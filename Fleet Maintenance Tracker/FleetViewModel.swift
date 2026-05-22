//
//  FleetViewModel.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

enum ServiceStatus: Equatable {
    case ok
    case dueSoon
    case overdue
    case unknown
}

enum AnalyticsPeriod {
    case month
    case year
    case lifetime
}

private let trackedServiceTypes = ["oil change", "brake service"]

@MainActor
@Observable
class FleetViewModel {
    var vehicles: [Vehicle] = []
    var logsByVehicleID: [String: [MaintenanceLog]] = [:]
    var serviceTemplates: [ServiceTemplate] = []
    var errorMessage: String?

    @ObservationIgnored
    private let db = Firestore.firestore()

    @ObservationIgnored
    private let storage = Storage.storage(url: "gs://fleet-maintenance-9ad07.firebasestorage.app")

    @ObservationIgnored
    private var vehiclesListener: ListenerRegistration?

    @ObservationIgnored
    private var logsListener: ListenerRegistration?

    @ObservationIgnored
    private var templatesListener: ListenerRegistration?

    @ObservationIgnored
    private var previousVehicles: [String: Vehicle] = [:]

    @ObservationIgnored
    private var previousServiceDue: Set<String> = []

    @ObservationIgnored
    private var hasReceivedInitialVehicleSnapshot = false

    @ObservationIgnored
    private var hasReceivedInitialLogsSnapshot = false

    deinit {
        vehiclesListener?.remove()
        logsListener?.remove()
        templatesListener?.remove()
    }

    func startListening() {
        startListeningVehicles()
        startListeningAllLogs()
        startListeningTemplates()
    }

    func stopListening() {
        vehiclesListener?.remove()
        vehiclesListener = nil
        logsListener?.remove()
        logsListener = nil
        templatesListener?.remove()
        templatesListener = nil
    }

    private func startListeningTemplates() {
        templatesListener?.remove()
        templatesListener = db.collection("serviceTemplates")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.serviceTemplates = snapshot?.documents.compactMap {
                        try? $0.data(as: ServiceTemplate.self)
                    } ?? []
                }
            }
    }

    func addServiceTemplate(serviceName: String, mileageInterval: Int) async -> Bool {
        errorMessage = nil
        let docRef = db.collection("serviceTemplates").document()
        let template = ServiceTemplate(
            id: docRef.documentID,
            serviceName: serviceName,
            mileageInterval: mileageInterval,
            assignedVehicleIDs: []
        )
        do {
            try docRef.setData(from: template)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteServiceTemplate(at offsets: IndexSet) {
        let idsToDelete = offsets.map { serviceTemplates[$0].id }
        Task {
            for id in idsToDelete {
                _ = await deleteServiceTemplateByID(id)
            }
        }
    }

    func deleteServiceTemplateByID(_ id: String) async -> Bool {
        errorMessage = nil
        guard !id.isEmpty else { return false }
        do {
            try await db.collection("serviceTemplates").document(id).delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setTemplateAssignment(templateID: String,
                               vehicleID: String,
                               assigned: Bool) async -> Bool {
        errorMessage = nil
        guard !templateID.isEmpty, !vehicleID.isEmpty else { return false }
        let docRef = db.collection("serviceTemplates").document(templateID)
        let update: [String: Any] = [
            "assignedVehicleIDs": assigned
                ? FieldValue.arrayUnion([vehicleID])
                : FieldValue.arrayRemove([vehicleID])
        ]
        do {
            try await docRef.updateData(update)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func startListeningVehicles() {
        vehiclesListener?.remove()
        vehiclesListener = db.collection("vehicles").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                let newVehicles: [Vehicle] = snapshot?.documents.compactMap {
                    try? $0.data(as: Vehicle.self)
                } ?? []
                self.detectStatusChanges(newVehicles: newVehicles)
                self.vehicles = newVehicles
                self.hasReceivedInitialVehicleSnapshot = true
                self.detectServiceDueChanges()
            }
        }
    }

    private func startListeningAllLogs() {
        logsListener?.remove()
        logsListener = db.collection("logs")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    let allLogs: [MaintenanceLog] = snapshot?.documents.compactMap {
                        try? $0.data(as: MaintenanceLog.self)
                    } ?? []
                    self.logsByVehicleID = Dictionary(grouping: allLogs, by: { $0.vehicleID })
                    self.hasReceivedInitialLogsSnapshot = true
                    self.detectServiceDueChanges()
                }
            }
    }

    private func detectStatusChanges(newVehicles: [Vehicle]) {
        defer {
            previousVehicles = Dictionary(uniqueKeysWithValues: newVehicles.map { ($0.id, $0) })
        }
        guard hasReceivedInitialVehicleSnapshot else { return }
        for vehicle in newVehicles {
            guard let prev = previousVehicles[vehicle.id] else { continue }
            if prev.effectiveStatus != .recall && vehicle.effectiveStatus == .recall {
                NotificationManager.shared.send(
                    title: "Vehicle Recall",
                    body: "\(vehicle.make) \(vehicle.model) was marked as Recall."
                )
            }
        }
    }

    private func detectServiceDueChanges() {
        let nowDue: Set<String> = Set(vehicles.compactMap { vehicle in
            let status = serviceStatus(for: vehicle)
            return (status == .overdue || status == .dueSoon) ? vehicle.id : nil
        })
        defer { previousServiceDue = nowDue }
        guard hasReceivedInitialVehicleSnapshot && hasReceivedInitialLogsSnapshot else { return }
        let newlyDue = nowDue.subtracting(previousServiceDue)
        for vehicleID in newlyDue {
            guard let vehicle = vehicles.first(where: { $0.id == vehicleID }) else { continue }
            NotificationManager.shared.send(
                title: "Service Due",
                body: "\(vehicle.make) \(vehicle.model) is due for service."
            )
        }
    }

    func addVehicle(make: String,
                    model: String,
                    year: Int,
                    vin: String,
                    licensePlate: String,
                    serviceInterval: Int?,
                    status: VehicleStatus,
                    owner: String,
                    color: String,
                    lockboxCode: String) async -> Bool {
        errorMessage = nil
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to add a vehicle."
            return false
        }
        let docRef = db.collection("vehicles").document()
        let vehicle = Vehicle(
            id: docRef.documentID,
            make: make, model: model, year: year,
            vin: vin, licensePlate: licensePlate,
            addedBy: uid,
            serviceInterval: serviceInterval,
            status: status,
            owner: owner,
            color: color,
            lockboxCode: lockboxCode,
            qrCode: UUID().uuidString
        )
        do {
            try docRef.setData(from: vehicle)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateVehicleStatus(vehicleID: String, newStatus: String) async -> Bool {
        errorMessage = nil
        guard !vehicleID.isEmpty else {
            errorMessage = "Vehicle is missing an id."
            return false
        }
        do {
            try await db.collection("vehicles").document(vehicleID)
                .updateData(["status": newStatus])
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateVehicle(_ vehicle: Vehicle) async -> Bool {
        errorMessage = nil
        guard !vehicle.id.isEmpty else {
            errorMessage = "Vehicle is missing an id."
            return false
        }
        // qrCode is locked at creation. Preserve the existing value to prevent rotation.
        var toSave = vehicle
        if let existing = vehicles.first(where: { $0.id == vehicle.id })?.qrCode {
            toSave.qrCode = existing
        } else if toSave.qrCode == nil {
            toSave.qrCode = UUID().uuidString
        }
        do {
            try db.collection("vehicles").document(vehicle.id).setData(from: toSave, merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteVehicle(at offsets: IndexSet) {
        let idsToDelete = offsets.map { vehicles[$0].id }
        Task {
            for id in idsToDelete {
                _ = await deleteVehicleByID(id)
            }
        }
    }

    func deleteVehicleByID(_ id: String) async -> Bool {
        errorMessage = nil
        guard !id.isEmpty else {
            errorMessage = "Vehicle is missing an id."
            return false
        }
        do {
            let logsSnapshot = try await db.collection("logs")
                .whereField("vehicleID", isEqualTo: id)
                .getDocuments()
            let batch = db.batch()
            for doc in logsSnapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            batch.deleteDocument(db.collection("vehicles").document(id))
            try await batch.commit()
            logsByVehicleID.removeValue(forKey: id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func addLog(vehicleID: String,
                serviceType: String,
                date: Date,
                mileage: Int,
                cost: Double,
                notes: String,
                receiptImageData: Data? = nil) async -> Bool {
        errorMessage = nil

        var receiptURL: String? = nil
        if let receiptImageData {
            do {
                receiptURL = try await uploadReceipt(data: receiptImageData)
            } catch {
                errorMessage = "Receipt upload failed: \(error.localizedDescription)"
                return false
            }
        }

        let docRef = db.collection("logs").document()
        let log = MaintenanceLog(
            id: docRef.documentID,
            vehicleID: vehicleID,
            serviceType: serviceType,
            date: date,
            mileage: mileage,
            cost: cost,
            notes: notes,
            receiptURL: receiptURL
        )
        do {
            try docRef.setData(from: log)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateLog(_ log: MaintenanceLog,
                   newReceiptImageData: Data? = nil) async -> Bool {
        errorMessage = nil
        guard !log.id.isEmpty else {
            errorMessage = "Log is missing an id."
            return false
        }

        var toSave = log
        if let newReceiptImageData {
            do {
                toSave.receiptURL = try await uploadReceipt(data: newReceiptImageData)
            } catch {
                errorMessage = "Receipt upload failed: \(error.localizedDescription)"
                return false
            }
        }

        do {
            try db.collection("logs").document(toSave.id).setData(from: toSave, merge: true)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteLog(_ log: MaintenanceLog) async -> Bool {
        errorMessage = nil
        guard !log.id.isEmpty else {
            errorMessage = "Log is missing an id."
            return false
        }
        do {
            try await db.collection("logs").document(log.id).delete()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func fetchLogs(for vehicleID: String) -> [MaintenanceLog] {
        logsByVehicleID[vehicleID] ?? []
    }

    func latestMileage(for vehicleID: String) -> Int? {
        logsByVehicleID[vehicleID]?.first?.mileage
    }

    func assignedTemplates(for vehicleID: String) -> [ServiceTemplate] {
        serviceTemplates
            .filter { $0.assignedVehicleIDs.contains(vehicleID) }
            .sorted { $0.serviceName.localizedCaseInsensitiveCompare($1.serviceName) == .orderedAscending }
    }

    // Resolves a scanned token (either a persistent qrCode or a legacy id) to a vehicle id.
    func vehicleID(forScannedToken token: String) -> String? {
        if let match = vehicles.first(where: { $0.qrCode == token }) {
            return match.id
        }
        if vehicles.contains(where: { $0.id == token }) {
            return token
        }
        return nil
    }

    enum FleetHealth: Hashable {
        case percentage(Int)
        case noSchedule
        case unknown
    }

    func fleetHealth(for vehicle: Vehicle) -> FleetHealth {
        let templates = assignedTemplates(for: vehicle.id)
        guard !templates.isEmpty else { return .noSchedule }
        var lowest: Int? = nil
        for template in templates {
            let h = serviceHealth(for: vehicle.id, template: template)
            let percent: Int
            switch h {
            case .green(let m), .yellow(let m), .red(let m):
                percent = Int((Double(m) / Double(max(template.mileageInterval, 1))) * 100)
            case .overdue(let m):
                percent = -Int((Double(m) / Double(max(template.mileageInterval, 1))) * 100)
            case .neverServiced:
                percent = 0
            case .unknown:
                continue
            }
            if lowest == nil || percent < lowest! {
                lowest = percent
            }
        }
        guard let lowest else { return .unknown }
        return .percentage(lowest)
    }

    func serviceHealth(for vehicleID: String, template: ServiceTemplate) -> ServiceHealth {
        let logs = logsByVehicleID[vehicleID] ?? []
        guard let currentMileage = logs.first?.mileage else { return .unknown }
        let matching = logs.filter {
            $0.serviceType.localizedCaseInsensitiveContains(template.serviceName)
        }
        guard let lastServiceMileage = matching.first?.mileage else {
            return .neverServiced
        }
        let remaining = (lastServiceMileage + template.mileageInterval) - currentMileage
        if remaining < 0 { return .overdue(milesOver: -remaining) }
        if remaining < 200 { return .red(milesRemaining: remaining) }
        if remaining <= 1000 { return .yellow(milesRemaining: remaining) }
        return .green(milesRemaining: remaining)
    }

    func serviceStatus(for vehicle: Vehicle) -> ServiceStatus {
        guard let interval = vehicle.serviceInterval, interval > 0 else { return .unknown }
        let logs = logsByVehicleID[vehicle.id] ?? []
        guard let currentMileage = logs.first?.mileage else { return .unknown }

        var worst: ServiceStatus = .unknown
        for service in trackedServiceTypes {
            let matching = logs.filter { $0.serviceType.localizedCaseInsensitiveContains(service) }
            guard let lastMileage = matching.first?.mileage else { continue }
            let miles = currentMileage - lastMileage
            let status: ServiceStatus
            if miles >= interval {
                status = .overdue
            } else if miles >= interval - 500 {
                status = .dueSoon
            } else {
                status = .ok
            }
            if severity(of: status) > severity(of: worst) {
                worst = status
            }
        }
        return worst
    }

    var vehiclesInRepairCount: Int {
        vehicles.filter { $0.effectiveStatus == .inShop }.count
    }

    func totalSpent(in period: AnalyticsPeriod) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let activeVehicleIDs = Set(vehicles.map { $0.id })
        let allLogs = logsByVehicleID
            .filter { activeVehicleIDs.contains($0.key) }
            .values
            .flatMap { $0 }
        return allLogs.filter { log in
            switch period {
            case .month:
                return calendar.isDate(log.date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(log.date, equalTo: now, toGranularity: .year)
            case .lifetime:
                return true
            }
        }.reduce(0) { $0 + $1.cost }
    }

    private func severity(of status: ServiceStatus) -> Int {
        switch status {
        case .overdue: return 3
        case .dueSoon: return 2
        case .ok: return 1
        case .unknown: return 0
        }
    }

    private func uploadReceipt(data: Data) async throws -> String {
        let filename = "receipts/\(UUID().uuidString).jpg"
        let ref = storage.reference().child(filename)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}

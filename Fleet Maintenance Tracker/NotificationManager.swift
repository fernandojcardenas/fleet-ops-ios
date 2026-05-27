//
//  NotificationManager.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // Threshold below which a vehicle is considered "low health" (in percent).
    static let lowHealthThreshold: Int = 15

    // Mileage window (in miles) before an upcoming service milestone that
    // triggers a "due soon" alert.
    static let serviceDueWindow: Int = 500

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[NotificationManager] auth error: \(error.localizedDescription)")
        }
    }

    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationManager] add error: \(error.localizedDescription)")
            }
        }
    }

    // Evaluates the current fleet state and (re)schedules a single local
    // notification per vehicle when a maintenance threshold is crossed.
    // Using vehicle.id as the UNNotificationRequest identifier causes the
    // system to replace any pending request with the same id, preventing
    // duplicate stacks of alerts as listeners fire.
    func evaluateMaintenanceAlerts(in fleet: FleetViewModel) {
        let activeVehicleIDs = Set(fleet.vehicles.map { $0.id })

        for vehicle in fleet.vehicles {
            // Skip vehicles that aren't operational — they have their own status flow.
            guard vehicle.effectiveStatus == .active else {
                cancelMaintenanceAlert(forVehicleID: vehicle.id)
                continue
            }

            let isLowHealth = isVehicleLowHealth(vehicle, in: fleet)
            let isServiceDueSoon = isVehicleServiceDueSoon(vehicle, in: fleet)

            if isLowHealth || isServiceDueSoon {
                scheduleMaintenanceAlert(
                    for: vehicle,
                    lowHealth: isLowHealth,
                    serviceDueSoon: isServiceDueSoon
                )
            } else {
                cancelMaintenanceAlert(forVehicleID: vehicle.id)
            }
        }

        // Clear pending alerts for vehicles that no longer exist in the fleet.
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let stale = requests
                .map(\.identifier)
                .filter { !activeVehicleIDs.contains($0) }
            guard !stale.isEmpty else { return }
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: stale)
        }
    }

    private func isVehicleLowHealth(_ vehicle: Vehicle, in fleet: FleetViewModel) -> Bool {
        if case .percentage(let pct) = fleet.fleetHealth(for: vehicle) {
            return pct < Self.lowHealthThreshold
        }
        return false
    }

    private func isVehicleServiceDueSoon(_ vehicle: Vehicle, in fleet: FleetViewModel) -> Bool {
        guard let currentMileage = fleet.latestMileage(for: vehicle.id) else { return false }
        let templates = fleet.assignedTemplates(for: vehicle.id)
        guard !templates.isEmpty else { return false }
        let logs = fleet.fetchLogs(for: vehicle.id)
        for template in templates {
            let interval = vehicle.effectiveInterval(for: template)
            guard interval > 0 else { continue }
            let lastServiceMileage = logs
                .filter { $0.serviceType.localizedCaseInsensitiveContains(template.serviceName) }
                .first?.mileage
            let nextMilestone = (lastServiceMileage ?? 0) + interval
            let remaining = nextMilestone - currentMileage
            if remaining > 0 && remaining <= Self.serviceDueWindow {
                return true
            }
        }
        return false
    }

    private func scheduleMaintenanceAlert(for vehicle: Vehicle,
                                          lowHealth: Bool,
                                          serviceDueSoon: Bool) {
        let label = vehicleLabel(for: vehicle)
        let title: String
        let body: String
        switch (lowHealth, serviceDueSoon) {
        case (true, true):
            title = "Maintenance Attention Needed"
            body = "Low Health Alert: \(label) has dropped below \(Self.lowHealthThreshold)% health! Service Due Soon: \(label) is within \(Self.serviceDueWindow) miles of its custom maintenance interval."
        case (true, false):
            title = "Low Health Alert"
            body = "Low Health Alert: \(label) has dropped below \(Self.lowHealthThreshold)% health!"
        case (false, true):
            title = "Service Due Soon"
            body = "Service Due Soon: \(label) is within \(Self.serviceDueWindow) miles of its custom maintenance interval."
        case (false, false):
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["vehicleID": vehicle.id]

        // Reusing vehicle.id as the request identifier guarantees the system
        // replaces any prior pending request for the same vehicle.
        let request = UNNotificationRequest(
            identifier: vehicle.id,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationManager] schedule error: \(error.localizedDescription)")
            }
        }
    }

    private func cancelMaintenanceAlert(forVehicleID id: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }

    private func vehicleLabel(for vehicle: Vehicle) -> String {
        let plate = vehicle.licensePlate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plate.isEmpty {
            return "\(vehicle.make) \(vehicle.model) (\(plate))"
        }
        return "\(vehicle.make) \(vehicle.model)"
    }
}

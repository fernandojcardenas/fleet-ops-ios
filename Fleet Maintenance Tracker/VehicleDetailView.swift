//
//  VehicleDetailView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI

struct VehicleDetailView: View {
    let vehicleID: String
    let fleetViewModel: FleetViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var showingEdit = false
    @State private var showingAddLog = false
    @State private var showingDeleteConfirmation = false
    @State private var receiptLog: MaintenanceLog? = nil
    @State private var pdfURL: URL? = nil
    @State private var showingShareSheet = false
    @State private var showingQR = false
    @State private var isExporting = false
    @AppStorage("companyName") private var companyName: String = "My Fleet"

    private var vehicle: Vehicle? {
        fleetViewModel.vehicles.first { $0.id == vehicleID }
    }

    private var logs: [MaintenanceLog] {
        fleetViewModel.fetchLogs(for: vehicleID)
    }

    var body: some View {
        Group {
            if let vehicle {
                Form {
                    Section("Vehicle") {
                        LabeledContent("Make", value: vehicle.make)
                        LabeledContent("Model", value: vehicle.model)
                        LabeledContent("Year", value: String(vehicle.year))
                    }
                    Section("Identification") {
                        LabeledContent("VIN", value: vehicle.vin)
                        LabeledContent("License Plate", value: vehicle.licensePlate)
                    }
                    Section("Operational Status") {
                        Picker("Status", selection: statusBinding(for: vehicle)) {
                            ForEach(VehicleStatus.allCases, id: \.self) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                        if let interval = vehicle.serviceInterval {
                            LabeledContent("Service Interval", value: "\(interval) mi")
                        } else {
                            Text("No service interval set.")
                                .foregroundStyle(.secondary)
                        }
                        serviceStatusRow
                    }

                    let assignedTemplates = fleetViewModel.assignedTemplates(for: vehicleID)
                    if !assignedTemplates.isEmpty {
                        Section("Service Health") {
                            ForEach(assignedTemplates) { template in
                                serviceHealthRow(for: template)
                            }
                        }
                    }

                    Section("Maintenance Log") {
                        if logs.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("No service history yet")
                                    .font(.headline)
                                Text("Tap + to log your first oil change.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else {
                            ForEach(logs) { log in
                                Button {
                                    if log.receiptURL != nil {
                                        receiptLog = log
                                    }
                                } label: {
                                    logRow(log)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button {
                            showingAddLog = true
                        } label: {
                            Label("Add Maintenance Log", systemImage: "plus.circle")
                        }
                    }

                    Section {
                        Button {
                            showingQR = true
                        } label: {
                            Label("Generate Vehicle QR", systemImage: "qrcode")
                        }
                        Button {
                            exportServiceHistory(vehicle: vehicle)
                        } label: {
                            HStack {
                                Label("Export Service History", systemImage: "square.and.arrow.up")
                                if isExporting {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isExporting)

                        if let pdfURL {
                            ShareLink(
                                item: pdfURL,
                                preview: SharePreview(
                                    "\(vehicle.make) \(vehicle.model) Service History",
                                    image: Image(systemName: "doc.text")
                                )
                            ) {
                                Label("Share Last Report", systemImage: "paperplane")
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Vehicle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .navigationTitle("\(vehicle.make) \(vehicle.model)")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showingEdit = true }
                    }
                }
                .sheet(isPresented: $showingEdit) {
                    EditVehicleView(vehicle: vehicle, fleetViewModel: fleetViewModel)
                }
                .sheet(isPresented: $showingAddLog) {
                    AddLogView(vehicleID: vehicleID, fleetViewModel: fleetViewModel)
                }
                .sheet(item: $receiptLog) { log in
                    if let urlString = log.receiptURL, let url = URL(string: urlString) {
                        ReceiptViewer(url: url)
                    }
                }
                #if canImport(UIKit)
                .sheet(isPresented: $showingShareSheet) {
                    if let pdfURL {
                        ActivityView(activityItems: [pdfURL])
                    }
                }
                #endif
                .sheet(isPresented: $showingQR) {
                    VehicleQRView(vehicle: vehicle)
                }
                .alert("Delete Vehicle?", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        Task {
                            let success = await fleetViewModel.deleteVehicleByID(vehicleID)
                            if success { dismiss() }
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this vehicle? This action cannot be undone.")
                }
            } else {
                ContentUnavailableView(
                    "Vehicle Not Found",
                    systemImage: "car",
                    description: Text("It may have been deleted.")
                )
            }
        }
    }

    private func exportServiceHistory(vehicle: Vehicle) {
        isExporting = true
        Task {
            #if canImport(UIKit)
            let receipts = await fetchReceiptImages(for: logs)
            let url = generateVehiclePDF(
                companyName: companyName,
                vehicle: vehicle,
                logs: logs,
                receiptImages: receipts as [String: AnyObject]
            )
            #else
            let url = generateVehiclePDF(
                companyName: companyName,
                vehicle: vehicle,
                logs: logs
            )
            #endif
            isExporting = false
            if let url {
                pdfURL = url
                showingShareSheet = true
            }
        }
    }

    private func statusBinding(for vehicle: Vehicle) -> Binding<VehicleStatus> {
        Binding(
            get: { vehicle.effectiveStatus },
            set: { newValue in
                Task {
                    await fleetViewModel.updateVehicleStatus(
                        vehicleID: vehicle.id,
                        newStatus: newValue.rawValue
                    )
                }
            }
        )
    }

    @ViewBuilder
    private var serviceStatusRow: some View {
        if let vehicle {
            let status = fleetViewModel.serviceStatus(for: vehicle)
            switch status {
            case .overdue:
                LabeledContent("Service") { ServiceOverdueBadge() }
            case .dueSoon:
                LabeledContent("Service") { ServiceSoonBadge() }
            case .ok:
                LabeledContent("Service", value: "Up to date")
            case .unknown:
                LabeledContent("Service", value: "—")
            }
        }
    }

    @ViewBuilder
    private func serviceHealthRow(for template: ServiceTemplate) -> some View {
        let health = fleetViewModel.serviceHealth(for: vehicleID, template: template)
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.serviceName)
                    .font(.body)
                Text("Every \(template.mileageInterval) mi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(health.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(health.color, in: Capsule())
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func logRow(_ log: MaintenanceLog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.serviceType)
                    .font(.headline)
                if log.receiptURL != nil {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                Spacer()
                Text(log.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("\(log.mileage) mi")
                Spacer()
                Text(log.cost, format: .currency(code: "USD"))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

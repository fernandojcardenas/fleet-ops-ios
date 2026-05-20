//
//  VehicleCheckInView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import SwiftUI

struct VehicleCheckInView: View {
    let vehicleID: String
    let fleetViewModel: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mileage: Int? = nil
    @State private var servicePerformed: Bool = false
    @State private var selectedTemplate: ServiceTemplate? = nil
    @State private var notes: String = ""
    @State private var isSaving: Bool = false

    private var vehicle: Vehicle? {
        fleetViewModel.vehicles.first { $0.id == vehicleID }
    }

    private var assignedTemplates: [ServiceTemplate] {
        fleetViewModel.assignedTemplates(for: vehicleID)
    }

    var body: some View {
        NavigationStack {
            if let vehicle {
                Form {
                    Section("Vehicle") {
                        LabeledContent("Vehicle", value: "\(vehicle.make) \(vehicle.model)")
                        LabeledContent("Plate", value: vehicle.licensePlate)
                        if let last = fleetViewModel.latestMileage(for: vehicleID) {
                            LabeledContent("Last Recorded", value: "\(last) mi")
                        }
                    }

                    Section("Check-In") {
                        TextField("New Current Mileage",
                                  value: $mileage,
                                  format: .number.grouping(.never))
                        Toggle("Was service performed?", isOn: $servicePerformed)
                        if servicePerformed {
                            if assignedTemplates.isEmpty {
                                Text("No service templates assigned to this vehicle. Assign one from the Maintenance tab first.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Picker("Service", selection: $selectedTemplate) {
                                    Text("Choose…").tag(ServiceTemplate?.none)
                                    ForEach(assignedTemplates) { template in
                                        Text(template.serviceName).tag(Optional(template))
                                    }
                                }
                            }
                        }
                    }

                    Section("Notes") {
                        TextField("Optional notes", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                    }

                    if let errorMessage = fleetViewModel.errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Vehicle Check-In")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(!canSave || isSaving)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Vehicle Not Found",
                    systemImage: "car",
                    description: Text("This QR code doesn't match any vehicle in the fleet.")
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        guard let mileage, mileage > 0 else { return false }
        if servicePerformed && selectedTemplate == nil { return false }
        return true
    }

    private func save() {
        guard let mileage else { return }
        let serviceType: String
        if servicePerformed, let template = selectedTemplate {
            serviceType = template.serviceName
        } else {
            serviceType = "Mileage Update"
        }
        isSaving = true
        Task {
            let success = await fleetViewModel.addLog(
                vehicleID: vehicleID,
                serviceType: serviceType,
                date: .now,
                mileage: mileage,
                cost: 0,
                notes: notes
            )
            isSaving = false
            if success { dismiss() }
        }
    }
}

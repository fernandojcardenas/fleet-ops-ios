//
//  ServiceTemplateDetailView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import SwiftUI

struct ServiceTemplateDetailView: View {
    let templateID: String
    let fleetViewModel: FleetViewModel

    private var template: ServiceTemplate? {
        fleetViewModel.serviceTemplates.first { $0.id == templateID }
    }

    var body: some View {
        Group {
            if let template {
                Form {
                    Section("Template") {
                        LabeledContent("Service", value: template.serviceName)
                        LabeledContent("Interval", value: "\(template.mileageInterval) mi")
                        LabeledContent("Assigned", value: "\(template.assignedVehicleIDs.count) of \(fleetViewModel.vehicles.count)")
                    }

                    Section("Assigned Vehicles") {
                        if fleetViewModel.vehicles.isEmpty {
                            Text("No vehicles to assign yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            Button(allSelected(in: template) ? "Deselect All" : "Select All") {
                                toggleAll(for: template)
                            }
                            ForEach(fleetViewModel.vehicles) { vehicle in
                                Toggle(isOn: binding(for: template, vehicleID: vehicle.id)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(vehicle.make) \(vehicle.model)")
                                            .font(.body)
                                        Text(vehicle.licensePlate)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(template.serviceName)
            } else {
                ContentUnavailableView(
                    "Template Not Found",
                    systemImage: "list.clipboard",
                    description: Text("It may have been deleted.")
                )
            }
        }
    }

    private func binding(for template: ServiceTemplate, vehicleID: String) -> Binding<Bool> {
        Binding(
            get: { template.assignedVehicleIDs.contains(vehicleID) },
            set: { newValue in
                Task {
                    _ = await fleetViewModel.setTemplateAssignment(
                        templateID: template.id,
                        vehicleID: vehicleID,
                        assigned: newValue
                    )
                }
            }
        )
    }

    private func allSelected(in template: ServiceTemplate) -> Bool {
        let allIDs = Set(fleetViewModel.vehicles.map(\.id))
        guard !allIDs.isEmpty else { return false }
        return allIDs.isSubset(of: Set(template.assignedVehicleIDs))
    }

    private func toggleAll(for template: ServiceTemplate) {
        let shouldDeselect = allSelected(in: template)
        let newIDs = shouldDeselect ? [] : fleetViewModel.vehicles.map(\.id)
        Task {
            _ = await fleetViewModel.setAssignedVehicleIDs(
                templateID: template.id,
                vehicleIDs: newIDs
            )
        }
    }
}

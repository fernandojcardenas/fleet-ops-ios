//
//  MaintenanceTabView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import SwiftUI

struct MaintenanceTabView: View {
    let fleetViewModel: FleetViewModel
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(fleetViewModel.serviceTemplates) { template in
                    NavigationLink(value: template.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.serviceName)
                                .font(.headline)
                            HStack {
                                Text("Every \(template.mileageInterval) mi")
                                Text("·")
                                Text("\(template.assignedVehicleIDs.count) vehicle\(template.assignedVehicleIDs.count == 1 ? "" : "s")")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: fleetViewModel.deleteServiceTemplate)
            }
            .overlay {
                if fleetViewModel.serviceTemplates.isEmpty {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "list.clipboard",
                        description: Text("Tap + to add a template like \"Oil Change every 5,000 mi\".")
                    )
                }
            }
            .navigationTitle("Maintenance")
            .navigationDestination(for: String.self) { templateID in
                ServiceTemplateDetailView(templateID: templateID, fleetViewModel: fleetViewModel)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add Template", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddServiceTemplateView(fleetViewModel: fleetViewModel)
            }
        }
    }
}

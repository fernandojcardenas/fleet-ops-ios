//
//  HomeView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(AuthManager.self) private var authManager
    let fleetViewModel: FleetViewModel
    @State private var showingAddVehicle = false
    @State private var showingSettings = false
    @State private var showingScanner = false
    @State private var showingCheckIn = false
    @State private var checkInVehicleID: String? = nil
    @State private var showOnlyDue = false
    @State private var sortByHealth = false
    @State private var searchText = ""
    @State private var navPath = NavigationPath()
    @AppStorage("showOnlyActive") private var showOnlyActive = false
    @AppStorage("pendingVehicleID") private var pendingVehicleID: String = ""

    private var displayedVehicles: [Vehicle] {
        let filtered = fleetViewModel.vehicles.filter { vehicle in
            if showOnlyActive && vehicle.effectiveStatus != .active {
                return false
            }
            if showOnlyDue {
                let status = fleetViewModel.serviceStatus(for: vehicle)
                if status != .overdue && status != .dueSoon { return false }
            }
            let trimmed = searchText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let matches = vehicle.make.localizedCaseInsensitiveContains(trimmed)
                    || vehicle.model.localizedCaseInsensitiveContains(trimmed)
                    || vehicle.licensePlate.localizedCaseInsensitiveContains(trimmed)
                    || vehicle.vin.localizedCaseInsensitiveContains(trimmed)
                if !matches { return false }
            }
            return true
        }
        if sortByHealth {
            return filtered.sorted { healthSortValue(for: $0) < healthSortValue(for: $1) }
        }
        return filtered
    }

    private func healthSortValue(for vehicle: Vehicle) -> Int {
        switch fleetViewModel.fleetHealth(for: vehicle) {
        case .percentage(let p): return p
        case .noSchedule: return Int.max - 1
        case .unknown: return Int.max
        }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                Section("Analytics") {
                    LabeledContent(
                        "This Month",
                        value: fleetViewModel.totalSpent(in: .month),
                        format: .currency(code: "USD")
                    )
                    LabeledContent(
                        "Lifetime",
                        value: fleetViewModel.totalSpent(in: .lifetime),
                        format: .currency(code: "USD")
                    )
                    LabeledContent("Vehicles in Shop",
                                   value: "\(fleetViewModel.vehiclesInRepairCount)")
                }

                Section(sectionTitle) {
                    ForEach(displayedVehicles) { vehicle in
                        NavigationLink(value: vehicle.id) {
                            vehicleRow(vehicle)
                        }
                    }
                    .onDelete(perform: deleteFiltered)
                }
            }
            .overlay {
                if fleetViewModel.vehicles.isEmpty {
                    ContentUnavailableView(
                        "No Vehicles",
                        systemImage: "car.2",
                        description: Text("Tap + to add your first vehicle.")
                    )
                } else if !searchText.trimmingCharacters(in: .whitespaces).isEmpty
                            && displayedVehicles.isEmpty {
                    ContentUnavailableView(
                        "No vehicles match your search",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different make, model, plate, or VIN.")
                    )
                } else if displayedVehicles.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Show",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Adjust your filters to see vehicles.")
                    )
                }
            }
            .navigationTitle("Fleet")
            .navigationDestination(for: String.self) { vehicleID in
                VehicleDetailView(vehicleID: vehicleID, fleetViewModel: fleetViewModel)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Section("Filter") {
                            Button {
                                showOnlyDue = false
                            } label: {
                                Label("Show All", systemImage: showOnlyDue ? "" : "checkmark")
                            }
                            Button {
                                showOnlyDue = true
                            } label: {
                                Label("Due for Service Only", systemImage: showOnlyDue ? "checkmark" : "")
                            }
                        }
                        Section("Sort") {
                            Toggle(isOn: $sortByHealth) {
                                Label("Sort by Health", systemImage: "heart.text.square")
                            }
                        }
                    } label: {
                        Image(systemName: (showOnlyDue || sortByHealth)
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddVehicle = true
                    } label: {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddVehicle) {
                AddVehicleView(fleetViewModel: fleetViewModel)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showingScanner) {
                QRScannerView { value in
                    handleScannedValue(value)
                }
            }
            #endif
            .sheet(isPresented: $showingCheckIn) {
                if let checkInVehicleID {
                    VehicleCheckInView(vehicleID: checkInVehicleID, fleetViewModel: fleetViewModel)
                }
            }
            .searchable(text: $searchText, prompt: "Make, model, plate, or VIN")
            .onAppear {
                fleetViewModel.startListening()
                consumePendingVehicleIDIfNeeded()
            }
            .onChange(of: pendingVehicleID) { _, newValue in
                if !newValue.isEmpty { consumePendingVehicleIDIfNeeded() }
            }
            .onDisappear { fleetViewModel.stopListening() }
            .onOpenURL { url in
                if let id = vehicleID(from: url) {
                    navigate(to: id)
                }
            }
        }
    }

    private func handleScannedValue(_ value: String) {
        let id: String?
        if let url = URL(string: value), let parsed = vehicleID(from: url) {
            id = parsed
        } else if !value.isEmpty {
            id = value
        } else {
            id = nil
        }
        guard let id else { return }
        checkInVehicleID = id
        showingCheckIn = true
    }

    private func vehicleID(from url: URL) -> String? {
        guard url.scheme == QRGenerator.deepLinkScheme,
              url.host == "vehicle" else { return nil }
        let id = url.lastPathComponent
        return id.isEmpty ? nil : id
    }

    private func navigate(to vehicleID: String) {
        navPath = NavigationPath()
        navPath.append(vehicleID)
    }

    private func consumePendingVehicleIDIfNeeded() {
        let id = pendingVehicleID
        guard !id.isEmpty else { return }
        pendingVehicleID = ""
        navigate(to: id)
    }

    private var sectionTitle: String {
        switch (showOnlyDue, showOnlyActive) {
        case (true, true):   return "Active · Due for Service"
        case (true, false):  return "Due for Service"
        case (false, true):  return "Active"
        case (false, false): return "Vehicles"
        }
    }

    @ViewBuilder
    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        let serviceStatus = fleetViewModel.serviceStatus(for: vehicle)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(vehicle.make) \(vehicle.model)")
                    .font(.headline)
                statusPill(vehicle.effectiveStatus)
                ServiceStatusBadge(status: serviceStatus)
                Spacer()
                if let mileage = fleetViewModel.latestMileage(for: vehicle.id) {
                    Text("\(mileage) mi")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text(vehicle.licensePlate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                healthBadge(for: vehicle)
            }
        }
    }

    @ViewBuilder
    private func healthBadge(for vehicle: Vehicle) -> some View {
        switch fleetViewModel.fleetHealth(for: vehicle) {
        case .percentage(let percent):
            let color = healthColor(for: percent)
            Text("\(percent)% Health")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.18), in: Capsule())
                .foregroundStyle(color)
        case .noSchedule:
            Text("No maintenance schedule")
                .font(.caption2)
                .foregroundStyle(.gray.opacity(0.7))
        case .unknown:
            EmptyView()
        }
    }

    private func healthColor(for percent: Int) -> Color {
        if percent < 5 { return .red }
        if percent < 20 { return .yellow }
        return .green
    }

    @ViewBuilder
    private func statusPill(_ status: VehicleStatus) -> some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color, in: Capsule())
            .foregroundStyle(.white)
            .animation(.default, value: status)
    }

    private func deleteFiltered(at offsets: IndexSet) {
        let idsToDelete = offsets.map { displayedVehicles[$0].id }
        Task {
            for id in idsToDelete {
                _ = await fleetViewModel.deleteVehicleByID(id)
            }
        }
    }
}

#Preview {
    HomeView(fleetViewModel: FleetViewModel())
        .environment(AuthManager())
}

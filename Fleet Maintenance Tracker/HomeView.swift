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
    @State private var analyticsPeriod: AnalyticsPeriod = .month
    @AppStorage("showOnlyActive") private var showOnlyActive = false
    @AppStorage("pendingVehicleID") private var pendingVehicleID: String = ""
    @AppStorage("customVehicleOrder") private var customVehicleOrderData: String = ""

    private var customVehicleOrder: [String] {
        guard let data = customVehicleOrderData.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return ids
    }

    private func setCustomVehicleOrder(_ ids: [String]) {
        if let data = try? JSONEncoder().encode(ids),
           let str = String(data: data, encoding: .utf8) {
            customVehicleOrderData = str
        }
    }

    // Returns all vehicle ids in their persisted custom order, with any
    // vehicles not yet in the order appended at the end (in fleet order).
    private func orderedVehicleIDs() -> [String] {
        let allIDs = fleetViewModel.vehicles.map { $0.id }
        let allSet = Set(allIDs)
        var ordered = customVehicleOrder.filter { allSet.contains($0) }
        let orderedSet = Set(ordered)
        for id in allIDs where !orderedSet.contains(id) {
            ordered.append(id)
        }
        return ordered
    }

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
        let position = Dictionary(uniqueKeysWithValues: orderedVehicleIDs().enumerated().map { ($1, $0) })
        return filtered.sorted { (position[$0.id] ?? .max) < (position[$1.id] ?? .max) }
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
                    Picker("Spend Period", selection: $analyticsPeriod) {
                        Text("Monthly Spend").tag(AnalyticsPeriod.month)
                        Text("Lifetime Spend").tag(AnalyticsPeriod.lifetime)
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    LabeledContent(
                        analyticsPeriod == .month ? "This Month" : "Lifetime",
                        value: fleetViewModel.totalSpent(in: analyticsPeriod),
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
                    .onMove { source, destination in
                        if !sortByHealth {
                            moveVehicles(from: source, to: destination)
                        }
                    }
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
                    Button("Sign Out") { authManager.signOut() }
                }
                ToolbarItemGroup(placement: .secondaryAction) {
                    EditButton()
                    filterMenu
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
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
            .onChange(of: fleetViewModel.vehicles.count) { _, _ in
                consumePendingVehicleIDIfNeeded()
            }
            .onDisappear { fleetViewModel.stopListening() }
            .onOpenURL { url in
                if let id = vehicleID(from: url) {
                    navigate(to: id)
                }
            }
        }
    }

    private var filterMenu: some View {
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

    private func handleScannedValue(_ value: String) {
        let token: String?
        if let url = URL(string: value), let parsed = tokenFromDeepLink(url) {
            token = parsed
        } else if !value.isEmpty {
            token = value
        } else {
            token = nil
        }
        guard let token else { return }
        // Resolve the scanned QR token (persistent UUID) to the underlying vehicle id.
        // Fall back to the raw token so the check-in screen can render "Vehicle Not Found".
        checkInVehicleID = fleetViewModel.vehicleID(forScannedToken: token) ?? token
        showingCheckIn = true
    }

    private func tokenFromDeepLink(_ url: URL) -> String? {
        guard url.scheme == QRGenerator.deepLinkScheme,
              url.host == "vehicle" else { return nil }
        let token = url.lastPathComponent
        return token.isEmpty ? nil : token
    }

    private func vehicleID(from url: URL) -> String? {
        guard let token = tokenFromDeepLink(url) else { return nil }
        return fleetViewModel.vehicleID(forScannedToken: token) ?? token
    }

    private func navigate(to vehicleID: String) {
        navPath = NavigationPath()
        navPath.append(vehicleID)
    }

    private func consumePendingVehicleIDIfNeeded() {
        let token = pendingVehicleID
        guard !token.isEmpty else { return }
        // Resolve the pending token (which may be a persistent qrCode) to the real vehicle id.
        // If the fleet hasn't loaded yet, keep the token in storage and try again next snapshot.
        guard let resolved = fleetViewModel.vehicleID(forScannedToken: token) else {
            if !fleetViewModel.vehicles.isEmpty {
                pendingVehicleID = ""
            }
            return
        }
        pendingVehicleID = ""
        navigate(to: resolved)
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
        HStack(alignment: .top, spacing: 12) {
            colorSwatch(for: vehicle.color)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model)")
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
                ownershipLine(for: vehicle)
                HStack {
                    Text(vehicle.licensePlate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    healthBadge(for: vehicle)
                }
            }
        }
    }

    @ViewBuilder
    private func ownershipLine(for vehicle: Vehicle) -> some View {
        let owner = vehicle.owner?.trimmingCharacters(in: .whitespaces) ?? ""
        let color = vehicle.color?.trimmingCharacters(in: .whitespaces) ?? ""
        if !owner.isEmpty || !color.isEmpty {
            HStack(spacing: 4) {
                if !owner.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(owner)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !owner.isEmpty && !color.isEmpty {
                    Text("·")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !color.isEmpty {
                    Text(color)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func colorSwatch(for colorName: String?) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(vehicleColor(from: colorName))
            .frame(width: 18, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5)
            )
            .accessibilityHidden(true)
    }

    // Maps a free-form color string entered by the user to a SwiftUI Color.
    // Unknown values fall back to gray so the swatch is still rendered.
    private func vehicleColor(from name: String?) -> Color {
        let trimmed = name?.lowercased().trimmingCharacters(in: .whitespaces) ?? ""
        switch trimmed {
        case "black": return .black
        case "white": return .white
        case "silver", "grey", "gray": return Color(.systemGray3)
        case "red": return .red
        case "blue": return .blue
        case "navy", "dark blue": return Color(red: 0.05, green: 0.15, blue: 0.45)
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "brown": return .brown
        case "tan", "beige", "cream": return Color(red: 0.93, green: 0.85, blue: 0.70)
        case "purple", "violet": return .purple
        case "pink": return .pink
        case "gold": return Color(red: 0.83, green: 0.66, blue: 0.20)
        case "maroon", "burgundy": return Color(red: 0.50, green: 0.05, blue: 0.13)
        default: return .gray
        }
    }

    private func moveVehicles(from source: IndexSet, to destination: Int) {
        var displayed = displayedVehicles
        displayed.move(fromOffsets: source, toOffset: destination)
        let newDisplayedIDs = displayed.map { $0.id }

        // Stitch the reordered displayed IDs back into the master order,
        // leaving non-displayed vehicles in their existing positions.
        let displayedSet = Set(displayedVehicles.map { $0.id })
        var queue = newDisplayedIDs
        var newMaster: [String] = []
        for id in orderedVehicleIDs() {
            if displayedSet.contains(id), !queue.isEmpty {
                newMaster.append(queue.removeFirst())
            } else {
                newMaster.append(id)
            }
        }
        setCustomVehicleOrder(newMaster)
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

}

#Preview {
    HomeView(fleetViewModel: FleetViewModel())
        .environment(AuthManager())
}

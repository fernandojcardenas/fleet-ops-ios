//
//  AnalyticsTabView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import SwiftUI

struct AnalyticsTabView: View {
    let fleetViewModel: FleetViewModel

    @State private var analyticsPeriod: AnalyticsPeriod = .month
    @State private var selectedVehicleID: String = AnalyticsTabView.allFilterTag
    @State private var selectedOwner: String = AnalyticsTabView.allFilterTag
    @State private var selectedDateFilter: DateFilter = .all

    static let allFilterTag = "__all__"

    enum DateFilter: String, CaseIterable, Hashable {
        case all
        case thisMonth
        case thisYear
        case last30Days
        case last90Days

        var displayName: String {
            switch self {
            case .all: return "All Time"
            case .thisMonth: return "This Month"
            case .thisYear: return "This Year"
            case .last30Days: return "Last 30 Days"
            case .last90Days: return "Last 90 Days"
            }
        }
    }

    private var vehiclesByID: [String: Vehicle] {
        Dictionary(uniqueKeysWithValues: fleetViewModel.vehicles.map { ($0.id, $0) })
    }

    private var allLogs: [MaintenanceLog] {
        let activeIDs = Set(fleetViewModel.vehicles.map { $0.id })
        return fleetViewModel.logsByVehicleID
            .filter { activeIDs.contains($0.key) }
            .values
            .flatMap { $0 }
            .sorted { $0.date > $1.date }
    }

    private var uniqueOwners: [String] {
        let owners = fleetViewModel.vehicles
            .compactMap { $0.owner?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(Set(owners)).sorted()
    }

    private var filteredLogs: [MaintenanceLog] {
        let calendar = Calendar.current
        let now = Date()
        return allLogs.filter { log in
            if selectedVehicleID != Self.allFilterTag && log.vehicleID != selectedVehicleID {
                return false
            }
            if selectedOwner != Self.allFilterTag {
                let owner = vehiclesByID[log.vehicleID]?
                    .owner?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if owner != selectedOwner { return false }
            }
            switch selectedDateFilter {
            case .all:
                return true
            case .thisMonth:
                return calendar.isDate(log.date, equalTo: now, toGranularity: .month)
            case .thisYear:
                return calendar.isDate(log.date, equalTo: now, toGranularity: .year)
            case .last30Days:
                guard let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
                return log.date >= cutoff
            case .last90Days:
                guard let cutoff = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
                return log.date >= cutoff
            }
        }
    }

    var body: some View {
        NavigationStack {
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

                Section("Filters") {
                    Picker("Date", selection: $selectedDateFilter) {
                        ForEach(DateFilter.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        Text("All Vehicles").tag(Self.allFilterTag)
                        ForEach(fleetViewModel.vehicles) { vehicle in
                            Text("\(vehicle.make) \(vehicle.model)").tag(vehicle.id)
                        }
                    }
                    Picker("Owner", selection: $selectedOwner) {
                        Text("All Owners").tag(Self.allFilterTag)
                        ForEach(uniqueOwners, id: \.self) { owner in
                            Text(owner).tag(owner)
                        }
                    }
                }

                Section("Maintenance History") {
                    if filteredLogs.isEmpty {
                        Text("No logs match your filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredLogs) { log in
                            logRow(log)
                        }
                    }
                }
            }
            .navigationTitle("Analytics")
            .onAppear { fleetViewModel.startListening() }
        }
    }

    @ViewBuilder
    private func logRow(_ log: MaintenanceLog) -> some View {
        let vehicle = vehiclesByID[log.vehicleID]
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let vehicle {
                    Text("\(vehicle.make) \(vehicle.model)")
                        .font(.headline)
                } else {
                    Text("Unknown Vehicle")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(log.cost, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.semibold))
            }
            Text(log.serviceType)
                .font(.subheadline)
            HStack {
                Text(log.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                let owner = vehicle?.owner?.trimmingCharacters(in: .whitespaces) ?? ""
                if !owner.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(owner)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    AnalyticsTabView(fleetViewModel: FleetViewModel())
}

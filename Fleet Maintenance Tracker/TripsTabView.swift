//
//  TripsTabView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import SwiftUI

struct TripsTabView: View {
    let fleetViewModel: FleetViewModel

    @State private var showManualTripSheet = false
    @State private var editingTrip: Trip?
    @State private var tripPendingDeletion: Trip?
    @State private var showDeleteAlert = false

    private var vehiclesByID: [String: Vehicle] {
        Dictionary(uniqueKeysWithValues: fleetViewModel.vehicles.map { ($0.id, $0) })
    }

    // Sort by start date desc, falling back to end date so active trips
    // without a finalized timeline still appear near the top.
    private var sortedTrips: [Trip] {
        fleetViewModel.trips.sorted { lhs, rhs in
            let lhsKey = lhs.dateStart ?? lhs.dateEnd ?? .distantPast
            let rhsKey = rhs.dateStart ?? rhs.dateEnd ?? .distantPast
            return lhsKey > rhsKey
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedTrips.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Trips",
                            systemImage: "road.lanes.curved.right",
                            description: Text("Trips will appear here once vehicles are dispatched.")
                        )
                    }
                } else {
                    Section("All Trips") {
                        ForEach(sortedTrips) { trip in
                            Button {
                                editingTrip = trip
                            } label: {
                                tripRow(trip)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    tripPendingDeletion = trip
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showManualTripSheet = true
                    } label: {
                        Label("Log Trip", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showManualTripSheet) {
                ManualTripFormView(fleetViewModel: fleetViewModel)
            }
            .sheet(item: $editingTrip) { trip in
                EditTripView(trip: trip, fleetViewModel: fleetViewModel)
            }
            .alert("Delete Trip?", isPresented: $showDeleteAlert, presenting: tripPendingDeletion) { trip in
                Button("Delete", role: .destructive) {
                    Task { _ = await fleetViewModel.deleteTrip(trip) }
                    tripPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    tripPendingDeletion = nil
                }
            } message: { _ in
                Text("Are you sure you want to permanently delete this trip log? This cannot be undone.")
            }
            .onAppear { fleetViewModel.startListening() }
        }
    }

    @ViewBuilder
    private func tripRow(_ trip: Trip) -> some View {
        let vehicle = vehiclesByID[trip.vehicleID]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let vehicle {
                    Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model)")
                        .font(.headline)
                } else {
                    Text("Unknown Vehicle")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                tripStatusPill(for: trip)
            }
            if let vehicle {
                Text(vehicle.licensePlate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dateRangeText(start: trip.dateStart, end: trip.dateEnd))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(mileageRangeText(start: trip.mileageStart, end: trip.mileageEnd))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func dateRangeText(start: Date?, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let startText = start.map { formatter.string(from: $0) } ?? "—"
        let endText = end.map { formatter.string(from: $0) } ?? "In progress"
        return "\(startText) → \(endText)"
    }

    private func mileageRangeText(start: Int?, end: Int?) -> String {
        let startText = start.map { "\($0) mi" } ?? "—"
        let endText = end.map { "\($0) mi" } ?? "—"
        if let start, let end {
            let delta = max(0, end - start)
            return "\(startText) → \(endText)  (\(delta) mi)"
        }
        return "\(startText) → \(endText)"
    }

    @ViewBuilder
    private func tripStatusPill(for trip: Trip) -> some View {
        let isOngoing = trip.effectiveIsOngoing
        let label = isOngoing ? "Ongoing" : trip.status
        let color: Color = isOngoing ? .green : .gray
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    TripsTabView(fleetViewModel: FleetViewModel())
}

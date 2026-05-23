//
//  EditTripView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import SwiftUI

struct EditTripView: View {
    let trip: Trip
    let fleetViewModel: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dateStart: Date
    @State private var dateEnd: Date
    @State private var mileageStart: Int?
    @State private var mileageEnd: Int?
    @State private var notes: String
    // Tracks whether the trip should remain ongoing after the edit.
    // For ongoing trips this drives the "End Trip Manually" workflow:
    // turning the toggle ON below flips this to false and reveals the end inputs.
    @State private var isOngoing: Bool
    @State private var endTripNow: Bool = false
    @State private var isSaving = false
    private let wasOngoing: Bool

    init(trip: Trip, fleetViewModel: FleetViewModel) {
        self.trip = trip
        self.fleetViewModel = fleetViewModel
        let ongoing = trip.effectiveIsOngoing
        self.wasOngoing = ongoing
        _dateStart = State(initialValue: trip.dateStart ?? .now)
        _dateEnd = State(initialValue: trip.dateEnd ?? .now)
        _mileageStart = State(initialValue: trip.mileageStart)
        _mileageEnd = State(initialValue: trip.mileageEnd)
        _notes = State(initialValue: trip.notes ?? "")
        _isOngoing = State(initialValue: ongoing)
    }

    private var vehicle: Vehicle? {
        fleetViewModel.vehicles.first { $0.id == trip.vehicleID }
    }

    // True when the user is currently closing out an ongoing trip in this sheet.
    private var isEndingOngoingTrip: Bool {
        wasOngoing && endTripNow
    }

    // True when the form should currently expose end-of-trip fields.
    private var showsEndFields: Bool {
        if wasOngoing { return endTripNow }
        return !isOngoing
    }

    var body: some View {
        NavigationStack {
            Form {
                if let vehicle {
                    Section("Vehicle") {
                        LabeledContent("Vehicle",
                                       value: "\(String(vehicle.year)) \(vehicle.make) \(vehicle.model)")
                        LabeledContent("Plate", value: vehicle.licensePlate)
                    }
                }

                Section("Trip Start") {
                    DatePicker("Start Date & Time",
                               selection: $dateStart,
                               displayedComponents: [.date, .hourAndMinute])
                    TextField("Start Mileage",
                              value: $mileageStart,
                              format: .number.grouping(.never))
                        #if canImport(UIKit)
                        .keyboardType(.numberPad)
                        #endif
                }

                if wasOngoing {
                    Section {
                        Toggle(isOn: $endTripNow) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("End Trip Manually")
                                    .font(.headline)
                                Text("Close out this ongoing trip and record the final mileage.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Section("Status") {
                        Toggle("Is this trip ongoing?", isOn: $isOngoing)
                    }
                }

                if showsEndFields {
                    Section(isEndingOngoingTrip ? "End Trip" : "Trip End") {
                        DatePicker("End Date & Time",
                                   selection: $dateEnd,
                                   displayedComponents: [.date, .hourAndMinute])
                        TextField("End Mileage",
                                  value: $mileageEnd,
                                  format: .number.grouping(.never))
                            #if canImport(UIKit)
                            .keyboardType(.numberPad)
                            #endif
                        if let distance = computedDistance(start: mileageStart, end: mileageEnd) {
                            LabeledContent("Total Distance", value: "\(distance) mi")
                        }
                    }
                }

                Section("Driver / Notes") {
                    TextField("Driver name or notes",
                              text: $notes,
                              axis: .vertical)
                        .lineLimit(1...5)
                }

                if showsEndFields,
                   let mileageStart, let mileageEnd, mileageEnd < mileageStart {
                    Section {
                        Label("End mileage must be greater than or equal to start mileage.",
                              systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if let errorMessage = fleetViewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private var canSave: Bool {
        guard let mileageStart, mileageStart >= 0 else { return false }
        if showsEndFields {
            guard let mileageEnd, mileageEnd >= mileageStart else { return false }
            if dateEnd < dateStart { return false }
        }
        return true
    }

    private func computedDistance(start: Int?, end: Int?) -> Int? {
        guard let start, let end, end >= start else { return nil }
        return end - start
    }

    private func save() {
        guard let mileageStart else { return }
        isSaving = true
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = trimmed.isEmpty ? nil : trimmed

        // Decide the trip's final ongoing state.
        let finalIsOngoing: Bool
        if wasOngoing {
            finalIsOngoing = !endTripNow
        } else {
            finalIsOngoing = isOngoing
        }

        var updated = trip
        updated.dateStart = dateStart
        updated.mileageStart = mileageStart
        updated.notes = notesToSave
        updated.isOngoing = finalIsOngoing
        if finalIsOngoing {
            updated.status = Trip.statusActive
            updated.dateEnd = nil
            updated.mileageEnd = nil
        } else {
            updated.status = Trip.statusCompleted
            updated.dateEnd = dateEnd
            updated.mileageEnd = mileageEnd
        }

        Task {
            let success = await fleetViewModel.updateTrip(updated)
            isSaving = false
            if success { dismiss() }
        }
    }
}

#Preview {
    EditTripView(
        trip: Trip(
            id: "preview",
            vehicleID: "vehicle",
            dateStart: .now,
            dateEnd: nil,
            mileageStart: 12000,
            mileageEnd: nil,
            status: Trip.statusActive,
            notes: nil,
            isOngoing: true
        ),
        fleetViewModel: FleetViewModel()
    )
}

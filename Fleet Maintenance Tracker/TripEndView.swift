//
//  TripEndView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import SwiftUI

struct TripEndView: View {
    let vehicleID: String
    let fleetViewModel: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dateEnd: Date = .now
    @State private var mileageEnd: Int? = nil
    // Used by the fallback path when no active trip exists.
    @State private var dateStart: Date = .now
    @State private var mileageStart: Int? = nil
    @State private var isSaving = false
    @State private var didPrefill = false
    @State private var showMileageAlert = false

    private var vehicle: Vehicle? {
        fleetViewModel.vehicles.first { $0.id == vehicleID }
    }

    private var activeTrip: Trip? {
        fleetViewModel.activeTrip(for: vehicleID)
    }

    var body: some View {
        NavigationStack {
            if let vehicle {
                Form {
                    Section("Vehicle") {
                        LabeledContent("Vehicle", value: "\(vehicle.make) \(vehicle.model)")
                        LabeledContent("Plate", value: vehicle.licensePlate)
                    }

                    if let trip = activeTrip {
                        Section("Active Trip") {
                            LabeledContent("Start Date",
                                           value: formattedDate(trip.dateStart))
                            LabeledContent("Start Mileage",
                                           value: trip.mileageStart.map { "\($0) mi" } ?? "—")
                        }

                        Section("End Trip") {
                            DatePicker("End Date & Time",
                                       selection: $dateEnd,
                                       displayedComponents: [.date, .hourAndMinute])
                            TextField("End Mileage",
                                      value: $mileageEnd,
                                      format: .number.grouping(.never))
                                #if canImport(UIKit)
                                .keyboardType(.numberPad)
                                #endif
                            if let distance = computedDistance(start: trip.mileageStart,
                                                               end: mileageEnd) {
                                LabeledContent("Total Distance", value: "\(distance) mi")
                            }
                        }
                    } else {
                        Section {
                            Label("No active trip found. Logging this as a completed trip.",
                                  systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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

                        Section("Trip End") {
                            DatePicker("End Date & Time",
                                       selection: $dateEnd,
                                       displayedComponents: [.date, .hourAndMinute])
                            TextField("End Mileage",
                                      value: $mileageEnd,
                                      format: .number.grouping(.never))
                                #if canImport(UIKit)
                                .keyboardType(.numberPad)
                                #endif
                            if let distance = computedDistance(start: mileageStart,
                                                               end: mileageEnd) {
                                LabeledContent("Total Distance", value: "\(distance) mi")
                            }
                        }
                    }

                    if let errorMessage = fleetViewModel.errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("End Trip")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(!canSave || isSaving)
                    }
                }
                .onAppear { prefillIfNeeded() }
                .alert("Invalid Mileage", isPresented: $showMileageAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Ending mileage cannot be lower than starting mileage.")
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
        guard let mileageEnd, mileageEnd >= 0 else { return false }
        if activeTrip == nil {
            guard let mileageStart, mileageStart >= 0 else { return false }
        }
        return true
    }

    private func prefillIfNeeded() {
        guard !didPrefill else { return }
        didPrefill = true
        if activeTrip == nil, mileageStart == nil {
            mileageStart = fleetViewModel.latestMileage(for: vehicleID)
        }
    }

    private func computedDistance(start: Int?, end: Int?) -> Int? {
        guard let start, let end, end >= start else { return nil }
        return end - start
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func save() {
        guard let mileageEnd else { return }
        let comparisonStart: Int? = activeTrip?.mileageStart ?? mileageStart
        if let comparisonStart, mileageEnd < comparisonStart {
            showMileageAlert = true
            return
        }
        isSaving = true
        Task {
            let success: Bool
            if let trip = activeTrip {
                success = await fleetViewModel.endTrip(
                    trip,
                    dateEnd: dateEnd,
                    mileageEnd: mileageEnd
                )
            } else if let mileageStart {
                success = await fleetViewModel.addCompletedTrip(
                    vehicleID: vehicleID,
                    dateStart: dateStart,
                    dateEnd: dateEnd,
                    mileageStart: mileageStart,
                    mileageEnd: mileageEnd
                )
            } else {
                success = false
            }
            isSaving = false
            if success { dismiss() }
        }
    }
}

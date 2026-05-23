//
//  TripStartView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import SwiftUI

struct TripStartView: View {
    let vehicleID: String
    let fleetViewModel: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var dateStart: Date = .now
    @State private var mileageStart: Int? = nil
    @State private var isSaving = false
    @State private var didPrefillMileage = false

    private var vehicle: Vehicle? {
        fleetViewModel.vehicles.first { $0.id == vehicleID }
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

                    if let errorMessage = fleetViewModel.errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle("Start Trip")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Start") { save() }
                            .disabled(!canSave || isSaving)
                    }
                }
                .onAppear { prefillIfNeeded() }
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
        guard let mileageStart, mileageStart >= 0 else { return false }
        return true
    }

    private func prefillIfNeeded() {
        guard !didPrefillMileage else { return }
        didPrefillMileage = true
        if mileageStart == nil {
            mileageStart = fleetViewModel.latestMileage(for: vehicleID)
        }
    }

    private func save() {
        guard let mileageStart else { return }
        isSaving = true
        Task {
            let success = await fleetViewModel.startTrip(
                vehicleID: vehicleID,
                dateStart: dateStart,
                mileageStart: mileageStart
            )
            isSaving = false
            if success { dismiss() }
        }
    }
}

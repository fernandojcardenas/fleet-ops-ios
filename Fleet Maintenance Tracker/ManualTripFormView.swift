//
//  ManualTripFormView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import SwiftUI

struct ManualTripFormView: View {
    let fleetViewModel: FleetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedVehicleID: String = ""
    @State private var dateStart: Date = .now
    @State private var dateEnd: Date = .now
    @State private var isOngoing: Bool = false
    @State private var mileageStart: Int? = nil
    @State private var mileageEnd: Int? = nil
    @State private var notes: String = ""
    @State private var isSaving = false

    private var sortedVehicles: [Vehicle] {
        fleetViewModel.vehicles.sorted {
            "\($0.make) \($0.model)".localizedCaseInsensitiveCompare("\($1.make) \($1.model)") == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if fleetViewModel.vehicles.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Vehicles",
                            systemImage: "car",
                            description: Text("Add a vehicle to log a trip.")
                        )
                    }
                } else {
                    Section("Vehicle") {
                        Picker("Vehicle", selection: $selectedVehicleID) {
                            Text("Select a vehicle").tag("")
                            ForEach(sortedVehicles) { vehicle in
                                Text("\(String(vehicle.year)) \(vehicle.make) \(vehicle.model) — \(vehicle.licensePlate)")
                                    .tag(vehicle.id)
                            }
                        }
                        if !selectedVehicleID.isEmpty,
                           let last = fleetViewModel.latestMileage(for: selectedVehicleID) {
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

                    Section("Trip End") {
                        Toggle("Is this trip ongoing?", isOn: $isOngoing)
                        if !isOngoing {
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

                    Section("Driver / Notes") {
                        TextField("Driver name or notes",
                                  text: $notes,
                                  axis: .vertical)
                            .lineLimit(1...5)
                    }

                    if !canSaveMileageValid, !isOngoing,
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
            }
            .navigationTitle("Log Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
            .onChange(of: selectedVehicleID) { _, newValue in
                guard !newValue.isEmpty else { return }
                mileageStart = fleetViewModel.latestMileage(for: newValue)
            }
        }
    }

    private var canSaveMileageValid: Bool {
        guard let mileageStart, mileageStart >= 0 else { return false }
        if !isOngoing {
            guard let mileageEnd, mileageEnd >= mileageStart else { return false }
        }
        return true
    }

    private var canSave: Bool {
        guard !selectedVehicleID.isEmpty else { return false }
        guard canSaveMileageValid else { return false }
        if !isOngoing, dateEnd < dateStart { return false }
        return true
    }

    private func computedDistance(start: Int?, end: Int?) -> Int? {
        guard let start, let end, end >= start else { return nil }
        return end - start
    }

    private func save() {
        guard !selectedVehicleID.isEmpty, let mileageStart else { return }
        isSaving = true
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesToSave: String? = trimmed.isEmpty ? nil : trimmed
        Task {
            let success: Bool
            if isOngoing {
                success = await fleetViewModel.startTrip(
                    vehicleID: selectedVehicleID,
                    dateStart: dateStart,
                    mileageStart: mileageStart,
                    notes: notesToSave
                )
            } else if let mileageEnd {
                success = await fleetViewModel.addCompletedTrip(
                    vehicleID: selectedVehicleID,
                    dateStart: dateStart,
                    dateEnd: dateEnd,
                    mileageStart: mileageStart,
                    mileageEnd: mileageEnd,
                    notes: notesToSave
                )
            } else {
                success = false
            }
            isSaving = false
            if success { dismiss() }
        }
    }
}

#Preview {
    ManualTripFormView(fleetViewModel: FleetViewModel())
}

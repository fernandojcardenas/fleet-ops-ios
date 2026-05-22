//
//  AddVehicleView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI

struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    let fleetViewModel: FleetViewModel

    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int? = nil
    @State private var vin: String = ""
    @State private var licensePlate: String = ""
    @State private var owner: String = ""
    @State private var color: String = ""
    @State private var lockboxCode: String = ""
    @State private var serviceInterval: Int? = 5000
    @State private var status: VehicleStatus = .active
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Details") {
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    TextField("Year", value: $year, format: .number.grouping(.never))
                    TextField("VIN", text: $vin)
                    TextField("License Plate", text: $licensePlate)
                    TextField("Color", text: $color)
                }

                Section("Ownership & Access") {
                    TextField("Owner", text: $owner)
                    TextField("Lockbox Code", text: $lockboxCode)
                }

                Section("Operational") {
                    Picker("Status", selection: $status) {
                        ForEach(VehicleStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    TextField("Service Interval (miles)", value: $serviceInterval, format: .number.grouping(.never))
                }

                if let errorMessage = fleetViewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Vehicle")
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
        !make.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty &&
        year != nil
    }

    private func save() {
        guard let year else { return }
        isSaving = true
        Task {
            let success = await fleetViewModel.addVehicle(
                make: make,
                model: model,
                year: year,
                vin: vin,
                licensePlate: licensePlate,
                serviceInterval: serviceInterval,
                status: status,
                owner: owner,
                color: color,
                lockboxCode: lockboxCode
            )
            isSaving = false
            if success { dismiss() }
        }
    }
}

#Preview {
    AddVehicleView(fleetViewModel: FleetViewModel())
}

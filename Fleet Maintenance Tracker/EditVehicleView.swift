//
//  EditVehicleView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI

struct EditVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    let originalVehicle: Vehicle
    let fleetViewModel: FleetViewModel

    @State private var make: String
    @State private var model: String
    @State private var year: Int?
    @State private var vin: String
    @State private var licensePlate: String
    @State private var owner: String
    @State private var color: String
    @State private var lockboxCode: String
    @State private var serviceInterval: Int?
    @State private var status: VehicleStatus
    @State private var isSaving: Bool = false

    init(vehicle: Vehicle, fleetViewModel: FleetViewModel) {
        self.originalVehicle = vehicle
        self.fleetViewModel = fleetViewModel
        _make = State(initialValue: vehicle.make)
        _model = State(initialValue: vehicle.model)
        _year = State(initialValue: vehicle.year)
        _vin = State(initialValue: vehicle.vin)
        _licensePlate = State(initialValue: vehicle.licensePlate)
        _owner = State(initialValue: vehicle.owner ?? "")
        _color = State(initialValue: vehicle.color ?? "")
        _lockboxCode = State(initialValue: vehicle.lockboxCode ?? "")
        _serviceInterval = State(initialValue: vehicle.serviceInterval)
        _status = State(initialValue: vehicle.effectiveStatus)
    }

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
            .navigationTitle("Edit Vehicle")
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
        let updated = Vehicle(
            id: originalVehicle.id,
            make: make,
            model: model,
            year: year,
            vin: vin,
            licensePlate: licensePlate,
            addedBy: originalVehicle.addedBy,
            serviceInterval: serviceInterval,
            status: status,
            owner: owner,
            color: color,
            lockboxCode: lockboxCode,
            qrCode: originalVehicle.qrCode
        )
        Task {
            let success = await fleetViewModel.updateVehicle(updated)
            isSaving = false
            if success { dismiss() }
        }
    }
}

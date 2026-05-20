//
//  AddServiceTemplateView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/14/26.
//

import SwiftUI

struct AddServiceTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    let fleetViewModel: FleetViewModel

    @State private var serviceName: String = ""
    @State private var mileageInterval: Int? = 5000
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Service Name (e.g. Oil Change)", text: $serviceName)
                    TextField("Mileage Interval", value: $mileageInterval, format: .number.grouping(.never))
                }
                if let errorMessage = fleetViewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Template")
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
        !serviceName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (mileageInterval ?? 0) > 0
    }

    private func save() {
        guard let mileageInterval else { return }
        isSaving = true
        Task {
            let success = await fleetViewModel.addServiceTemplate(
                serviceName: serviceName,
                mileageInterval: mileageInterval
            )
            isSaving = false
            if success { dismiss() }
        }
    }
}

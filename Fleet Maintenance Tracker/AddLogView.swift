//
//  AddLogView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AddLogView: View {
    @Environment(\.dismiss) private var dismiss
    let vehicleID: String
    let fleetViewModel: FleetViewModel

    @State private var serviceType: String = ""
    @State private var date: Date = .now
    @State private var mileage: Int? = nil
    @State private var cost: Double? = nil
    @State private var notes: String = ""
    @State private var isSaving: Bool = false

    #if canImport(UIKit)
    @State private var receiptImage: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingSourceDialog = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    TextField("Service Type (e.g. Oil Change)", text: $serviceType)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Details") {
                    TextField("Mileage", value: $mileage, format: .number.grouping(.never))
                    TextField("Cost", value: $cost, format: .currency(code: "USD"))
                }
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                #if canImport(UIKit)
                Section("Receipt") {
                    Button {
                        showingSourceDialog = true
                    } label: {
                        Label("Capture Receipt", systemImage: "camera")
                    }

                    if let receiptImage {
                        HStack(spacing: 12) {
                            Image(uiImage: receiptImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Spacer()
                            Button(role: .destructive) {
                                self.receiptImage = nil
                            } label: {
                                Text("Remove")
                            }
                        }
                    }
                }
                #endif

                if let errorMessage = fleetViewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
            #if canImport(UIKit)
            .confirmationDialog("Capture Receipt",
                                isPresented: $showingSourceDialog,
                                titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        imagePickerSource = .camera
                        showingImagePicker = true
                    }
                }
                Button("Choose from Library") {
                    imagePickerSource = .photoLibrary
                    showingImagePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $receiptImage, sourceType: imagePickerSource)
                    .ignoresSafeArea()
            }
            #endif
        }
    }

    private var canSave: Bool {
        !serviceType.trimmingCharacters(in: .whitespaces).isEmpty &&
        mileage != nil &&
        cost != nil
    }

    private func save() {
        guard let mileage, let cost else { return }
        isSaving = true

        #if canImport(UIKit)
        let imageData = receiptImage?.jpegData(compressionQuality: 0.8)
        #else
        let imageData: Data? = nil
        #endif

        Task {
            let success = await fleetViewModel.addLog(
                vehicleID: vehicleID,
                serviceType: serviceType,
                date: date,
                mileage: mileage,
                cost: cost,
                notes: notes,
                receiptImageData: imageData
            )
            isSaving = false
            if success { dismiss() }
        }
    }
}

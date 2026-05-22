//
//  EditLogView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/22/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct EditLogView: View {
    @Environment(\.dismiss) private var dismiss
    let originalLog: MaintenanceLog
    let fleetViewModel: FleetViewModel

    @State private var serviceType: String
    @State private var date: Date
    @State private var mileage: Int?
    @State private var cost: Double?
    @State private var notes: String
    @State private var isSaving: Bool = false
    @State private var receiptRemoved: Bool = false

    #if canImport(UIKit)
    @State private var newReceiptImage: UIImage? = nil
    @State private var showingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingSourceDialog = false
    #endif

    init(log: MaintenanceLog, fleetViewModel: FleetViewModel) {
        self.originalLog = log
        self.fleetViewModel = fleetViewModel
        _serviceType = State(initialValue: log.serviceType)
        _date = State(initialValue: log.date)
        _mileage = State(initialValue: log.mileage)
        _cost = State(initialValue: log.cost)
        _notes = State(initialValue: log.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    TextField("Service Type", text: $serviceType)
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
                    if let newReceiptImage {
                        HStack(spacing: 12) {
                            Image(uiImage: newReceiptImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Spacer()
                            Button(role: .destructive) {
                                self.newReceiptImage = nil
                            } label: {
                                Text("Discard")
                            }
                        }
                    } else if let urlString = originalLog.receiptURL,
                              !urlString.isEmpty,
                              !receiptRemoved {
                        Text("Existing receipt attached.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            receiptRemoved = true
                        } label: {
                            Label("Remove Receipt", systemImage: "trash")
                        }
                    }
                    Button {
                        showingSourceDialog = true
                    } label: {
                        Label("Replace Receipt", systemImage: "camera")
                    }
                }
                #endif

                if let errorMessage = fleetViewModel.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Log")
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
            .confirmationDialog("Replace Receipt",
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
                ImagePicker(image: $newReceiptImage, sourceType: imagePickerSource)
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
        let imageData = newReceiptImage?.jpegData(compressionQuality: 0.8)
        #else
        let imageData: Data? = nil
        #endif

        var updated = originalLog
        updated.serviceType = serviceType
        updated.date = date
        updated.mileage = mileage
        updated.cost = cost
        updated.notes = notes
        if receiptRemoved && imageData == nil {
            updated.receiptURL = nil
        }

        Task {
            let success = await fleetViewModel.updateLog(updated, newReceiptImageData: imageData)
            isSaving = false
            if success { dismiss() }
        }
    }
}

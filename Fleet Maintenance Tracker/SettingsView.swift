//
//  SettingsView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @AppStorage("showOnlyActive") private var showOnlyActive = false
    @AppStorage("companyName") private var companyName: String = "My Fleet"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem? = nil
    #if canImport(UIKit)
    @State private var logoImage: UIImage? = nil
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Company Name", text: $companyName)

                    #if canImport(UIKit)
                    HStack(spacing: 12) {
                        Group {
                            if let logoImage {
                                Image(uiImage: logoImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading) {
                            Text("Company Logo")
                                .font(.subheadline)
                            PhotosPicker("Choose Logo", selection: $pickerItem, matching: .images)
                                .font(.footnote)
                        }

                        Spacer()

                        if logoImage != nil {
                            Button(role: .destructive) {
                                CompanyProfile.deleteLogo()
                                logoImage = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                    #endif
                }

                Section("Display") {
                    Toggle("Show only Active vehicles", isOn: $showOnlyActive)
                }

                Section("Help") {
                    Button {
                        hasSeenOnboarding = false
                        dismiss()
                    } label: {
                        Label("Show Onboarding Again", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if canImport(UIKit)
            .onAppear { logoImage = CompanyProfile.loadLogo() }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    CompanyProfile.saveLogo(image)
                    logoImage = image
                }
            }
            #endif
        }
    }
}

#Preview {
    SettingsView()
}

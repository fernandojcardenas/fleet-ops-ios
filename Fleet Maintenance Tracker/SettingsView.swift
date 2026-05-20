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
    @Environment(AuthManager.self) private var authManager

    @State private var pickerItem: PhotosPickerItem? = nil
    #if canImport(UIKit)
    @State private var logoImage: UIImage? = nil
    #endif

    @State private var showDeleteConfirm = false
    @State private var showReauthPrompt = false
    @State private var reauthPassword: String = ""
    @State private var deleteErrorMessage: String? = nil
    @State private var isDeleting = false

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

                Section("Account") {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(isDeleting)

                    if let deleteErrorMessage {
                        Text(deleteErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await performDeleteAccount() }
                }
            } message: {
                Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
            }
            .alert("Confirm Your Password", isPresented: $showReauthPrompt) {
                SecureField("Password", text: $reauthPassword)
                    .textContentType(.password)
                Button("Cancel", role: .cancel) {
                    reauthPassword = ""
                }
                Button("Confirm") {
                    Task { await performReauthAndDelete() }
                }
            } message: {
                Text("For your security, please re-enter your password to delete your account.")
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

    private func performDeleteAccount() async {
        deleteErrorMessage = nil
        isDeleting = true
        defer { isDeleting = false }
        let result = await authManager.deleteAccount()
        switch result {
        case .success:
            dismiss()
        case .requiresReauth:
            showReauthPrompt = true
        case .failed(let message):
            deleteErrorMessage = message
        }
    }

    private func performReauthAndDelete() async {
        deleteErrorMessage = nil
        isDeleting = true
        defer {
            isDeleting = false
            reauthPassword = ""
        }
        let password = reauthPassword
        let reauthed = await authManager.reauthenticate(password: password)
        guard reauthed else {
            deleteErrorMessage = authManager.errorMessage ?? "Re-authentication failed."
            return
        }
        let result = await authManager.deleteAccount()
        switch result {
        case .success:
            dismiss()
        case .requiresReauth:
            deleteErrorMessage = "Re-authentication is still required. Please log out and back in, then try again."
        case .failed(let message):
            deleteErrorMessage = message
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
}

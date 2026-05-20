//
//  RootView.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI

struct RootView: View {
    @State private var authManager = AuthManager()
    @AppStorage("pendingVehicleID") private var pendingVehicleID: String = ""
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .environment(authManager)
        #if os(macOS)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        #else
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        #endif
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
        }
        .onChange(of: showOnboarding) { _, isShown in
            if !isShown { hasSeenOnboarding = true }
        }
        .onChange(of: hasSeenOnboarding) { _, seen in
            if !seen { showOnboarding = true }
        }
        .onOpenURL { url in
            guard url.scheme == QRGenerator.deepLinkScheme,
                  url.host == "vehicle" else { return }
            let id = url.lastPathComponent
            if !id.isEmpty {
                pendingVehicleID = id
            }
        }
    }
}

#Preview {
    RootView()
}

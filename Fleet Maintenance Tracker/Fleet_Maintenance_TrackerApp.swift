//
//  Fleet_Maintenance_TrackerApp.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Firebase setup
//
// Production reads GoogleService-Info.plist and uses Firestore with on-device
// persistence for offline use. Debug builds launched with the
// `-useFirebaseEmulators` argument instead configure a placeholder "demo-"
// project and talk to the local Firebase Emulator Suite (firebase/README.md),
// so demo data and screenshots never touch production and no plist has to be
// swapped. Release builds compile the emulator branch out entirely.

private var usesFirebaseEmulators: Bool {
    #if DEBUG
    return ProcessInfo.processInfo.arguments.contains("-useFirebaseEmulators")
    #else
    return false
    #endif
}

private func configureFirebaseApp() {
    #if DEBUG
    if usesFirebaseEmulators {
        // "demo-" project IDs are reserved by Firebase for emulator-only use.
        let options = FirebaseOptions(googleAppID: "1:000000000000:ios:0000000000000000",
                                      gcmSenderID: "000000000000")
        options.apiKey = "demo-api-key-not-a-secret"
        options.projectID = "demo-fleet-ops"
        options.storageBucket = "demo-fleet-ops.appspot.com"
        options.bundleID = Bundle.main.bundleIdentifier ?? ""
        FirebaseApp.configure(options: options)
        return
    }
    #endif
    FirebaseApp.configure()
}

private func configureFirebaseBackends() {
    let firestore = Firestore.firestore()
    let settings = firestore.settings
    #if DEBUG
    if usesFirebaseEmulators {
        let host = "127.0.0.1"
        settings.host = "\(host):8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        firestore.settings = settings
        Auth.auth().useEmulator(withHost: host, port: 9099)
        Storage.storage().useEmulator(withHost: host, port: 9199)
        print("[Firebase] Using local emulators on \(host)")
        return
    }
    #endif
    settings.cacheSettings = PersistentCacheSettings()
    firestore.settings = settings
}

#if canImport(UIKit)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        configureFirebaseApp()
        configureFirebaseBackends()
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            await NotificationManager.shared.requestAuthorization()
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
#endif

@main
struct Fleet_Maintenance_TrackerApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #else
    init() {
        configureFirebaseApp()
        configureFirebaseBackends()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

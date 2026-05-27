//
//  Fleet_Maintenance_TrackerApp.swift
//  Fleet Maintenance Tracker
//
//  Created by Fernando Cardenas on 5/13/26.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

private func configureFirestoreOfflinePersistence() {
    let settings = Firestore.firestore().settings
    settings.cacheSettings = PersistentCacheSettings()
    Firestore.firestore().settings = settings
}

#if canImport(UIKit)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        configureFirestoreOfflinePersistence()
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
        FirebaseApp.configure()
        configureFirestoreOfflinePersistence()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

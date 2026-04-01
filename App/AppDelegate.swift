//
//  AppDelegate.swift
//  WiFiQualityMonitor
//

import UIKit
// import FirebaseCrashlytics  // TODO: Uncomment after Firebase setup

/// AppDelegate for Firebase Crashlytics initialization
/// and handling app lifecycle privacy requirements
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // TODO: Initialize Firebase Crashlytics
        // FirebaseApp.configure()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Privacy: clear all measurement data
        // Handled via NotificationCenter in NetworkViewModel
    }
}

//
//  AppDelegate.swift
//  WiFi Check
//

import UIKit
import Network
import SwiftData
// import FirebaseCrashlytics  // TODO: Uncomment after Firebase setup

/// AppDelegate for Firebase Crashlytics initialization
/// and handling app lifecycle privacy requirements
class AppDelegate: NSObject, UIApplicationDelegate {

    /// Pre-warmed model container — avoids SwiftData init blocking the first TabRootView frame
    static private(set) var modelContainer: ModelContainer?

    private var necpWarmupMonitor: NWPathMonitor?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 1. Pre-create Application Support so SwiftData never hits its fail+retry cycle
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        // 2. Pre-warm NECP network stack — avoids the 3-4s stall when NWPathMonitor
        //    first starts (NetworkMonitor + VPNDetectionService both use one).
        necpWarmupMonitor = NWPathMonitor()
        necpWarmupMonitor?.start(queue: DispatchQueue(label: "com.wificheck.necp.warmup"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.necpWarmupMonitor?.cancel()
            self?.necpWarmupMonitor = nil
        }

        // 3. Pre-warm SwiftData when the user has already seen onboarding,
        //    so TabRootView gets an already-initialized container instantly.
        if UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            AppDelegate.modelContainer = try? ModelContainer(for: SavedDevice.self)
        }

        // TODO: Initialize Firebase Crashlytics
        // FirebaseApp.configure()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Privacy: clear all measurement data
        // Handled via NotificationCenter in NetworkViewModel
    }
}

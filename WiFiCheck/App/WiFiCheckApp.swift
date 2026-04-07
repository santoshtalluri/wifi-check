//
//  WiFiCheckApp.swift
//  WiFi Check v1
//

import SwiftUI
import SwiftData

@main
struct WiFiCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                TabRootView()
                    .modelContainer(
                        AppDelegate.modelContainer
                            ?? (try! ModelContainer(for: SavedDevice.self))
                    )
            } else {
                OnboardingView()
            }
        }
    }
}

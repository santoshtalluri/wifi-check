//
//  WiFiCheckTVApp.swift
//  WiFi Check TV
//

import SwiftUI
import SwiftData
import CoreLocation

@main
struct WiFiCheckTVApp: App {
    @StateObject private var networkVM = NetworkViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("wqm-color-scheme") private var colorSchemeRaw: String = "system"

    private var activeColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Dashboard", systemImage: "gauge.medium") {
                    DashboardView(networkVM: networkVM)
                }
                Tab("Bandwidth", systemImage: "arrow.up.arrow.down.circle") {
                    BandwidthView(networkVM: networkVM)
                }
                Tab("Speed Test", systemImage: "bolt.fill") {
                    SpeedTestView(networkVM: networkVM)
                }
                Tab("Network Scan", systemImage: "magnifyingglass") {
                    NetworkScanView(networkVM: networkVM)
                }
                Tab("Settings", systemImage: "gearshape") {
                    TVSettingsView(networkVM: networkVM)
                }
            }
            .tabViewStyle(.tabBarOnly)
            .preferredColorScheme(activeColorScheme)
            .onAppear {
                LocationAuthorizationManager.shared.requestAuthorization()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    networkVM.clearAllData()
                    networkVM.resumeMeasurements()
                case .inactive, .background:
                    networkVM.pauseMeasurements()
                @unknown default: break
                }
            }
        }
        .modelContainer(for: SavedDevice.self)
    }
}

//
//  TabRootView.swift
//  WiFi Check v1
//

import SwiftUI

struct TabRootView: View {
    @StateObject private var networkVM = NetworkViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @GestureState private var dragOffset: CGFloat = 0

    // Font preferences — read here so the entire TabView tree picks up changes
    @AppStorage("wqm-font-family")  private var fontFamilyRaw: String  = "sfpro"
    @AppStorage("wqm-font-size")    private var fontSizeRaw: String    = "medium"
    @AppStorage("wqm-color-scheme") private var colorSchemeRaw: String = "system"

    /// The Font.Design resolved from the stored font family preference.
    private var activeFontDesign: Font.Design {
        AppFontFamily(rawValue: fontFamilyRaw)?.fontDesign ?? .default
    }

    /// The CGFloat scale multiplier resolved from the stored font size preference.
    private var activeFontScale: CGFloat {
        AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0
    }

    /// The resolved ColorScheme override — nil means follow system.
    private var activeColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WiFiInfoTab(networkVM: networkVM)
                .tag(0)
                .tabItem {
                    Image(systemName: networkVM.isConnectedToWiFi ? "wifi" : "wifi.slash")
                    Text("WiFi Info")
                }

            SpeedTestTab()
                .tag(1)
                .tabItem {
                    Image(systemName: "bolt.fill")
                    Text("Speed Test")
                }

            NetworkScanTab(networkVM: networkVM)
                .tag(2)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Network Scan")
                }
                .badge(networkVM.isConnectedToWiFi ? nil : "!")

            SettingsView(networkVM: networkVM)
                .tag(3)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        // Propagate font design, font scale, and color scheme to every view in the app.
        .fontDesign(activeFontDesign)
        .environment(\.appFontScale, activeFontScale)
        .preferredColorScheme(activeColorScheme)
        .tint(Color(hex: networkVM.accentColorHex))
        .offset(x: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .updating($dragOffset) { value, state, _ in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > vertical else { return }
                    // Rubber-band effect: dampen drag the further you pull
                    let resistance: CGFloat = 0.3
                    state = horizontal * resistance
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = abs(value.translation.height)
                    guard abs(horizontal) > vertical else { return }

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        if horizontal < -50 && selectedTab < 3 {
                            selectedTab += 1
                        } else if horizontal > 50 && selectedTab > 0 {
                            selectedTab -= 1
                        }
                    }
                }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: dragOffset)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                networkVM.clearAllData()
                networkVM.resumeMeasurements()
            case .inactive:
                networkVM.pauseMeasurements()
            case .background:
                networkVM.pauseMeasurements()
            @unknown default:
                break
            }
        }
        .onChange(of: fontSizeRaw) { _, _ in
            applyTabBarFontScale()
        }
        .onAppear {
            networkVM.requestPermissions()
            applyTabBarFontScale()
        }
    }

    // MARK: - Tab bar font scaling

    private func applyTabBarFontScale() {
        let fontSize = 10.0 * activeFontScale
        let font = UIFont.systemFont(ofSize: fontSize)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes   = [.font: font]
        itemAppearance.selected.titleTextAttributes = [.font: font]
        appearance.stackedLayoutAppearance        = itemAppearance
        appearance.inlineLayoutAppearance         = itemAppearance
        appearance.compactInlineLayoutAppearance  = itemAppearance

        // Update existing live tab bars in the view hierarchy
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                updateTabBar(in: window, appearance: appearance)
            }
        }

        // Also set for any future tab bars
        UITabBar.appearance().standardAppearance    = appearance
        UITabBar.appearance().scrollEdgeAppearance  = appearance
    }

    private func updateTabBar(in view: UIView, appearance: UITabBarAppearance) {
        if let tabBar = view as? UITabBar {
            tabBar.standardAppearance   = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
        for subview in view.subviews {
            updateTabBar(in: subview, appearance: appearance)
        }
    }
}

//
//  TabRootView.swift
//  WiFi Check v1
//

import SwiftUI
import UIKit

struct TabRootView: View {
    @StateObject private var networkVM = NetworkViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0

    // Font preferences — read here so the entire tab tree picks up changes
    @AppStorage("wqm-font-family")  private var fontFamilyRaw: String  = "sfpro"
    @AppStorage("wqm-font-size")    private var fontSizeRaw: String    = "medium"
    @AppStorage("wqm-color-scheme") private var colorSchemeRaw: String = "system"

    private var activeFontDesign: Font.Design {
        AppFontFamily(rawValue: fontFamilyRaw)?.fontDesign ?? .default
    }
    private var activeFontScale: CGFloat {
        AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0
    }
    private var activeColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
    private var accentColor: Color { Color(hex: networkVM.accentColorHex) }

    var body: some View {
        TabView(selection: $selectedTab) {
            WiFiInfoTab(networkVM: networkVM).tag(0)
            SpeedTestTab(networkVM: networkVM).tag(1)
            NetworkScanTab(networkVM: networkVM).tag(2)
            SettingsView(networkVM: networkVM).tag(3)
        }
        // Native side-by-side paging: content slides with finger, real momentum + spring
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Real UITabBar in the bottom inset — exact native appearance
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NativeTabBarView(
                selectedTab: $selectedTab,
                isConnectedToWiFi: networkVM.isConnectedToWiFi,
                fontScale: activeFontScale,
                accentUIColor: UIColor(accentColor)
            )
        }
        .fontDesign(activeFontDesign)
        .environment(\.appFontScale, activeFontScale)
        .preferredColorScheme(activeColorScheme)
        .tint(accentColor)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                networkVM.clearAllData()
                // Only auto-measure on the WiFi Info home tab
                if selectedTab == 0 {
                    networkVM.resumeMeasurements()
                }
            case .inactive:
                networkVM.pauseMeasurements()
            case .background:
                networkVM.pauseMeasurements()
            @unknown default:
                break
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Pause loop when user leaves home tab; resume when they return
            if newTab == 0 {
                networkVM.resumeMeasurements()
            } else {
                networkVM.pauseMeasurements()
            }
        }
        .onAppear {
            networkVM.requestPermissions()
        }
    }
}

// MARK: - Native UITabBar bridge

/// SwiftUI wrapper that hosts the real UITabBar and extends its glass background
/// behind the home indicator via `ignoresSafeArea`.
private struct NativeTabBarView: View {
    @Binding var selectedTab: Int
    let isConnectedToWiFi: Bool
    let fontScale: CGFloat
    let accentUIColor: UIColor

    var body: some View {
        NativeTabBarRepresentable(
            selectedTab: $selectedTab,
            isConnectedToWiFi: isConnectedToWiFi,
            fontScale: fontScale,
            accentUIColor: accentUIColor
        )
        .frame(height: 49)
        .background {
            // Extend the same bar material into the home indicator safe area,
            // making the glass surface visually continuous to the screen edge.
            Rectangle()
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// `UIViewRepresentable` that renders a real `UITabBar`.
/// Gives the exact iOS frosted-glass appearance, separator line, tint, badge,
/// and font scaling — all handled by UIKit natively.
private struct NativeTabBarRepresentable: UIViewRepresentable {
    @Binding var selectedTab: Int
    let isConnectedToWiFi: Bool
    let fontScale: CGFloat
    let accentUIColor: UIColor

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITabBar {
        // Seed coordinator so updateUIView diffs correctly on first call
        context.coordinator.lastConnected  = isConnectedToWiFi
        context.coordinator.lastSelectedTab = selectedTab
        context.coordinator.lastFontScale   = fontScale
        context.coordinator.lastAccentColor = accentUIColor

        let tabBar = UITabBar()
        tabBar.delegate = context.coordinator
        tabBar.tintColor = accentUIColor
        let items = makeItems()
        tabBar.setItems(items, animated: false)
        tabBar.selectedItem = items[selectedTab]
        applyAppearance(to: tabBar)
        return tabBar
    }

    func updateUIView(_ tabBar: UITabBar, context: Context) {
        let c = context.coordinator

        // Tint — only update when accent color changes
        if !tabBar.tintColor.isEqual(accentUIColor) {
            tabBar.tintColor = accentUIColor
            c.lastAccentColor = accentUIColor
        }

        // Items — only rebuild when connectivity changes (wifi icon / badge)
        if c.lastConnected != isConnectedToWiFi {
            c.lastConnected = isConnectedToWiFi
            let items = makeItems()
            tabBar.setItems(items, animated: false)
            tabBar.selectedItem = items[selectedTab]
            c.lastSelectedTab = selectedTab
            applyAppearance(to: tabBar)
            return  // selectedItem already set above
        }

        // Selection — let UIKit animate its own indicator; no setItems needed
        if c.lastSelectedTab != selectedTab {
            c.lastSelectedTab = selectedTab
            tabBar.selectedItem = tabBar.items?[selectedTab]
        }

        // Appearance — only rebuild when font scale changes
        if c.lastFontScale != fontScale {
            c.lastFontScale = fontScale
            applyAppearance(to: tabBar)
        }
    }

    // MARK: - Helpers

    private func makeItems() -> [UITabBarItem] {
        let wifiIcon = isConnectedToWiFi ? "wifi" : "wifi.slash"

        let item0 = UITabBarItem(title: "WiFi Info",
                                 image: UIImage(systemName: wifiIcon), tag: 0)
        let item1 = UITabBarItem(title: "Speed Test",
                                 image: UIImage(systemName: "bolt.fill"), tag: 1)
        let item2 = UITabBarItem(title: "Network Scan",
                                 image: UIImage(systemName: "magnifyingglass"), tag: 2)
        item2.badgeValue = isConnectedToWiFi ? nil : "!"

        let item3 = UITabBarItem(title: "Settings",
                                 image: UIImage(systemName: "gearshape"), tag: 3)
        return [item0, item1, item2, item3]
    }

    private func applyAppearance(to tabBar: UITabBar) {
        let fontSize = 10.0 * fontScale
        let font = UIFont.systemFont(ofSize: fontSize)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes   = [.font: font]
        itemAppearance.selected.titleTextAttributes = [.font: font]
        appearance.stackedLayoutAppearance        = itemAppearance
        appearance.inlineLayoutAppearance         = itemAppearance
        appearance.compactInlineLayoutAppearance  = itemAppearance

        tabBar.standardAppearance   = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    // MARK: - Delegate

    final class Coordinator: NSObject, UITabBarDelegate {
        var parent: NativeTabBarRepresentable

        // Last-known state — prevents redundant UIKit calls on every SwiftUI update
        var lastConnected:   Bool    = true
        var lastSelectedTab: Int     = 0
        var lastFontScale:   CGFloat = 1.0
        var lastAccentColor: UIColor = .systemGreen

        init(_ parent: NativeTabBarRepresentable) { self.parent = parent }

        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            parent.selectedTab = item.tag
        }
    }
}

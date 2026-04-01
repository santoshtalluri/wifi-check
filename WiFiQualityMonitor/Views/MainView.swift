//
//  MainView.swift
//  WiFiQualityMonitor
//

import SwiftUI
import AppTrackingTransparency

/// Root view — orchestrates all screen states
struct MainView: View {
    @StateObject private var networkVM = NetworkViewModel()
    @StateObject private var speedTestVM = SpeedTestViewModel()
    @StateObject private var purchaseVM = PurchaseViewModel()

    @State private var showDrawer = false

    var body: some View {
        ZStack {
            // Background
            backgroundLayer

            // Content based on state
            if !networkVM.isConnectedToWiFi {
                BlockedView(type: .noWiFi)
            } else {
                mainContent
            }

            // Drawer overlay
            if showDrawer {
                DrawerView(
                    networkVM: networkVM,
                    purchaseVM: purchaseVM,
                    isOpen: $showDrawer
                )
                .transition(.move(edge: .trailing))
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            networkVM.requestPermissions()
            // Request ATT after delay (per spec: after UI is visible)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            networkVM.clearAllData()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            networkVM.clearAllData()
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Orb 1 — accent color, top-left
            Circle()
                .fill(networkVM.accentColor)
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .opacity(0.20)
                .offset(x: -100, y: -200)

            // Orb 2 — purple, bottom-right
            Circle()
                .fill(Color.enterprise)
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .opacity(0.13)
                .offset(x: 100, y: 300)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Nav bar
            navBar

            ScrollView {
                VStack(spacing: 12) {
                    // Ad banner (placeholder)
                    if !purchaseVM.adsRemoved && !networkVM.adBannerDismissed {
                        adBannerPlaceholder
                    }

                    // Public network banner
                    if networkVM.isPublicNetwork {
                        PublicBanner(isDismissed: $networkVM.publicBannerDismissed)
                    }

                    // Enterprise banner
                    if networkVM.isEnterprise {
                        EnterpriseBanner()
                    }

                    // Gauge card
                    GaugeCard(vm: networkVM, isVPN: networkVM.isVPNActive)

                    // Metrics card
                    MetricsCard(
                        metrics: networkVM.metrics,
                        score: networkVM.score,
                        isDimmed: networkVM.isVPNActive
                    )

                    // WiFi Info card
                    WiFiInfoCard(info: networkVM.wifiInfo)

                    // Speed Test card
                    SpeedTestCard(
                        speedVM: speedTestVM,
                        currentScore: networkVM.score.composite
                    )

                    // Footer
                    footerView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Nav Bar

    private var navBar: some View {
        HStack {
            Text("WiFi Quality")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.6)
                .foregroundColor(.textPrimary)

            Spacer()

            // Status chip
            statusChip

            // Hamburger
            Button(action: { withAnimation(.easeInOut(duration: 0.3)) { showDrawer = true } }) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 36, height: 36)
                    .overlay(
                        VStack(spacing: 5) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 16, height: 2)
                            }
                        }
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var statusChip: some View {
        let (text, color): (String, Color) = {
            if networkVM.isVPNActive {
                return ("VPN ACTIVE", .vpnActive)
            } else if networkVM.score.composite < 40 {
                return ("WEAK SIGNAL", .weakSignal)
            } else {
                return ("CONNECTED", networkVM.accentColor)
            }
        }()

        return Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    // MARK: - Ad Banner Placeholder

    private var adBannerPlaceholder: some View {
        HStack {
            Text("Ad Banner")
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
            Spacer()
            Button(action: { networkVM.adBannerDismissed = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(networkVM.accentColor)
                .frame(width: 6, height: 6)

            if networkVM.updateFrequency > 0 {
                Text("Updating in \(networkVM.countdown)s...")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            } else {
                Text("Manual mode — tap Refresh to update")
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.top, 8)
    }
}

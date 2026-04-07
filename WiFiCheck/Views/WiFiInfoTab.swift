//
//  WiFiInfoTab.swift
//  WiFi Check v1
//

import SwiftUI

struct WiFiInfoTab: View {
    @ObservedObject var networkVM: NetworkViewModel
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        ZStack {
            // Background
            Color.appBackground.ignoresSafeArea()

            // Ambient orbs
            backgroundOrbs

            if !networkVM.isConnectedToWiFi {
                BlockedView(type: .noWiFi)
            } else if networkVM.isVPNActive {
                mainContent
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Nav bar
            navBar

            // Sticky GaugeCard
            GaugeCard(vm: networkVM, isVPN: networkVM.isVPNActive)
                .padding(.horizontal, 16)
                .padding(.top, 6)

            // Scrollable content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    // Banners
                    if networkVM.isPublicNetwork && !networkVM.publicBannerDismissed {
                        PublicBanner(isDismissed: $networkVM.publicBannerDismissed)
                    }
                    if networkVM.isEnterprise {
                        EnterpriseBanner()
                    }

                    // Metrics (collapsible)
                    MetricsCard(
                        metrics: networkVM.metrics,
                        score: networkVM.score,
                        isDimmed: networkVM.isVPNActive
                    )

                    // Network Info (collapsible)
                    WiFiInfoCard(info: networkVM.wifiInfo)

                    // Footer
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .refreshable {
                await networkVM.refresh()
            }
        }
    }

    private var navBar: some View {
        HStack {
            Text("WiFi Check")
                .font(.system(size: 26 * scale, weight: .bold))
                .tracking(-0.6)
                .foregroundColor(.textPrimary)

            Spacer()

            statusChip
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var statusChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(chipColor)
                .frame(width: 6, height: 6)
            Text(chipText)
                .font(.system(size: 10 * scale, weight: .bold))
                .tracking(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(chipColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .foregroundColor(chipColor)
        .accessibilityIdentifier("statusChip")
    }

    private var chipText: String {
        if networkVM.isVPNActive { return "VPN ACTIVE" }
        if networkVM.score.composite < 40 { return "WEAK SIGNAL" }
        return "CONNECTED"
    }

    private var chipColor: Color {
        if networkVM.isVPNActive { return .vpnActive }
        if networkVM.score.composite < 40 { return .weakSignal }
        return Color(hex: networkVM.accentColorHex)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: networkVM.accentColorHex))
                .frame(width: 6, height: 6)
            if networkVM.updateFrequency == 0 {
                Text("Manual mode — pull down to refresh")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textSecondary)
            } else {
                Text("Next refresh in \(networkVM.countdown)s")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 6)
    }

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundOrbs: some View {
        let orbOpacity1 = colorScheme == .dark ? 0.20 : 0.08
        let orbOpacity2 = colorScheme == .dark ? 0.13 : 0.06

        return ZStack {
            Circle()
                .fill(Color(hex: networkVM.accentColorHex))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .opacity(orbOpacity1)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.enterprise)
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .opacity(orbOpacity2)
                .offset(x: 100, y: 300)
        }
        .ignoresSafeArea()
    }
}

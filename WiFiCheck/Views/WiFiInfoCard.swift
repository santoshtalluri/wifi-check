//
//  WiFiInfoCard.swift
//  WiFi Check v1
//
//  Displays network info with collapsible advanced section

import SwiftUI

/// Displays network info: SSID, Local IP, Gateway + expandable BSSID, Signal, Security, Public IP
struct WiFiInfoCard: View {
    let info: WiFiInfo

    @AppStorage("networkExpanded") private var showDetails = false
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                // SpeedTestCard-style header
                sectionHeader

                Divider().background(Color.dividerColor)

                // Essential rows (always visible)
                infoRow(label: "Network", value: info.ssid, icon: "wifi")
                Divider().background(Color.dividerColor)
                infoRow(label: "My IP", value: info.localIP, icon: "iphone")
                Divider().background(Color.dividerColor)
                infoRow(label: "Gateway", value: info.gatewayIP, icon: "server.rack")
                if !info.routerManufacturer.isEmpty {
                    Divider().background(Color.dividerColor)
                    infoRow(label: "Router", value: info.routerManufacturer, icon: "wifi.router")
                }

                // Expanded details
                if showDetails {
                    if info.signalStrength > 0 {
                        Divider().background(Color.dividerColor)
                        signalRow
                    }
                    Divider().background(Color.dividerColor)
                    infoRow(label: "Security", value: info.securityType, icon: "lock.shield")
                    if !info.ispName.isEmpty {
                        Divider().background(Color.dividerColor)
                        infoRow(label: "ISP", value: ispDisplayValue, icon: "building.2")
                    }
                    if !info.dnsServers.isEmpty {
                        Divider().background(Color.dividerColor)
                        infoRow(label: "DNS", value: dnsDisplayValue, icon: "server.rack")
                    }
                    Divider().background(Color.dividerColor)
                    infoRow(label: "Public IP", value: info.publicIP, icon: "globe")
                    if !info.localIPv6.isEmpty {
                        Divider().background(Color.dividerColor)
                        infoRow(label: "IPv6", value: info.localIPv6, icon: "network")
                    }
                    Divider().background(Color.dividerColor)
                    infoRow(label: "BSSID", value: info.bssid, icon: "antenna.radiowaves.left.and.right")
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showDetails)
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Button(action: { showDetails.toggle() }) {
            HStack {
                Image(systemName: "wifi")
                    .font(.system(size: 17 * scale))
                    .foregroundColor(.textSecondary)

                Text("Network Info")
                    .font(.system(size: 17 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("More Details")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textSecondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundColor(.textTertiary)
                    .rotationEffect(.degrees(showDetails ? 180 : 0))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .background(Color.textSecondary.opacity(0.08))
        .padding(.horizontal, -16)
        .padding(.top, -16)
        .buttonStyle(.plain)
        .accessibilityIdentifier("networkInfoToggleHeader")
    }

    // MARK: - Info Row

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .font(.system(size: 12 * scale))
                .foregroundColor(.textSecondary)
                .frame(width: 24)
                .padding(.top, 1)

            Text(label)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 13 * scale, weight: .light))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
    }

    // MARK: - ISP / DNS Display Helpers

    private var ispDisplayValue: String {
        guard !info.ispCity.isEmpty else { return info.ispName }
        return "\(info.ispName) · \(info.ispCity)"
    }

    private static let knownDNS: [String: String] = [
        "8.8.8.8": "Google", "8.8.4.4": "Google",
        "1.1.1.1": "Cloudflare", "1.0.0.1": "Cloudflare",
        "9.9.9.9": "Quad9", "149.112.112.112": "Quad9",
        "208.67.222.222": "OpenDNS", "208.67.220.220": "OpenDNS",
    ]

    private var dnsDisplayValue: String {
        info.dnsServers
            .prefix(2)
            .map { ip in
                if let name = Self.knownDNS[ip] { return "\(ip) (\(name))" }
                return ip
            }
            .joined(separator: "\n")
    }

    // MARK: - Signal Strength Row

    private var signalRow: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 12 * scale))
                .foregroundColor(.textSecondary)
                .frame(width: 24)

            Text("WiFi Signal")
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)

            Spacer()

            // Signal bars
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < signalBars ? Color.scoreGood : Color.textTertiary)
                        .frame(width: 3, height: CGFloat(4 + i * 3))
                }
            }
            .frame(height: 14, alignment: .bottom)

            Text(signalValueText)
                .font(.system(size: 13 * scale, weight: .light))
                .foregroundColor(.textPrimary)
                .padding(.leading, 4)
        }
        .padding(.vertical, 9)
    }

    private var signalBars: Int {
        let s = info.signalStrength
        if s >= 0.75 { return 4 }
        if s >= 0.50 { return 3 }
        if s >= 0.25 { return 2 }
        if s > 0 { return 1 }
        return 0
    }

    private var signalLabel: String {
        let s = info.signalStrength
        if s >= 0.75 { return "Excellent" }
        if s >= 0.50 { return "Good" }
        if s >= 0.25 { return "Fair" }
        if s > 0 { return "Weak" }
        return "--"
    }

    private var signalValueText: String {
        let s = info.signalStrength
        if s <= 0 { return "--" }
        let pct = Int(s * 100)
        return "\(pct)% \u{00B7} \(signalLabel)"
    }
}

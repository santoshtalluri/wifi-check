//
//  WiFiInfoCard.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Displays network info: SSID, Local IP, Gateway, Public IP
struct WiFiInfoCard: View {
    let info: WiFiInfo

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                infoRow(label: "Network", value: info.ssid, icon: "wifi")
                Divider().background(Color.white.opacity(0.06))
                infoRow(label: "My IP", value: info.localIP, icon: "iphone")
                Divider().background(Color.white.opacity(0.06))
                infoRow(label: "Gateway", value: info.gatewayIP, icon: "server.rack")
                Divider().background(Color.white.opacity(0.06))
                infoRow(label: "Public IP", value: info.publicIP, icon: "globe")
            }
        }
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.textPrimary)
        }
        .padding(.vertical, 10)
    }
}

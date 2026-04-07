//
//  TVNetworkInfoCard.swift
//  WiFi Check TV
//
//  Full labels, no truncation, TV-sized fonts.
//

import SwiftUI

struct TVNetworkInfoCard: View {
    let info: WiFiInfo

    var body: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text("Network Info")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                .padding(.bottom, 4)

                Divider().background(Color.dividerColor)

                // Show SSID row only on WiFi — on Ethernet/USB-C it has no meaning
                if info.connectionType == "Wi-Fi" {
                    infoRow(icon: "wifi", label: "Network", value: info.ssid.isEmpty ? "Wi-Fi Network" : info.ssid)
                    divider
                }
                infoRow(icon: "desktopcomputer", label: "Device IP", value: info.localIP)
                divider
                infoRow(icon: "server.rack", label: "Gateway", value: info.gatewayIP)
                divider
                infoRow(icon: "globe", label: "Public IP", value: info.publicIP)
                divider
                infoRow(icon: "number", label: "IPv6", value: info.localIPv6.isEmpty ? "--" : info.localIPv6)
                divider
                infoRow(icon: "antenna.radiowaves.left.and.right.circle", label: "Type", value: info.connectionType)
            }
        }
    }

    // MARK: - Standard Row

    private func infoRow(icon: String, label: String, value: String, dimmed: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .frame(width: 22, alignment: .center)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(dimmed ? .textTertiary : .textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Signal Row

    private var signalRow: some View {
        let hasSignal = info.signalStrength > 0
        let bars = signalBars
        let pct = hasSignal ? Int(info.signalStrength * 100) : 0

        return HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .frame(width: 24, alignment: .center)
            Text("WiFi Signal")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
            Spacer()

            if hasSignal {
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < bars ? Color.accentGreen : Color.textTertiary)
                            .frame(width: 5, height: barHeight(for: index))
                    }
                }
                .frame(height: 18, alignment: .bottom)

                Text("\(pct)%")
                    .font(.system(size: 15))
                    .foregroundColor(.textPrimary)

                Text(signalLabel)
                    .font(.system(size: 13))
                    .foregroundColor(signalLabelColor)
            } else {
                Text("--")
                    .font(.system(size: 15))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.vertical, 3)
        .opacity(hasSignal ? 1.0 : 0.5)
    }

    // MARK: - Divider

    private var divider: some View {
        Divider()
            .background(Color.dividerColor)
    }

    // MARK: - Signal Helpers

    private var signalBars: Int {
        let pct = info.signalStrength
        if pct >= 0.75 { return 4 }
        if pct >= 0.50 { return 3 }
        if pct >= 0.25 { return 2 }
        if pct > 0     { return 1 }
        return 0
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [5, 9, 13, 18]
        return heights[index]
    }

    private var signalLabel: String {
        let pct = info.signalStrength
        if pct >= 0.75 { return "Excellent" }
        if pct >= 0.50 { return "Good" }
        if pct >= 0.25 { return "Fair" }
        return "Weak"
    }

    private var signalLabelColor: Color {
        let pct = info.signalStrength
        if pct >= 0.75 { return .scoreExcellent }
        if pct >= 0.50 { return .accentGreen }
        if pct >= 0.25 { return .scoreFair }
        return .scorePoor
    }
}

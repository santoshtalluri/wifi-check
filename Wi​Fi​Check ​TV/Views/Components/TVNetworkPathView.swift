//
//  TVNetworkPathView.swift
//  WiFi Check TV
//
//  TV-sized: 40x40 node icons, 12pt labels, 14pt latency values.
//  Full text: "Apple TV", "Router", "Internet" — no truncation.
//

import SwiftUI

struct TVNetworkPathView: View {
    let routerLatency: Double?
    let internetLatency: Double?
    let gatewayIP: String
    let publicIP: String

    var body: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text("Network Path")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }

                Spacer(minLength: 0)

                // Network topology
                HStack(spacing: 0) {
                    Spacer()

                    // Node 1: Apple TV
                    nodeView(
                        icon: "tv.fill",
                        label: "Apple TV",
                        value: "You"
                    )

                    // Connecting line + latency
                    connectionLine(
                        latency: routerLatency,
                        gradient: Gradient(colors: [.scoreGood, .scoreGood.opacity(0.4)])
                    )

                    // Node 2: Router
                    nodeView(
                        icon: "wifi.router.fill",
                        label: "Router",
                        value: gatewayIP
                    )

                    // Connecting line + latency
                    connectionLine(
                        latency: internetLatency,
                        gradient: Gradient(colors: [.scoreExcellent, .scoreExcellent.opacity(0.4)])
                    )

                    // Node 3: Internet
                    nodeView(
                        icon: "globe",
                        label: "Internet",
                        value: publicIP
                    )

                    Spacer()
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func nodeView(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.textPrimary)
            }

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 90)
    }

    @ViewBuilder
    private func connectionLine(latency: Double?, gradient: Gradient) -> some View {
        VStack(spacing: 5) {
            Rectangle()
                .fill(LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)

            Text(latencyText(latency))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
        }
        .frame(minWidth: 70, maxWidth: .infinity)
    }

    private func latencyText(_ latency: Double?) -> String {
        guard let latency = latency else { return "--" }
        return String(format: "%.0f ms", latency)
    }
}

//
//  TVMetricsGrid.swift
//  WiFi Check TV
//
//  2x3 grid with 36x36 icons, 22pt values, 13pt labels, 16pt tile padding.
//

import SwiftUI

struct TVMetricsGrid: View {
    let metrics: NetworkMetrics
    let score: QualityScore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Text("Quality Metrics")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("6 of 6")
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    metricTile(
                        icon: "arrow.down.circle.fill",
                        iconBg: Color(hex: "FF9F0A"),
                        label: "Download Speed",
                        value: formatDecimal(metrics.throughput ?? 0),
                        unit: "Mbps",
                        subScore: score.throughputSubScore
                    )
                    metricTile(
                        icon: "globe",
                        iconBg: Color(hex: "0A84FF"),
                        label: "Internet Latency",
                        value: "\(Int(metrics.internetLatency ?? 0))",
                        unit: "ms",
                        subScore: score.internetSubScore
                    )
                    metricTile(
                        icon: "house.fill",
                        iconBg: Color(hex: "0A84FF"),
                        label: "Router Latency",
                        value: "\(Int(metrics.routerLatency ?? 0))",
                        unit: "ms",
                        subScore: score.routerSubScore
                    )
                    metricTile(
                        icon: "shippingbox.fill",
                        iconBg: Color(hex: "30D158"),
                        label: "Packet Loss",
                        value: "\(Int(metrics.packetLoss ?? 0))",
                        unit: "%",
                        subScore: score.packetLossSubScore
                    )
                    metricTile(
                        icon: "bolt.fill",
                        iconBg: Color(hex: "30D158"),
                        label: "DNS Lookup",
                        value: "\(Int(metrics.dnsSpeed ?? 0))",
                        unit: "ms",
                        subScore: score.dnsSubScore
                    )
                    metricTile(
                        icon: "chart.line.uptrend.xyaxis",
                        iconBg: Color(hex: "0A84FF"),
                        label: "Jitter",
                        value: formatDecimal(metrics.jitter ?? 0),
                        unit: "ms",
                        subScore: score.jitterSubScore
                    )
                }
            }
        }
    }

    // MARK: - Metric Tile

    private func metricTile(icon: String, iconBg: Color, label: String, value: String, unit: String, subScore: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(iconBg.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text(unit)
                    .font(.system(size: 13))
                    .foregroundColor(.textTertiary)
            }

            // Sub-score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gaugeTrack)
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: subScore))
                        .frame(width: max(0, geo.size.width * CGFloat(max(subScore, 0)) / 100), height: 5)
                        .animation(.easeInOut(duration: 0.4), value: subScore)
                }
            }
            .frame(height: 5)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func barColor(for score: Int) -> Color {
        if score >= 80 { return Color(hex: "30D158") }
        if score >= 60 { return Color(hex: "0A84FF") }
        if score >= 40 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }

    private func formatDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

//
//  TVScoreBreakdown.swift
//  WiFi Check TV
//
//  Tile-grid layout matching Quality Metrics style.
//

import SwiftUI

struct TVScoreBreakdown: View {
    let score: QualityScore
    let bottleneck: String?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private struct SubScoreItem: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
        let icon: String
        let iconBg: Color
    }

    private var subScores: [SubScoreItem] {
        [
            SubScoreItem(label: "Throughput", value: score.throughputSubScore,
                         icon: "arrow.down.circle.fill", iconBg: Color(hex: "FF9F0A")),
            SubScoreItem(label: "Packet Loss", value: score.packetLossSubScore,
                         icon: "shippingbox.fill", iconBg: Color(hex: "30D158")),
            SubScoreItem(label: "Internet", value: score.internetSubScore,
                         icon: "globe", iconBg: Color(hex: "0A84FF")),
            SubScoreItem(label: "Jitter", value: score.jitterSubScore,
                         icon: "chart.line.uptrend.xyaxis", iconBg: Color(hex: "0A84FF")),
            SubScoreItem(label: "Router", value: score.routerSubScore,
                         icon: "house.fill", iconBg: Color(hex: "0A84FF")),
            SubScoreItem(label: "DNS", value: score.dnsSubScore,
                         icon: "bolt.fill", iconBg: Color(hex: "30D158"))
        ]
    }

    var body: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text("Score Breakdown")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    if let bottleneck = bottleneck {
                        Text("Bottleneck: \(bottleneck)")
                            .font(.system(size: 12))
                            .foregroundColor(.scorePoor)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.scorePoor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // 2-column tile grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(subScores) { item in
                        scoreTile(item)
                    }
                }

                Divider().background(Color.dividerColor).padding(.top, 4)

                // Score legend
                HStack(spacing: 0) {
                    legendBadge(color: Color(hex: "30D158"), label: "80+ Excellent")
                    legendBadge(color: Color(hex: "0A84FF"), label: "60–79 Good")
                    legendBadge(color: Color(hex: "FF9F0A"), label: "40–59 Fair")
                    legendBadge(color: Color(hex: "FF453A"), label: "<40 Poor")
                }

                // Weights footnote
                Text("Throughput 30 · Latency 25 · Packet Loss 20 · Jitter 15 · DNS 10")
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
        }
    }

    private func legendBadge(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Score Tile (matches TVMetricsGrid style)

    @ViewBuilder
    private func scoreTile(_ item: SubScoreItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(item.iconBg.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Text(item.label)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(item.value)")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("/100")
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
                        .fill(barColor(for: item.value))
                        .frame(width: max(0, geo.size.width * CGFloat(max(item.value, 0)) / 100), height: 5)
                        .animation(.easeInOut(duration: 0.4), value: item.value)
                }
            }
            .frame(height: 5)
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func barColor(for value: Int) -> Color {
        if value >= 80 { return Color(hex: "30D158") }
        if value >= 60 { return Color(hex: "0A84FF") }
        if value >= 40 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }
}

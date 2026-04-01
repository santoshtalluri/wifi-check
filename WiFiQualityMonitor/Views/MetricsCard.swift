//
//  MetricsCard.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Displays the 4 metrics: Router Latency, Packet Loss, Internet Latency, DNS Speed
struct MetricsCard: View {
    let metrics: NetworkMetrics
    let score: QualityScore
    let isDimmed: Bool  // true when VPN active

    @State private var selectedMetric: MetricType?

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    metricRow(metric)
                    if metric != MetricType.allCases.last {
                        Divider()
                            .background(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .sheet(item: $selectedMetric) { metric in
            TooltipSheet(metric: metric)
        }
    }

    private func metricRow(_ type: MetricType) -> some View {
        Button(action: { if !isDimmed { selectedMetric = type } }) {
            HStack {
                // Icon
                Image(systemName: type.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(isDimmed ? .textTertiary : type.iconColor)
                    .frame(width: 32)

                // Name
                Text(type.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDimmed ? .textTertiary : .textPrimary)

                Spacer()

                // Value
                Text(isDimmed ? "--" : formattedValue(for: type))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(isDimmed ? .textTertiary : .textSecondary)

                // Sub-score bar
                if !isDimmed {
                    subScoreBar(for: type)
                        .frame(width: 40, height: 4)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.4 : 1.0)
    }

    private func formattedValue(for type: MetricType) -> String {
        switch type {
        case .routerLatency:
            guard let v = metrics.routerLatency else { return "--" }
            return String(format: "%.0f ms", v)
        case .packetLoss:
            guard let v = metrics.packetLoss else { return "--" }
            return String(format: "%.1f%%", v)
        case .internetLatency:
            guard let v = metrics.internetLatency else { return "--" }
            return String(format: "%.0f ms", v)
        case .dnsSpeed:
            guard let v = metrics.dnsSpeed else { return "--" }
            return String(format: "%.0f ms", v)
        }
    }

    private func subScoreValue(for type: MetricType) -> Int {
        switch type {
        case .routerLatency: return score.routerSubScore
        case .packetLoss: return score.packetLossSubScore
        case .internetLatency: return score.internetSubScore
        case .dnsSpeed: return score.dnsSubScore
        }
    }

    private func subScoreBar(for type: MetricType) -> some View {
        let value = subScoreValue(for: type)
        let color = ScoreCalculator.qualityLevel(for: value).color
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.07))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(value) / 100.0)
            }
        }
    }
}

// MARK: - Metric Type

enum MetricType: String, CaseIterable, Identifiable {
    case routerLatency
    case packetLoss
    case internetLatency
    case dnsSpeed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .routerLatency: return "Router Latency"
        case .packetLoss: return "Packet Loss"
        case .internetLatency: return "Internet Latency"
        case .dnsSpeed: return "DNS Speed"
        }
    }

    var iconName: String {
        switch self {
        case .routerLatency: return "wifi.router"
        case .packetLoss: return "exclamationmark.triangle"
        case .internetLatency: return "globe"
        case .dnsSpeed: return "magnifyingglass"
        }
    }

    var iconColor: Color {
        switch self {
        case .routerLatency: return .scoreGood
        case .packetLoss: return .scoreFair
        case .internetLatency: return .scoreExcellent
        case .dnsSpeed: return .accentPurple
        }
    }

    var explanation: String {
        switch self {
        case .routerLatency:
            return "How fast your device talks to your WiFi router. Lower is better. High latency means your router is far away or overloaded."
        case .packetLoss:
            return "Percentage of data packets that got lost between your device and router. Even 1-2% can cause video stuttering and call drops."
        case .internetLatency:
            return "How fast your router talks to the internet. This affects everything you do online. High latency means slow page loads and buffering."
        case .dnsSpeed:
            return "How fast website names are translated to addresses. Slow DNS makes every website feel slow to start loading."
        }
    }
}

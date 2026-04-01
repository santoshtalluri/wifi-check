//
//  MetricsCard.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Displays the 6 metrics: Throughput, Packet Loss, Jitter, Internet Latency, Router Latency, DNS Speed
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
        case .throughput:
            guard let v = metrics.throughput else { return "--" }
            return String(format: "%.1f Mbps", v)
        case .packetLoss:
            guard let v = metrics.packetLoss else { return "--" }
            return String(format: "%.1f%%", v)
        case .jitter:
            guard let v = metrics.jitter else { return "--" }
            return String(format: "%.0f ms", v)
        case .internetLatency:
            guard let v = metrics.internetLatency else { return "--" }
            return String(format: "%.0f ms", v)
        case .routerLatency:
            guard let v = metrics.routerLatency else { return "--" }
            return String(format: "%.0f ms", v)
        case .dnsSpeed:
            guard let v = metrics.dnsSpeed else { return "--" }
            return String(format: "%.0f ms", v)
        }
    }

    private func subScoreValue(for type: MetricType) -> Int {
        switch type {
        case .throughput: return score.throughputSubScore
        case .packetLoss: return score.packetLossSubScore
        case .jitter: return score.jitterSubScore
        case .internetLatency: return score.internetSubScore
        case .routerLatency: return score.routerSubScore
        case .dnsSpeed: return score.dnsSubScore
        }
    }

    @ViewBuilder
    private func subScoreBar(for type: MetricType) -> some View {
        let value = subScoreValue(for: type)
        if value < 0 {
            // No data — show empty track
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.07))
        } else {
            let color = ScoreCalculator.qualityLevel(for: value).color
            GeometryReader { geo in
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
}

// MARK: - Metric Type

enum MetricType: String, CaseIterable, Identifiable {
    case throughput
    case packetLoss
    case jitter
    case internetLatency
    case routerLatency
    case dnsSpeed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .throughput: return "Throughput"
        case .packetLoss: return "Packet Loss"
        case .jitter: return "Jitter"
        case .internetLatency: return "Internet Latency"
        case .routerLatency: return "Router Latency"
        case .dnsSpeed: return "DNS Speed"
        }
    }

    var iconName: String {
        switch self {
        case .throughput: return "arrow.down.circle"
        case .packetLoss: return "exclamationmark.triangle"
        case .jitter: return "waveform.path.ecg"
        case .internetLatency: return "globe"
        case .routerLatency: return "wifi.router"
        case .dnsSpeed: return "magnifyingglass"
        }
    }

    var iconColor: Color {
        switch self {
        case .throughput: return .scoreExcellent
        case .packetLoss: return .scoreFair
        case .jitter: return .accentPurple
        case .internetLatency: return .scoreGood
        case .routerLatency: return .scoreGood
        case .dnsSpeed: return .textSecondary
        }
    }

    var explanation: String {
        switch self {
        case .throughput:
            return "Your actual download speed in Megabits per second. This is the single most important indicator of how fast your WiFi connection really is."
        case .packetLoss:
            return "Percentage of data packets that got lost between your device and router. Even 1-2% can cause video stuttering and call drops."
        case .jitter:
            return "How much your latency varies from one moment to the next. High jitter causes audio glitches in calls and lag spikes in games."
        case .internetLatency:
            return "How fast your router talks to the internet. This affects everything you do online. High latency means slow page loads and buffering."
        case .routerLatency:
            return "How fast your device talks to your WiFi router. Lower is better. High latency means your router is far away or overloaded."
        case .dnsSpeed:
            return "How fast website names are translated to addresses. Slow DNS makes every website feel slow to start loading."
        }
    }
}

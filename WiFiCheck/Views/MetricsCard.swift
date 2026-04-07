//
//  MetricsCard.swift
//  WiFi Check v1
//
//  Displays 6 metrics with collapsible advanced section (SpeedTestCard-style header)

import SwiftUI

/// Displays the 6 metrics with sub-score bars and tap-to-explain
struct MetricsCard: View {
    let metrics: NetworkMetrics
    let score: QualityScore
    let isDimmed: Bool  // true when VPN active

    @AppStorage("metricsExpanded") private var showAdvanced = false
    @State private var selectedMetric: MetricType?
    @State private var showSpeedMethodology = false
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    // Essential metrics (always visible)
    private let essentialMetrics: [MetricType] = [.throughput, .uploadThroughput, .internetLatency, .routerLatency]
    // Advanced metrics (collapsible)
    private let advancedMetrics: [MetricType] = [.packetLoss, .jitter, .dnsSpeed]

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                // SpeedTestCard-style header
                sectionHeader

                Divider().background(Color.dividerColor)

                // Essential metrics (always visible)
                ForEach(essentialMetrics, id: \.self) { metric in
                    metricRow(metric)
                    if metric != essentialMetrics.last {
                        Divider().background(Color.dividerColor)
                    }
                }

                // Advanced metrics (collapsible)
                if showAdvanced {
                    Divider().background(Color.dividerColor)
                    ForEach(advancedMetrics, id: \.self) { metric in
                        metricRow(metric)
                        if metric != advancedMetrics.last {
                            Divider().background(Color.dividerColor)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showAdvanced)
        .sheet(item: $selectedMetric) { metric in
            TooltipSheet(metric: metric)
        }
        .sheet(isPresented: $showSpeedMethodology) {
            SpeedTestMethodologySheet()
        }
    }

    // MARK: - Section Header (SpeedTestCard-style)

    private var sectionHeader: some View {
        Button(action: { showAdvanced.toggle() }) {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 17 * scale))
                    .foregroundColor(.scoreExcellent)

                Text("Metrics")
                    .font(.system(size: 17 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(showAdvanced ? "7 of 7" : "4 of 7")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textSecondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundColor(.textTertiary)
                    .rotationEffect(.degrees(showAdvanced ? 180 : 0))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .background(Color.textSecondary.opacity(0.08))
        .padding(.horizontal, -16)
        .padding(.top, -16)
        .buttonStyle(.plain)
        .accessibilityIdentifier("metricsToggleHeader")
    }

    // MARK: - Metric Row

    private func metricRow(_ type: MetricType) -> some View {
        let isSpeedMetric = (type == .throughput || type == .uploadThroughput)

        return Button(action: { if !isDimmed { selectedMetric = type } }) {
            HStack {
                Image(systemName: type.iconName)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(isDimmed ? .textTertiary : type.iconColor)
                    .frame(width: 28)

                Text(type.displayName)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundColor(isDimmed ? .textTertiary : .textPrimary)

                // Info icon — opens methodology sheet for speed rows
                if isSpeedMetric && !isDimmed {
                    Button(action: { showSpeedMethodology = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12 * scale))
                            .foregroundColor(.textTertiary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("speedMethodologyInfo_\(type.rawValue)")
                }

                Spacer()

                Text(isDimmed ? "--" : formattedValue(for: type))
                    .font(.system(size: 13 * scale, weight: .light))
                    .foregroundColor(isDimmed ? .textTertiary : .textPrimary)

                if !isDimmed {
                    subScoreBar(for: type)
                        .frame(width: 36, height: 4)
                }
            }
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.4 : 1.0)
        .accessibilityIdentifier("metricRow_\(type.rawValue)")
    }

    private func formattedValue(for type: MetricType) -> String {
        switch type {
        case .throughput:
            guard let v = metrics.throughput else { return "--" }
            if v >= 100 { return String(format: "%.0f Mbps", v) }
            return String(format: "%.1f Mbps", v)
        case .uploadThroughput:
            guard let v = metrics.uploadThroughput else { return "--" }
            if v >= 100 { return String(format: "%.0f Mbps", v) }
            return String(format: "%.1f Mbps", v)
        case .packetLoss:
            guard let v = metrics.packetLoss else { return "--" }
            return String(format: "%.1f%%", v)
        case .jitter:
            guard let v = metrics.jitter else { return "--" }
            return String(format: "%.1f ms", v)
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
        case .throughput: return score.hasThroughputScore ? score.throughputSubScore : 0
        case .uploadThroughput:
            guard let v = metrics.uploadThroughput else { return 0 }
            return ScoreCalculator.throughputSubScore(mbps: v)
        case .packetLoss: return score.packetLossSubScore
        case .jitter: return score.hasJitterScore ? score.jitterSubScore : 0
        case .internetLatency: return score.internetSubScore
        case .routerLatency: return score.routerSubScore
        case .dnsSpeed: return score.dnsSubScore
        }
    }

    private func subScoreBar(for type: MetricType) -> some View {
        let value = subScoreValue(for: type)
        let color = ScoreCalculator.qualityLevel(for: value).color
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gaugeTrack)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(value) / 100.0)
            }
        }
    }
}

// MARK: - Metric Type (6 metrics, ordered by weight)

enum MetricType: String, CaseIterable, Identifiable {
    case throughput
    case uploadThroughput
    case packetLoss
    case jitter
    case internetLatency
    case routerLatency
    case dnsSpeed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .throughput: return "Download Speed"
        case .uploadThroughput: return "Upload Speed"
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
        case .uploadThroughput: return "arrow.up.circle"
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
        case .uploadThroughput: return .scoreGood
        case .packetLoss: return .scoreFair
        case .jitter: return .scorePoor
        case .internetLatency: return .scoreGood
        case .routerLatency: return .scoreGood
        case .dnsSpeed: return .accentPurple
        }
    }

    var explanation: String {
        switch self {
        case .throughput:
            return "Your actual download speed in Megabits per second. This is what determines if you can stream HD video, join video calls, or download files quickly. 25+ Mbps is great for most activities."
        case .uploadThroughput:
            return "Your actual upload speed in Megabits per second. Critical for video calls, cloud backups, and sharing files. 10+ Mbps handles most tasks comfortably; 50+ Mbps is excellent."
        case .packetLoss:
            return "Percentage of data packets that got lost between your device and router. Even 1-2% can cause video stuttering and call drops."
        case .jitter:
            return "How consistent your connection timing is. High jitter means some packets arrive fast and others slow — this causes choppy video calls and laggy gaming."
        case .internetLatency:
            return "How fast your router talks to the internet. This affects everything you do online. High latency means slow page loads and buffering."
        case .routerLatency:
            return "How fast your device talks to your WiFi router. Lower is better. High latency means your router is far away or overloaded."
        case .dnsSpeed:
            return "How fast website names are translated to addresses. Slow DNS makes every website feel slow to start loading."
        }
    }
}

// MARK: - Speed Test Methodology Sheet

/// Full-page sheet explaining how download/upload speed is measured
/// and why results may differ from an ISP's advertised plan speed.
struct SpeedTestMethodologySheet: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Drag handle
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 5)
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.bottom, 20)

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 36 * scale))
                        .foregroundColor(.scoreExcellent)

                    Text("How Speed Is Measured")
                        .font(.system(size: 20 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Text("What the test does and why your result may differ from your ISP's advertised plan speed.")
                        .font(.system(size: 14 * scale))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)

                // The Test
                methodologySectionCard {
                    methodologySectionTitle(icon: "doc.text.magnifyingglass", title: "What the Test Does")

                    methodologyMethodRow(
                        icon: "arrow.down.circle.fill",
                        color: .scoreExcellent,
                        title: "Download",
                        detail: "Downloads a 5 MB file from a globally distributed CDN server to measure your real download throughput."
                    )

                    Divider().background(Color.dividerColor).padding(.vertical, 4)

                    methodologyMethodRow(
                        icon: "arrow.up.circle.fill",
                        color: .scoreGood,
                        title: "Upload",
                        detail: "Sends a 3 MB payload to a CDN upload endpoint to measure your real upload throughput."
                    )

                    Divider().background(Color.dividerColor).padding(.vertical, 4)

                    methodologyMethodRow(
                        icon: "clock.fill",
                        color: .accentPurple,
                        title: "Frequency",
                        detail: "Runs once every 5 minutes to conserve data.\nResets immediately when you pull to refresh."
                    )
                }

                // Why Results May Differ
                methodologySectionCard {
                    methodologySectionTitle(icon: "exclamationmark.triangle.fill", title: "Why Your Result May Appear Lower")

                    VStack(alignment: .leading, spacing: 14) {
                        methodologyReasonRow(
                            icon: "arrow.left.arrow.right",
                            title: "Single connection vs. multi-stream",
                            body: "Your ISP's plan speed is typically measured using 8–16 parallel streams (like Speedtest.net). This app uses one HTTP connection — a real-world scenario. Many connections reach ~30–50% of plan speed in single-stream tests."
                        )
                        Divider().background(Color.dividerColor)
                        methodologyReasonRow(
                            icon: "doc.zipper",
                            title: "Probe size on very fast connections",
                            body: "A 5 MB file transfers in under 100 ms on a 400+ Mbps link. At that scale, HTTPS handshake time becomes a measurable fraction of the result. The test is most accurate in the 10–300 Mbps range."
                        )
                        Divider().background(Color.dividerColor)
                        methodologyReasonRow(
                            icon: "cpu",
                            title: "Device processing overhead",
                            body: "Decrypting TLS traffic at gigabit speeds is CPU-intensive. Older iPhones can become CPU-bound before the network is saturated, capping the measured result."
                        )
                        Divider().background(Color.dividerColor)
                        methodologyReasonRow(
                            icon: "waveform.path",
                            title: "Background network activity",
                            body: "Other apps, system syncs, or automatic updates using bandwidth during the test will lower the measured speed."
                        )
                        Divider().background(Color.dividerColor)
                        methodologyReasonRow(
                            icon: "wifi.exclamationmark",
                            title: "Wi-Fi vs. wired speed",
                            body: "Wi-Fi adds contention, interference, and distance attenuation. Even on a 1 Gbps plan, Wi-Fi typically delivers 200–600 Mbps in good conditions."
                        )
                    }
                }

                // Tip
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14 * scale))
                        .foregroundColor(.yellow)
                        .padding(.top, 1)
                    Text("For the most accurate comparison with your ISP speed, use a dedicated speed test app with parallel streams, or connect directly via Ethernet.")
                        .font(.system(size: 13 * scale))
                        .foregroundColor(.textSecondary)
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

                // Dismiss
                Button("Got it") { dismiss() }
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .accessibilityIdentifier("speedMethodologyDismissButton")
            }
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Private helpers

    private func methodologySectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func methodologySectionTitle(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textSecondary)
            Text(title)
                .font(.system(size: 13 * scale, weight: .bold))
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.bottom, 4)
    }

    private func methodologyMethodRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18 * scale))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(detail)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(.textSecondary)
            }
        }
    }

    private func methodologyReasonRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15 * scale))
                .foregroundColor(.textTertiary)
                .frame(width: 22, alignment: .center)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(body)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

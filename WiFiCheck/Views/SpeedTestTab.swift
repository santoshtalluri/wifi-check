//
//  SpeedTestTab.swift
//  WiFi Check v1
//

import SwiftUI

// MARK: - Speed Unit

enum SpeedUnit: String, CaseIterable {
    case mbps = "Mbps"
    case MBps = "MB/s"
    case KBps = "KB/s"

    func convert(_ mbps: Double) -> Double {
        switch self {
        case .mbps: return mbps
        case .MBps: return mbps / 8.0
        case .KBps: return mbps * 125.0
        }
    }

    func format(_ mbps: Double?) -> String {
        guard let v = mbps else { return "--" }
        let converted = convert(v)
        switch self {
        case .mbps:
            return converted >= 100 ? String(format: "%.0f", converted) : String(format: "%.1f", converted)
        case .MBps:
            return converted >= 10  ? String(format: "%.1f", converted) : String(format: "%.2f", converted)
        case .KBps:
            return converted >= 1000 ? String(format: "%.0f", converted) : String(format: "%.1f", converted)
        }
    }
}

// MARK: - NetworkPathCard

/// Phone → Router → Internet diagram with glossy nodes, latency-colored bridges,
/// and an integrated diagnosis section.
struct NetworkPathCard: View {
    let metrics: NetworkMetrics
    let wifiInfo: WiFiInfo
    let accentColor: Color

    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    @State private var glowPhase: Bool = false
    @State private var showDiagnosisInfo: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let circleSize: CGFloat = 54

    // MARK: - Diagnosis types

    private struct DiagnosisStat: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let isGood: Bool
    }

    private struct DiagnosisInfo {
        let isHealthy: Bool        // drives fancy vs. problem layout
        let icon: String
        let iconColor: Color
        let headline: String
        let subtitle: String       // shown below headline in healthy banner
        let detail: String
        let tip: String?
        let stats: [DiagnosisStat]
    }

    private var diagnosisInfo: DiagnosisInfo { diagnose(metrics) }

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                // Header — shows WiFi network name
                HStack {
                    Image(systemName: "wifi")
                        .font(.system(size: 17 * scale))
                        .foregroundColor(.textSecondary)
                    Text(wifiInfo.ssid)
                        .font(.system(size: 17 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.textSecondary.opacity(0.15))
                .padding(.horizontal, -16)
                .padding(.top, -16)

                Divider().background(Color.dividerColor)

                // Path diagram
                HStack(alignment: .top, spacing: 0) {
                    nodeView(
                        icon: "iphone",
                        label: "iPhone",
                        sublabel: wifiInfo.localIP.isEmpty ? "You" : wifiInfo.localIP,
                        color: accentColor
                    )
                    connectionBridge(latency: metrics.routerLatency, color: routerColor)
                        .padding(.top, circleSize / 2 - 1)
                    nodeView(
                        icon: "wifi.router.fill",
                        label: "Router",
                        sublabel: wifiInfo.gatewayIP.isEmpty ? "--" : wifiInfo.gatewayIP,
                        color: routerColor
                    )
                    connectionBridge(latency: metrics.internetLatency, color: internetColor)
                        .padding(.top, circleSize / 2 - 1)
                    nodeView(
                        icon: "globe",
                        label: "Internet",
                        sublabel: wifiInfo.publicIP.isEmpty ? "--" : wifiInfo.publicIP,
                        color: internetColor
                    )
                }
                .padding(.top, 14)

                Divider().background(Color.dividerColor).padding(.top, 14)

                diagnosisSection
                    .padding(.top, 12)
            }
        }
        .onAppear {
            guard !reduceMotion else { glowPhase = true; return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
        .sheet(isPresented: $showDiagnosisInfo) {
            DiagnosisInfoSheet()
        }
    }

    // MARK: - Diagnosis section router

    @ViewBuilder
    private var diagnosisSection: some View {
        if diagnosisInfo.isHealthy {
            healthyBanner
        } else {
            problemDiagnosis
        }
    }

    // MARK: - Healthy banner (fancy green card)

    private var healthyBanner: some View {
        HStack(spacing: 14) {
            // Pulsing glow circle with checkmark
            ZStack {
                Circle()
                    .fill(Color.scoreExcellent.opacity(
                        reduceMotion ? 0.15 : (glowPhase ? 0.24 : 0.08)
                    ))
                    .frame(width: 50, height: 50)
                Circle()
                    .fill(Color.scoreExcellent.opacity(0.10))
                    .frame(width: 50, height: 50)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.scoreExcellent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(diagnosisInfo.headline)
                    .font(.system(size: 16 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)
                if !diagnosisInfo.subtitle.isEmpty {
                    Text(diagnosisInfo.subtitle)
                        .font(.system(size: 12 * scale))
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Button(action: { showDiagnosisInfo = true }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14 * scale))
                    .foregroundColor(.textTertiary)
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.scoreExcellent.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.scoreExcellent.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Problem diagnosis (detailed layout)

    @ViewBuilder
    private var problemDiagnosis: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon + headline + info button
            HStack(spacing: 10) {
                Image(systemName: diagnosisInfo.icon)
                    .font(.system(size: 17 * scale))
                    .foregroundColor(diagnosisInfo.iconColor)
                Text(diagnosisInfo.headline)
                    .font(.system(size: 15 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)
                Button(action: { showDiagnosisInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13 * scale))
                        .foregroundColor(.textTertiary)
                }
                .buttonStyle(.borderless)
                Spacer()
            }

            // Stat boxes
            if !diagnosisInfo.stats.isEmpty {
                HStack(spacing: 6) {
                    ForEach(diagnosisInfo.stats) { stat in
                        VStack(spacing: 2) {
                            Text(stat.value)
                                .font(.system(size: 15 * scale, weight: .medium))
                                .foregroundColor(stat.isGood ? .textPrimary : diagnosisInfo.iconColor)
                            Text(stat.label)
                                .font(.system(size: 9 * scale, weight: .semibold))
                                .foregroundColor(.textSecondary)
                                .tracking(0.5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.gaugeTrack)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if !diagnosisInfo.detail.isEmpty {
                Text(diagnosisInfo.detail)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let tip = diagnosisInfo.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11 * scale))
                        .foregroundColor(Color(hex: "FFD60A"))
                        .padding(.top, 1)
                    Text(tip)
                        .font(.system(size: 12 * scale))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.textTertiary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Glossy node bubble

    private func nodeView(icon: String, label: String, sublabel: String, color: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: circleSize, height: circleSize)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.30), Color.clear],
                            startPoint: UnitPoint(x: 0.2, y: 0.05),
                            endPoint: UnitPoint(x: 0.8, y: 0.75)
                        )
                    )
                    .frame(width: circleSize, height: circleSize)
                Circle()
                    .strokeBorder(color.opacity(0.35), lineWidth: 1)
                    .frame(width: circleSize, height: circleSize)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            Text(sublabel)
                .font(.system(size: 11 * scale))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 80)
    }

    // MARK: - Connection bridge

    private func connectionBridge(latency: Double?, color: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Capsule().fill(color.opacity(0.15)).frame(height: 2)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(reduceMotion ? 0.70 : (glowPhase ? 0.95 : 0.45)),
                                color.opacity(0.20),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
            }
            Text(latency.map { String(format: "%.0f ms", $0) } ?? "--")
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundColor(Color.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(latency == nil ? 0.15 : 0.20))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Color helpers

    private var routerColor: Color   { latencyColor(metrics.routerLatency) }
    private var internetColor: Color { latencyColor(metrics.internetLatency) }

    private func latencyColor(_ ms: Double?) -> Color {
        guard let ms else { return .textTertiary }
        if ms < 10  { return .scoreExcellent }
        if ms < 30  { return .scoreGood      }
        if ms < 80  { return .scoreFair      }
        return .scorePoor
    }

    // MARK: - Diagnosis logic

    private func diagnose(_ m: NetworkMetrics) -> DiagnosisInfo {
        let router   = m.routerLatency
        let internet = m.internetLatency
        let loss     = m.packetLoss
        let dns      = m.dnsSpeed

        guard router != nil || internet != nil else {
            return DiagnosisInfo(
                isHealthy: false,
                icon: "chart.bar.fill", iconColor: .textTertiary,
                headline: "Waiting for Data",
                subtitle: "",
                detail: "Measurements are needed to analyze your connection. Results will appear after the next reading cycle.",
                tip: nil, stats: []
            )
        }

        if let loss, loss > 2.0 {
            return DiagnosisInfo(
                isHealthy: false,
                icon: "exclamationmark.triangle.fill", iconColor: .scorePoor,
                headline: "Packet Loss Detected",
                subtitle: "",
                detail: String(format: "%.1f%% of packets are being dropped. This causes stuttering in video calls, gaming, and real-time apps.", loss),
                tip: "Likely cause: faulty cable, Wi-Fi interference, or ISP equipment. Try a wired connection to isolate the issue.",
                stats: [DiagnosisStat(label: "LOSS", value: String(format: "%.1f%%", loss), isGood: false)]
            )
        }

        if let r = router, let i = internet, r <= 20 && i > 80 {
            return DiagnosisInfo(
                isHealthy: false,
                icon: "wifi.exclamationmark", iconColor: .scorePoor,
                headline: "ISP Issue Detected",
                subtitle: "",
                detail: "Your router is healthy (\(Int(r))ms) but internet latency is high (\(Int(i))ms). The bottleneck is between your modem and your ISP — not your home network.",
                tip: "Restart your modem. If latency stays high, contact your ISP — the problem is on their end.",
                stats: [
                    DiagnosisStat(label: "ROUTER",   value: "\(Int(r))ms", isGood: true),
                    DiagnosisStat(label: "INTERNET", value: "\(Int(i))ms", isGood: false),
                ]
            )
        }

        if let r = router, let i = internet, r > 50 && i > 100 {
            return DiagnosisInfo(
                isHealthy: false,
                icon: "wifi.router", iconColor: .scoreFair,
                headline: "Router Congestion",
                subtitle: "",
                detail: "Both router (\(Int(r))ms) and internet (\(Int(i))ms) latency are elevated. Your router may be overloaded by too many devices or heavy downloads.",
                tip: "Restart your router. Check if any device is streaming or downloading large files in the background.",
                stats: [
                    DiagnosisStat(label: "ROUTER",   value: "\(Int(r))ms", isGood: false),
                    DiagnosisStat(label: "INTERNET", value: "\(Int(i))ms", isGood: false),
                ]
            )
        }

        if let d = dns, d > 100 {
            return DiagnosisInfo(
                isHealthy: false,
                icon: "clock.badge.exclamationmark.fill", iconColor: .scoreFair,
                headline: "Slow DNS Lookups",
                subtitle: "",
                detail: String(format: "DNS resolution is taking %.0fms. Pages will feel sluggish even when your download speed is fine.", d),
                tip: "Set your router's DNS to Cloudflare (1.1.1.1) or Google (8.8.8.8) for faster browsing.",
                stats: [DiagnosisStat(label: "DNS", value: String(format: "%.0fms", d), isGood: false)]
            )
        }

        // All good — build a contextual subtitle line
        var sub: [String] = []
        if let r = router   { sub.append("Router \(Int(r))ms")   }
        if let i = internet { sub.append("Internet \(Int(i))ms") }
        if let l = loss, l < 0.5 { sub.append("No packet loss")  }
        let subtitle = sub.isEmpty ? "All metrics look good" : sub.joined(separator: " · ")

        return DiagnosisInfo(
            isHealthy: true,
            icon: "checkmark.circle.fill", iconColor: .scoreExcellent,
            headline: healthyHeadline(router: router, internet: internet, throughput: m.throughput),
            subtitle: subtitle,
            detail: "", tip: nil, stats: []
        )
    }

    // Context-aware creative headline for healthy state
    private func healthyHeadline(router: Double?, internet: Double?, throughput: Double?) -> String {
        if let r = router, let i = internet, r < 5  && i < 15 { return "Lightning Fast"         }
        if let r = router, let i = internet, r < 8  && i < 25 { return "Blazing Smooth"         }
        if let r = router, let i = internet, r < 15 && i < 50 { return "Running at Full Speed"  }
        if let r = router, let i = internet, r < 30 && i < 80 { return "Solid & Steady"         }
        if let dl = throughput, dl >= 100                      { return "Fast & Reliable"        }
        return "All Systems Clear"
    }
}

// MARK: - Diagnosis Info Sheet

private struct DiagnosisInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.scoreExcellent.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "network")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.scoreExcellent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Status")
                        .font(.system(size: 18 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("What each diagnosis means")
                        .font(.system(size: 13 * scale))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Divider().background(Color.dividerColor).padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Intro
                    Text("Your connection is diagnosed in real-time using latency, packet loss, and DNS measurements. The status updates every few seconds automatically.")
                        .font(.system(size: 13 * scale))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    // Status rows
                    VStack(spacing: 0) {
                        diagnosisRow(
                            icon: "checkmark.circle.fill", color: .scoreExcellent,
                            title: "Healthy (Lightning Fast / Solid & Steady / etc.)",
                            description: "Router and internet latency are both low with minimal or no packet loss. The exact headline reflects how good your metrics actually are."
                        )
                        rowDivider
                        diagnosisRow(
                            icon: "exclamationmark.triangle.fill", color: .scorePoor,
                            title: "Packet Loss Detected",
                            description: "More than 2% of data packets are being dropped. Causes stuttering in video calls, gaming lag, and unreliable real-time connections."
                        )
                        rowDivider
                        diagnosisRow(
                            icon: "wifi.exclamationmark", color: .scorePoor,
                            title: "ISP Issue Detected",
                            description: "Your router is healthy but internet latency is high. The bottleneck is between your modem and your ISP — not your local network."
                        )
                        rowDivider
                        diagnosisRow(
                            icon: "wifi.router", color: .scoreFair,
                            title: "Router Congestion",
                            description: "Both router and internet latency are elevated. Usually means the router is overloaded by too many active devices or heavy background downloads."
                        )
                        rowDivider
                        diagnosisRow(
                            icon: "clock.badge.exclamationmark.fill", color: .scoreFair,
                            title: "Slow DNS Lookups",
                            description: "DNS is taking over 100ms to resolve names. Web pages feel sluggish to start even when your download speed is fast."
                        )
                        rowDivider
                        diagnosisRow(
                            icon: "chart.bar.fill", color: .textTertiary,
                            title: "Waiting for Data",
                            description: "Not enough measurements yet. Appears briefly on first launch or after the app resumes from background."
                        )
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }

            Button(action: { dismiss() }) {
                Text("Got it")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundColor(Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.scoreExcellent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var rowDivider: some View {
        Divider().background(Color.dividerColor).padding(.leading, 46)
    }

    private func diagnosisRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20 * scale))
                .foregroundColor(color)
                .frame(width: 24, alignment: .center)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(description)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Speed Test Card

struct SpeedTestCard: View {
    let metrics: NetworkMetrics
    let isMeasuring: Bool
    let accentColor: Color
    let onRunTest: () -> Void

    @AppStorage("wqm-speed-unit") private var speedUnitRaw: String = SpeedUnit.mbps.rawValue
    @AppStorage("wqm-font-size")  private var fontSizeRaw:  String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    @State private var showMethodology: Bool = false
    @State private var shimmerOn:       Bool = false

    private var speedUnit: SpeedUnit { SpeedUnit(rawValue: speedUnitRaw) ?? .mbps }
    private var hasData: Bool { metrics.throughput != nil || metrics.uploadThroughput != nil }

    var body: some View {
        GlassCard {
            VStack(spacing: 0) {
                header
                Divider().background(Color.dividerColor)

                VStack(spacing: 14) {
                    if isMeasuring {
                        measuringView
                    } else if hasData {
                        speedResultsRow
                    } else {
                        runTestCTA
                    }

                    Divider().background(Color.dividerColor)

                    selectorRow(
                        label: "Speed Unit",
                        options: SpeedUnit.allCases.map {
                            (label: $0.rawValue, key: $0.rawValue, isSelected: $0.rawValue == speedUnitRaw)
                        },
                        onSelect: { speedUnitRaw = $0 }
                    )

                    if hasData {
                        methodologyNote
                    }
                }
                .padding(.top, 14)
            }
        }
        .sheet(isPresented: $showMethodology) { SpeedTestMethodologySheet() }
        .onAppear {
            if isMeasuring { startShimmer() }
        }
        .onChange(of: isMeasuring) { _, measuring in
            if measuring { startShimmer() } else { shimmerOn = false }
        }
    }

    private func startShimmer() {
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
            shimmerOn = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .font(.system(size: 17 * scale))
                .foregroundColor(.scoreExcellent)
            Text("Speed Test")
                .font(.system(size: 17 * scale, weight: .bold))
                .foregroundColor(.textPrimary)
            Spacer()

            if isMeasuring {
                HStack(spacing: 5) {
                    ProgressView().scaleEffect(0.7).tint(.textSecondary)
                    Text("Testing…")
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.textSecondary.opacity(0.10))
                .clipShape(Capsule())
            } else if hasData {
                Button(action: onRunTest) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10 * scale, weight: .semibold))
                        Text("Re-run")
                            .font(.system(size: 12 * scale, weight: .semibold))
                    }
                    .foregroundColor(.scoreExcellent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.scoreExcellent.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.textSecondary.opacity(0.15))
        .padding(.horizontal, -16)
        .padding(.top, -16)
    }

    // MARK: - No-data CTA

    private var runTestCTA: some View {
        Button(action: onRunTest) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.scoreExcellent.opacity(0.12))
                        .frame(width: 76, height: 76)
                    Circle()
                        .strokeBorder(Color.scoreExcellent.opacity(0.30), lineWidth: 1.5)
                        .frame(width: 76, height: 76)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.scoreExcellent)
                }
                VStack(spacing: 5) {
                    Text("Test Your Speed")
                        .font(.system(size: 16 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Tap to measure download & upload\nusing your current connection (~100 MB)")
                        .font(.system(size: 12 * scale))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color.scoreExcellent.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        Color.scoreExcellent.opacity(0.20),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Measuring view

    private var measuringView: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                shimmerBox(icon: "arrow.down.circle.fill", color: .scoreExcellent, label: "DOWNLOAD")
                shimmerBox(icon: "arrow.up.circle.fill",  color: .scoreGood,       label: "UPLOAD")
            }
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.75).tint(.textTertiary)
                Text("Measuring your connection speed…")
                    .font(.system(size: 12 * scale))
                    .foregroundColor(.textSecondary)
            }
        }
    }

    private func shimmerBox(icon: String, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(color.opacity(shimmerOn ? 0.5 : 1.0))
                Text(label)
                    .font(.system(size: 9 * scale, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .tracking(0.5)
            }
            Text("—")
                .font(.system(size: 26 * scale, weight: .medium))
                .foregroundColor(.textTertiary)
                .opacity(shimmerOn ? 0.25 : 0.70)
            Text("•  •  •")
                .font(.system(size: 9 * scale))
                .foregroundColor(.textTertiary)
                .opacity(shimmerOn ? 0.30 : 0.70)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.gaugeTrack)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Speed Results Row

    private var speedResultsRow: some View {
        HStack(spacing: 8) {
            speedBox(icon: "arrow.down.circle.fill", color: .scoreExcellent,
                     label: "DOWNLOAD", mbps: metrics.throughput)
            speedBox(icon: "arrow.up.circle.fill",   color: .scoreGood,
                     label: "UPLOAD",   mbps: metrics.uploadThroughput)
        }
    }

    private func speedBox(icon: String, color: Color, label: String, mbps: Double?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9 * scale, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .tracking(0.5)
            }
            Text(speedUnit.format(mbps))
                .font(.system(size: 26 * scale, weight: .medium))
                .foregroundColor(.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(speedUnit.rawValue)
                .font(.system(size: 10 * scale, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.gaugeTrack)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Selector Row

    private func selectorRow(
        label: String,
        options: [(label: String, key: String, isSelected: Bool)],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ForEach(options, id: \.key) { option in
                    Button(action: { onSelect(option.key) }) {
                        Text(option.label)
                            .font(.system(size: 11 * scale,
                                         weight: option.isSelected ? .semibold : .regular))
                            .foregroundColor(option.isSelected ? .white : .textSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                option.isSelected
                                    ? accentColor
                                    : Color.textSecondary.opacity(0.12)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Methodology note

    private var methodologyNote: some View {
        Button(action: { showMethodology = true }) {
            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textTertiary)
                Text("Why lower than Speedtest.net?")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textTertiary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9 * scale, weight: .medium))
                    .foregroundColor(.textTertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SpeedTestTab

struct SpeedTestTab: View {
    @ObservedObject var networkVM: NetworkViewModel

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    @State private var dataUsageExpanded: Bool = true

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Circle()
                .fill(Color.scoreExcellent)
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .opacity(colorScheme == .dark ? 0.15 : 0.06)
                .offset(x: -100, y: -200)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("WiFi Check")
                        .font(.system(size: 26 * scale, weight: .bold))
                        .tracking(-0.6)
                        .foregroundColor(.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        NetworkPathCard(
                            metrics: networkVM.metrics,
                            wifiInfo: networkVM.wifiInfo,
                            accentColor: networkVM.accentColor
                        )
                        SpeedTestCard(
                            metrics: networkVM.metrics,
                            isMeasuring: networkVM.isMeasuring,
                            accentColor: networkVM.accentColor,
                            onRunTest: { networkVM.manualRefresh() }
                        )
                        dataUsageCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Data Usage Card (collapsed by default)

    private var dataUsageCard: some View {
        let runs = networkVM.throughputRunCount
        let totalMB = runs * 100
        let usageLabel = totalMB == 0 ? "0 MB"
                       : totalMB < 1000 ? "\(totalMB) MB"
                       : String(format: "%.1f GB", Double(totalMB) / 1000.0)

        return GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.22)) { dataUsageExpanded.toggle() }
                }) {
                    HStack(spacing: 0) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 17 * scale))
                            .foregroundColor(.textSecondary)
                            .padding(.trailing, 8)
                        Text("Data Usage")
                            .font(.system(size: 17 * scale, weight: .bold))
                            .foregroundColor(.textPrimary)

                        Spacer()

                        if !dataUsageExpanded {
                            Text("\(runs) test\(runs == 1 ? "" : "s") · \(usageLabel)")
                                .font(.system(size: 11 * scale))
                                .foregroundColor(.textSecondary)
                                .padding(.trailing, 6)
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12 * scale, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .rotationEffect(.degrees(dataUsageExpanded ? 180 : 0))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.textSecondary.opacity(0.15))
                .padding(.horizontal, -16)
                .padding(.top, -16)

                if dataUsageExpanded {
                    Divider().background(Color.dividerColor)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            statBox(label: "SPEED TESTS",  value: "\(runs)")
                            statBox(label: "SESSION DATA", value: usageLabel)
                            statBox(label: "PER TEST",     value: "~100 MB")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12 * scale))
                                .foregroundColor(.textTertiary)
                                .padding(.top, 1)
                            Text("Speed tests use ~75 MB download + 25 MB upload each. Larger payloads give accurate results on fast connections (100 Mbps+). Latency and packet loss checks are negligible.")
                                .font(.system(size: 12 * scale))
                                .foregroundColor(.textSecondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.textTertiary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.system(size: 9 * scale, weight: .semibold))
                .foregroundColor(.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gaugeTrack)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

//
//  GaugeCard.swift
//  WiFi Check
//

import SwiftUI

/// The main gauge card showing SSID, score ring, quality label, and activity hint.
struct GaugeCard: View {
    @ObservedObject var vm: NetworkViewModel
    let isVPN: Bool

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }
    @State private var showScoreInfo = false

    private var scoreColor: Color {
        isVPN ? .vpnActive : vm.score.level.color
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 6) {
                // Header: info icon | centered SSID | refresh icon (manual only)
                headerRow

                // Gauge ring
                gaugeRing
                    .frame(width: 200, height: 200)

                // Quality label
                if isVPN {
                    Text("Monitoring Paused")
                        .font(.system(size: 19 * scale, weight: .semibold))
                        .foregroundColor(.vpnActive)
                } else {
                    Text(vm.score.level.rawValue)
                        .font(.system(size: 19 * scale, weight: .semibold))
                        .foregroundColor(scoreColor)
                }

                // Activity hint
                Text(isVPN ? "Disconnect VPN to resume monitoring" : vm.score.level.activityHint)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showScoreInfo) {
            ScoreInfoSheet()
        }
    }

    // MARK: - Header Row

    /// ZStack keeps the SSID truly centered regardless of icon widths.
    private var headerRow: some View {
        ZStack(alignment: .center) {
            // Centered network name with live dot
            HStack(spacing: 6) {
                Circle()
                    .fill(isVPN ? Color.vpnActive : vm.accentColor)
                    .frame(width: 8, height: 8)
                Text(vm.wifiInfo.ssid)
                    .font(.system(size: 14 * scale, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            }

            // Flanking icons: info left, refresh right (manual only)
            HStack {
                Button(action: { showScoreInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16 * scale))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("scoreInfoButton")

                Spacer()

                if vm.updateFrequency == 0 {
                    Button(action: { vm.manualRefresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14 * scale, weight: .medium))
                            .foregroundColor(vm.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Gauge Ring

    private var gaugeRing: some View {
        ZStack {
            // Track
            Arc(startAngle: .degrees(-225), endAngle: .degrees(45))
                .stroke(Color.gaugeTrack, style: StrokeStyle(lineWidth: 13, lineCap: .round))

            // Fill arc
            let progress = isVPN ? 0.0 : Double(vm.score.composite) / 100.0
            Arc(startAngle: .degrees(-225), endAngle: .degrees(-225 + 270 * progress))
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .shadow(color: scoreColor.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 7)
                .shadow(color: scoreColor.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 16)
                .animation(.easeOut(duration: 1.0), value: vm.score.composite)

            // Center content
            if isVPN {
                vpnLockIcon
            } else {
                VStack(spacing: 2) {
                    Text("\(vm.score.composite)")
                        .font(.system(size: 60 * scale, weight: .light, design: .default))
                        .tracking(-3)
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }

    // MARK: - VPN Lock Icon

    private var vpnLockIcon: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 44 * scale, weight: .light))
            .foregroundColor(.vpnActive)
    }
}

// MARK: - Score Info Sheet

struct ScoreInfoSheet: View {
    @State private var showSupport = false
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How We Score Your WiFi")
                .font(.system(size: 22 * scale, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("Your score (0–100) reflects 6 real-time measurements, weighted by everyday impact.")
                .font(.system(size: 13 * scale))
                .foregroundColor(.textSecondary)

            scoreRanges
            metricsBreakdown

            Divider().background(Color.dividerColor)

            Button(action: { showSupport = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 13 * scale))
                    Text("Contact Support")
                        .font(.system(size: 14 * scale, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "0A84FF"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color.appBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSupport) { SupportSheet(preselectedCategory: .question) }
    }

    // MARK: - Score Ranges

    private var scoreRanges: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Score Ranges")
                .font(.system(size: 15 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)

            VStack(spacing: 1) {
                scoreRangeRow("80–100", "Excellent", "0A84FF", "4K streaming & gaming")
                scoreRangeRow("60–79",  "Good",      "30D158", "HD video calls")
                scoreRangeRow("40–59",  "Fair",      "FF9F0A", "Browsing OK, calls may stutter")
                scoreRangeRow("20–39",  "Poor",      "FF453A", "Move closer to router")
                scoreRangeRow("0–19",   "Very Poor", "FF453A", "Check router or contact ISP")
            }
        }
    }

    private func scoreRangeRow(_ range: String, _ label: String, _ hex: String, _ hint: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 9, height: 9)
            Text(range)
                .font(.system(size: 12 * scale, weight: .semibold, design: .monospaced))
                .foregroundColor(.textPrimary)
                .frame(width: 50, alignment: .leading)
            Text(label)
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundColor(Color(hex: hex))
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(hint)
                .font(.system(size: 11 * scale))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Metrics Breakdown

    private var metricsBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The 6 Metrics")
                .font(.system(size: 15 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)

            VStack(spacing: 1) {
                metricRow("Download Speed",  "30%", "arrow.down.circle")
                metricRow("Packet Loss",      "25%", "exclamationmark.triangle")
                metricRow("Jitter",           "15%", "waveform.path.ecg")
                metricRow("Internet Latency", "15%", "globe")
                metricRow("Router Latency",   "10%", "wifi.router")
                metricRow("DNS Speed",         "5%", "magnifyingglass")
            }
        }
    }

    private func metricRow(_ name: String, _ weight: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13 * scale))
                .foregroundColor(.textSecondary)
                .frame(width: 18, alignment: .center)
            Text(name)
                .font(.system(size: 13 * scale))
                .foregroundColor(.textPrimary)
            Spacer()
            Text(weight)
                .font(.system(size: 11 * scale, weight: .bold))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.textSecondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Arc Shape

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle

    var animatableData: AnimatablePair<Double, Double> {
        get { .init(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 78
        var path = Path()
        path.addArc(center: center, radius: radius,
                     startAngle: startAngle, endAngle: endAngle,
                     clockwise: false)
        return path
    }
}

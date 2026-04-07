//
//  BandwidthView.swift
//  WiFi Check TV
//

import SwiftUI

struct BandwidthView: View {

    @ObservedObject var networkVM: NetworkViewModel

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Circle()
                .fill(Color(hex: "0A84FF").opacity(0.12))
                .frame(width: 600, height: 600)
                .blur(radius: 200)
                .offset(x: -350, y: -200)

            Circle()
                .fill(Color.accentGreen.opacity(0.10))
                .frame(width: 500, height: 500)
                .blur(radius: 180)
                .offset(x: 400, y: 250)

            GeometryReader { geo in
                VStack(spacing: 24) {

                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "0A84FF"))
                        Text("Device Bandwidth")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Spacer()
                        interfaceBadge
                    }

                    HStack(spacing: 24) {

                        VStack(spacing: 20) {
                            liveSpeedCard(
                                label: "DOWNLOAD",
                                speed: networkVM.bandwidth.downloadFormatted,
                                bytesPerSec: networkVM.bandwidth.downloadBytesPerSec,
                                peak: networkVM.peakDownload,
                                icon: "arrow.down.circle.fill",
                                color: Color(hex: "0A84FF"),
                                history: networkVM.bandwidthHistory.map(\.downloadBytesPerSec)
                            )
                            liveSpeedCard(
                                label: "UPLOAD",
                                speed: networkVM.bandwidth.uploadFormatted,
                                bytesPerSec: networkVM.bandwidth.uploadBytesPerSec,
                                peak: networkVM.peakUpload,
                                icon: "arrow.up.circle.fill",
                                color: Color(hex: "30D158"),
                                history: networkVM.bandwidthHistory.map(\.uploadBytesPerSec)
                            )
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            sessionStatsPanel
                            packetStatsPanel
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            combinedSparklineCard
                            peakRecordsCard
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Text("Made with ❤️ by Santosh T")
                        .font(.system(size: 13))
                        .foregroundColor(.textTertiary)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 20)
            }
        }
    }

    @ViewBuilder
    private var interfaceBadge: some View {
        let iface = networkVM.bandwidth.interface
        let isWiFi = iface == "en0"
        HStack(spacing: 6) {
            Image(systemName: isWiFi ? "wifi" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 16))
            Text(isWiFi ? "WiFi (en0)" : "Cellular (pdp_ip0)")
                .font(.system(size: 16, weight: .medium))
        }
        .foregroundColor(isWiFi ? .accentGreen : Color(hex: "FF9F0A"))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func liveSpeedCard(
        label: String,
        speed: String,
        bytesPerSec: Double,
        peak: Double,
        icon: String,
        color: Color,
        history: [Double]
    ) -> some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
                Text(speed)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if peak > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 6)
                            RoundedRectangle(cornerRadius: 3).fill(color)
                                .frame(width: geo.size.width * min(bytesPerSec / peak, 1.0), height: 6)
                                .animation(.easeOut(duration: 0.3), value: bytesPerSec)
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text("Current").foregroundColor(.textTertiary)
                        Spacer()
                        Text("Peak: \(DeviceBandwidthService.BandwidthReading.formatBytes(peak))/s")
                            .foregroundColor(color.opacity(0.8))
                    }
                    .font(.system(size: 12))
                }
                if history.count >= 3 {
                    BandwidthSparkline(data: history.suffix(60).map { $0 }, color: color).frame(height: 30)
                }
            }
        }
    }

    @ViewBuilder
    private var sessionStatsPanel: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill").font(.system(size: 18)).foregroundColor(.textSecondary)
                    Text("Session Totals").font(.system(size: 18, weight: .semibold)).foregroundColor(.textPrimary)
                }
                VStack(spacing: 10) {
                    sessionRow(label: "Downloaded", value: networkVM.bandwidth.sessionInFormatted, icon: "arrow.down", color: Color(hex: "0A84FF"))
                    sessionRow(label: "Uploaded", value: networkVM.bandwidth.sessionOutFormatted, icon: "arrow.up", color: Color(hex: "30D158"))
                    Divider().background(Color.white.opacity(0.1))
                    sessionRow(label: "Total", value: networkVM.bandwidth.sessionTotalFormatted, icon: "arrow.up.arrow.down", color: .textPrimary)
                }
                HStack {
                    Text("Session Duration").font(.system(size: 13)).foregroundColor(.textTertiary)
                    Spacer()
                    Text(networkVM.sessionUptime).font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundColor(.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color).frame(width: 20)
            Text(label).font(.system(size: 15)).foregroundColor(.textSecondary)
            Spacer()
            Text(value).font(.system(size: 17, weight: .medium, design: .monospaced)).foregroundColor(.textPrimary)
        }
    }

    @ViewBuilder
    private var packetStatsPanel: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill").font(.system(size: 18)).foregroundColor(.textSecondary)
                    Text("Packets").font(.system(size: 18, weight: .semibold)).foregroundColor(.textPrimary)
                }
                HStack(spacing: 16) {
                    packetStat(label: "IN", value: formatPackets(networkVM.bandwidth.packetsIn), color: Color(hex: "0A84FF"))
                    packetStat(label: "OUT", value: formatPackets(networkVM.bandwidth.packetsOut), color: Color(hex: "30D158"))
                }
            }
        }
    }

    @ViewBuilder
    private func packetStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.textTertiary)
            Text(value).font(.system(size: 20, weight: .light, design: .monospaced)).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var combinedSparklineCard: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 18)).foregroundColor(.textSecondary)
                    Text("Live History").font(.system(size: 18, weight: .semibold)).foregroundColor(.textPrimary)
                    Spacer()
                    Text("\(networkVM.bandwidthHistory.count) samples").font(.system(size: 12)).foregroundColor(.textTertiary)
                }
                if networkVM.bandwidthHistory.count >= 3 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: "0A84FF")).frame(width: 6, height: 6)
                            Text("Download").font(.system(size: 11)).foregroundColor(.textTertiary)
                            Spacer()
                            Circle().fill(Color(hex: "30D158")).frame(width: 6, height: 6)
                            Text("Upload").font(.system(size: 11)).foregroundColor(.textTertiary)
                        }
                        BandwidthSparkline(data: networkVM.bandwidthHistory.suffix(60).map(\.downloadBytesPerSec), color: Color(hex: "0A84FF")).frame(height: 50)
                        BandwidthSparkline(data: networkVM.bandwidthHistory.suffix(60).map(\.uploadBytesPerSec), color: Color(hex: "30D158")).frame(height: 50)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 30)).foregroundColor(.textTertiary)
                        Text("Collecting data…").font(.system(size: 14)).foregroundColor(.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var peakRecordsCard: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill").font(.system(size: 18)).foregroundColor(Color(hex: "FFD60A"))
                    Text("Peak Speeds").font(.system(size: 18, weight: .semibold)).foregroundColor(.textPrimary)
                }
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down").font(.system(size: 14)).foregroundColor(Color(hex: "0A84FF"))
                        Text(DeviceBandwidthService.BandwidthReading.formatBytes(networkVM.peakDownload) + "/s")
                            .font(.system(size: 18, weight: .medium, design: .monospaced)).foregroundColor(.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("Download").font(.system(size: 11)).foregroundColor(.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up").font(.system(size: 14)).foregroundColor(Color(hex: "30D158"))
                        Text(DeviceBandwidthService.BandwidthReading.formatBytes(networkVM.peakUpload) + "/s")
                            .font(.system(size: 18, weight: .medium, design: .monospaced)).foregroundColor(.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("Upload").font(.system(size: 11)).foregroundColor(.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func formatPackets(_ count: UInt64) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000     { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Bandwidth Sparkline

struct BandwidthSparkline: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = data.max() ?? 1
            let safeMax = maxVal > 0 ? maxVal : 1
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                for (i, val) in data.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                    let y = h - (h * CGFloat(val / safeMax))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            Path { path in
                for (i, val) in data.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                    let y = h - (h * CGFloat(val / safeMax))
                    if i == 0 { path.move(to: CGPoint(x: 0, y: h)); path.addLine(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [color.opacity(0.25), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
        }
    }
}

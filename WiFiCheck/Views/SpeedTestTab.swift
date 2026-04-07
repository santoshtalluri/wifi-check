//
//  SpeedTestTab.swift
//  WiFi Check v1
//

import SwiftUI

struct SpeedTestSite: Identifiable {
    let id = UUID()
    let name: String
    let domain: String
    let faviconColor: Color
    let faviconLetter: String
}

struct SpeedTestTab: View {
    @State private var sites: [SpeedTestSite] = [
        SpeedTestSite(name: "Google", domain: "google.com", faviconColor: Color(hex: "4285F4"), faviconLetter: "G"),
        SpeedTestSite(name: "Facebook", domain: "facebook.com", faviconColor: Color(hex: "1877F2"), faviconLetter: "f"),
        SpeedTestSite(name: "Apple", domain: "apple.com", faviconColor: Color(hex: "555555"), faviconLetter: ""),
    ]

    @State private var results: [String: SiteTestResult] = [:]
    @State private var testing: Set<String> = []

    private let speedService = SiteSpeedService()

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Ambient orbs
            ZStack {
                Circle()
                    .fill(Color.scoreExcellent)
                    .frame(width: 360, height: 360)
                    .blur(radius: 90)
                    .opacity(colorScheme == .dark ? 0.15 : 0.06)
                    .offset(x: -100, y: -200)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
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
                        ForEach(sites) { site in
                            siteCard(site)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func siteCard(_ site: SpeedTestSite) -> some View {
        let result = results[site.domain]
        let isTesting = testing.contains(site.domain)

        return GlassCard {
            VStack(spacing: 10) {
                // Site header
                HStack(spacing: 10) {
                    // Favicon
                    RoundedRectangle(cornerRadius: 8)
                        .fill(site.faviconColor)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(site.faviconLetter)
                                .font(.system(size: 16 * scale, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(site.name)
                            .font(.system(size: 15 * scale, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text(site.domain)
                            .font(.system(size: 11 * scale))
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    // Test button
                    Button(action: { testSite(site) }) {
                        if isTesting {
                            ProgressView()
                                .tint(.scoreExcellent)
                                .scaleEffect(0.8)
                        } else {
                            Text(result != nil ? "Retest" : "Test")
                                .font(.system(size: 12 * scale, weight: .semibold))
                                .foregroundColor(.scoreExcellent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.scoreExcellent.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .disabled(isTesting)
                    .accessibilityIdentifier("testButton_\(site.name.lowercased())")
                }

                // Metrics row
                HStack(spacing: 6) {
                    metricBox(label: "LATENCY", value: formatLatency(result?.latency), isTesting: isTesting)
                    metricBox(label: "DOWNLOAD", value: formatSpeed(result?.downloadSpeed), isTesting: isTesting)
                    metricBox(label: "DNS", value: formatDNS(result?.dnsTime), isTesting: isTesting)
                }
            }
        }
    }

    private func metricBox(label: String, value: String?, isTesting: Bool) -> some View {
        VStack(spacing: 2) {
            if isTesting {
                ProgressView()
                    .tint(.textTertiary)
                    .scaleEffect(0.6)
                    .frame(height: 20)
            } else {
                Text(value ?? "--")
                    .font(.system(size: 16 * scale, weight: .light))
                    .foregroundColor(.textPrimary)
                    .frame(height: 20)
            }
            Text(label)
                .font(.system(size: 9 * scale, weight: .semibold))
                .foregroundColor(.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gaugeTrack)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private func testSite(_ site: SpeedTestSite) {
        testing.insert(site.domain)
        Task {
            let result = await speedService.testSite(domain: site.domain)
            await MainActor.run {
                results[site.domain] = result
                testing.remove(site.domain)
            }
        }
    }

    // MARK: - Formatting

    private func formatLatency(_ value: Double?) -> String? {
        guard let v = value else { return nil }
        return String(format: "%.0f ms", v)
    }

    private func formatSpeed(_ value: Double?) -> String? {
        guard let v = value else { return nil }
        if v >= 100 { return String(format: "%.0f Mbps", v) }
        return String(format: "%.1f Mbps", v)
    }

    private func formatDNS(_ value: Double?) -> String? {
        guard let v = value else { return nil }
        return String(format: "%.0f ms", v)
    }
}

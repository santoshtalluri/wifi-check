//
//  SpeedTestView.swift
//  WiFi Check TV
//

import SwiftUI

struct SpeedTestView: View {
    @ObservedObject var networkVM: NetworkViewModel

    @State private var results: [String: SiteTestResult] = [:]
    @State private var isTesting = false

    private let speedService = SiteSpeedService()

    private let siteConfigs: [(name: String, domain: String, color: Color, letter: String)] = [
        ("Google", "google.com", Color(hex: "#4285F4"), "G"),
        ("Facebook", "facebook.com", Color(hex: "#1877F2"), "f"),
        ("Apple", "apple.com", Color(hex: "#555555"), "\u{25CF}")
    ]

    private var averageSpeed: Double? {
        let speeds = siteConfigs.compactMap { results[$0.domain]?.downloadSpeed }
        guard !speeds.isEmpty else { return nil }
        return speeds.reduce(0, +) / Double(speeds.count)
    }

    var body: some View {
        HStack(spacing: 40) {
            TVGlassCard {
                VStack(spacing: 16) {
                    Spacer()
                    Text("DOWNLOAD SPEED")
                        .font(.system(size: 16, weight: .medium)).foregroundColor(.textTertiary).tracking(3)
                    ZStack {
                        if let avg = averageSpeed {
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 80, weight: .ultraLight)).foregroundColor(.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
                        } else {
                            Text("--")
                                .font(.system(size: 80, weight: .ultraLight)).foregroundColor(.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center).multilineTextAlignment(.center)
                        }
                        if isTesting { ProgressView().progressViewStyle(.circular).scaleEffect(3) }
                    }
                    Text("Mbps").font(.system(size: 18, weight: .regular)).foregroundColor(.textSecondary)
                    Spacer()
                    Button(action: { testAllSites() }) {
                        HStack(spacing: 8) {
                            if isTesting { ProgressView().tint(.white).scaleEffect(0.9) }
                            Text(isTesting ? "Testing…" : "Test All Sites").font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.scoreGood).controlSize(.large).disabled(isTesting)
                    .accessibilityIdentifier("tvTestAllButton")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 20) {
                ForEach(Array(siteConfigs.enumerated()), id: \.offset) { _, site in
                    siteCard(site: site)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func siteCard(site: (name: String, domain: String, color: Color, letter: String)) -> some View {
        let result = results[site.domain]
        TVGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(site.color).frame(width: 36, height: 36)
                        Text(site.letter).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.name).font(.system(size: 18, weight: .semibold)).foregroundColor(.textPrimary)
                        Text(site.domain).font(.system(size: 13)).foregroundColor(.textTertiary)
                    }
                    Spacer()
                }
                HStack(spacing: 0) {
                    metricBlock(label: "LATENCY", value: result?.latency, unit: "ms", decimals: 0)
                    Spacer()
                    metricBlock(label: "DOWNLOAD", value: result?.downloadSpeed, unit: "Mbps", decimals: 1)
                    Spacer()
                    metricBlock(label: "DNS", value: result?.dnsTime, unit: "ms", decimals: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func metricBlock(label: String, value: Double?, unit: String, decimals: Int) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.textTertiary).tracking(1)
            if let value = value {
                Text(decimals == 0 ? "\(Int(value))" : String(format: "%.\(decimals)f", value))
                    .font(.system(size: 32, weight: .light)).foregroundColor(.textPrimary)
            } else {
                Text("--").font(.system(size: 32, weight: .light)).foregroundColor(.textTertiary)
            }
            Text(unit).font(.system(size: 12)).foregroundColor(.textSecondary)
        }
        .frame(minWidth: 100)
    }

    private func testAllSites() {
        isTesting = true
        Task {
            await withTaskGroup(of: (String, SiteTestResult).self) { group in
                for site in siteConfigs {
                    group.addTask {
                        let result = await speedService.testSite(domain: site.domain)
                        return (site.domain, result)
                    }
                }
                for await (domain, result) in group {
                    await MainActor.run { results[domain] = result }
                }
            }
            await MainActor.run { isTesting = false }
        }
    }
}

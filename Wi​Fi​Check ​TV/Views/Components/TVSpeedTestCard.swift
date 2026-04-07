//
//  TVSpeedTestCard.swift
//  WiFi Check TV
//
//  TV-sized: site name 15pt, metric values 14pt, wider metric columns.
//

import SwiftUI

struct TVSpeedTestCard: View {
    private let speedService = SiteSpeedService()
    @State private var results: [String: SiteTestResult] = [:]
    @State private var isTesting = false

    private let siteConfigs: [(name: String, domain: String, color: Color, letter: String)] = [
        ("Google", "google.com", Color(hex: "4285F4"), "G"),
        ("Facebook", "facebook.com", Color(hex: "1877F2"), "f"),
        ("Apple", "apple.com", Color(hex: "555555"), "\u{25CF}")
    ]

    var body: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text("Speed Test")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: { testAll() }) {
                        HStack(spacing: 5) {
                            if isTesting {
                                ProgressView().tint(.scoreGood).scaleEffect(0.7)
                            }
                            Text(isTesting ? "Testing…" : "Test All")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isTesting ? .textTertiary : .scoreGood)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(TVGhostCapsuleStyle(accentColor: .scoreGood))
                    .disabled(isTesting)
                }

                // Site rows
                ForEach(Array(siteConfigs.enumerated()), id: \.offset) { index, site in
                    if index > 0 {
                        Divider().background(Color.dividerColor)
                    }
                    siteRow(site: site)
                }
            }
        }
    }

    private func testAll() {
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
                    await MainActor.run {
                        results[domain] = result
                    }
                }
            }
            await MainActor.run { isTesting = false }
        }
    }

    @ViewBuilder
    private func siteRow(site: (name: String, domain: String, color: Color, letter: String)) -> some View {
        let result = results[site.domain]

        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(site.color)
                    .frame(width: 28, height: 28)
                Text(site.letter)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(site.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 72, alignment: .leading)

            Spacer(minLength: 2)

            HStack(spacing: 8) {
                metricColumn(label: "LAT", value: result?.latency, unit: "ms", decimals: 0)
                metricColumn(label: "DL", value: result?.downloadSpeed, unit: "", decimals: 1)
                metricColumn(label: "DNS", value: result?.dnsTime, unit: "ms", decimals: 0)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func metricColumn(label: String, value: Double?, unit: String, decimals: Int) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textTertiary)
                .lineLimit(1)
            if let value = value {
                Text(decimals == 0 ? "\(Int(value))\(unit)" : String(format: "%.\(decimals)f\(unit)", value))
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
            } else {
                Text("--")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.textTertiary)
            }
        }
        .frame(minWidth: 44)
    }
}

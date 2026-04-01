//
//  SpeedTestCard.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Expandable speed test card
/// Phase 1: Simulated results
struct SpeedTestCard: View {
    @ObservedObject var speedVM: SpeedTestViewModel
    let currentScore: Int

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                // Header row (always visible)
                Button(action: { withAnimation { speedVM.isExpanded.toggle() } }) {
                    HStack {
                        Image(systemName: "speedometer")
                            .font(.system(size: 16))
                            .foregroundColor(.scoreExcellent)

                        Text("Speed Test")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Text(speedVM.lastTestedText)
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)

                        Image(systemName: speedVM.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                if speedVM.isExpanded {
                    Divider().background(Color.white.opacity(0.06))

                    if speedVM.state == .idle || speedVM.state == .completed {
                        // Results or start button
                        if speedVM.state == .completed {
                            resultsRow
                        }

                        Button(action: {
                            Task { await speedVM.runTest(currentScore: currentScore) }
                        }) {
                            Text(speedVM.state == .completed ? "Run Again" : "Start Speed Test")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.scoreExcellent.opacity(0.3))
                                .cornerRadius(10)
                        }
                    } else {
                        // Running state
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(.scoreExcellent)
                            Text(speedVM.statusText)
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private var resultsRow: some View {
        HStack(spacing: 0) {
            resultColumn(label: "Download", value: "\(Int(speedVM.downloadMbps))", unit: "Mbps")
            Spacer()
            resultColumn(label: "Upload", value: "\(Int(speedVM.uploadMbps))", unit: "Mbps")
            Spacer()
            resultColumn(label: "Ping", value: "\(speedVM.pingMs)", unit: "ms")
        }
        .padding(.vertical, 4)
    }

    private func resultColumn(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .light, design: .monospaced))
                .foregroundColor(.textPrimary)
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
    }
}

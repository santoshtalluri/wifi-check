//
//  TVSessionStatsCard.swift
//  WiFi Check TV
//
//  TV-sized: stat values 20pt, labels 11pt.
//

import SwiftUI

struct TVSessionStatsCard: View {
    let uptime: String
    let avgScore: Int
    let sampleCount: Int
    let countdown: Int
    let accentColor: Color

    var body: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text("Session Stats")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }

                // Stat boxes
                HStack(spacing: 6) {
                    statBox(label: "UPTIME", value: uptime, color: .white)
                    statBox(label: "AVG", value: "\(avgScore)", color: accentColor)
                    statBox(label: "READS", value: "\(sampleCount)", color: .white)
                    statBox(label: "NEXT", value: "\(countdown)s", color: Color(hex: "0A84FF"))
                }
            }
        }
    }

    @ViewBuilder
    private func statBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textTertiary)
                .textCase(.uppercase)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

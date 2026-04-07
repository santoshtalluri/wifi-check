//
//  TVGaugeCard.swift
//  WiFi Check TV
//
//  Sized for 10-foot tvOS viewing: 200x200 gauge, 56pt score, 20pt label.
//

import SwiftUI

struct TVGaugeCard: View {
    @ObservedObject var networkVM: NetworkViewModel

    // MARK: - Layout Constants

    private let gaugeSize: CGFloat = 180
    private let strokeWidth: CGFloat = 12

    var body: some View {
        TVGlassCard {
            VStack(spacing: 16) {
                // SSID with wifi icon
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi")
                            .font(.system(size: 18))
                            .foregroundColor(.accentGreen)
                        Text(networkVM.wifiInfo.ssid)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Text("Connected")
                        .font(.system(size: 13))
                        .foregroundColor(.accentGreen)
                }

                // Circular Gauge
                ZStack {
                    // Track — same color as arc but very dim
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(gaugeArcColor.opacity(0.15), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                        .rotationEffect(.degrees(135))
                        .frame(width: gaugeSize, height: gaugeSize)

                    // Filled arc — solid color + glow
                    Circle()
                        .trim(from: 0, to: gaugeProgress)
                        .stroke(gaugeArcColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                        .rotationEffect(.degrees(135))
                        .frame(width: gaugeSize, height: gaugeSize)
                        .shadow(color: gaugeArcColor.opacity(0.8), radius: 12, x: 0, y: 0)
                        .shadow(color: gaugeArcColor.opacity(0.4), radius: 24, x: 0, y: 0)
                        .animation(.easeInOut(duration: 0.6), value: networkVM.score.composite)

                    // Score number in center
                    VStack(spacing: 4) {
                        Text("\(networkVM.score.composite)")
                            .font(.system(size: 56, weight: .light, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Text(networkVM.score.level.rawValue)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(levelColor)
                    }
                }
                .frame(height: gaugeSize + 14)

                // Activity hint
                Text(activityHint)
                    .font(.system(size: 15))
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(4)
        }
    }

    // MARK: - Helpers

    private var gaugeProgress: Double {
        min(max(Double(networkVM.score.composite) / 100.0, 0), 1) * 0.75
    }

    private var accentColor: Color {
        Color(hex: networkVM.accentColorHex)
    }

    private var gaugeArcColor: Color {
        let score = networkVM.score.composite
        switch score {
        case 80...100: return Color(hex: "30D158")  // Green
        case 60..<80:  return Color(hex: "FFD60A")  // Yellow
        case 40..<60:  return Color(hex: "FF9F0A")  // Orange
        default:       return Color(hex: "FF453A")  // Red
        }
    }

    private var levelColor: Color {
        switch networkVM.score.level {
        case .excellent: return .scoreExcellent
        case .good:      return .accentGreen
        case .fair:      return .scoreFair
        case .poor:      return .scorePoor
        case .veryPoor:  return .scorePoor
        }
    }

    private var activityHint: String {
        switch networkVM.score.level {
        case .excellent: return "Excellent for all activities"
        case .good:      return "HD streaming and calls work fine"
        case .fair:      return "Basic browsing, calls may drop"
        case .poor:      return "Very limited connectivity"
        case .veryPoor:  return "Connection unusable"
        }
    }
}

//
//  TooltipSheet.swift
//  WiFi Check
//

import SwiftUI

/// Bottom sheet showing a rich explanation for a tapped metric
struct TooltipSheet: View {
    let metric: MetricType

    @Environment(\.dismiss) private var dismiss
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        VStack(spacing: 0) {

            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // Icon + title
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(metric.iconColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: metric.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(metric.iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.displayName)
                        .font(.system(size: 18 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)

                    // Impact tags
                    HStack(spacing: 6) {
                        ForEach(metric.impactAreas, id: \.self) { area in
                            Text(area)
                                .font(.system(size: 10 * scale, weight: .medium))
                                .foregroundColor(metric.iconColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(metric.iconColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            Divider()
                .background(Color.dividerColor)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            // Plain English explanation
            Text(metric.explanation)
                .font(.system(size: 14 * scale))
                .foregroundColor(.textSecondary)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Threshold scale
            VStack(spacing: 0) {
                HStack {
                    Text("THRESHOLDS")
                        .font(.system(size: 10 * scale, weight: .semibold))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(metric.thresholds.enumerated()), id: \.offset) { index, threshold in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(threshold.color)
                                .frame(width: 8, height: 8)
                            Text(threshold.label)
                                .font(.system(size: 13 * scale, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text(threshold.value)
                                .font(.system(size: 13 * scale))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)

                        if index < metric.thresholds.count - 1 {
                            Divider()
                                .background(Color.dividerColor)
                                .padding(.leading, 36)
                        }
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Got it button
            Button(action: { dismiss() }) {
                Text("Got it")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundColor(Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(metric.iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .accessibilityIdentifier("tooltipDismissButton")
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - MetricType threshold & impact data

extension MetricType {

    struct Threshold {
        let label: String
        let value: String
        let color: Color
    }

    var impactAreas: [String] {
        switch self {
        case .throughput:       return ["Streaming", "Downloads"]
        case .uploadThroughput: return ["Video Calls", "Uploads"]
        case .packetLoss:       return ["Video Calls", "Gaming"]
        case .jitter:           return ["Gaming", "Video Calls"]
        case .internetLatency:  return ["Browsing", "Streaming"]
        case .routerLatency:    return ["All Traffic"]
        case .dnsSpeed:         return ["Page Loads"]
        }
    }

    var thresholds: [Threshold] {
        switch self {
        case .throughput:
            return [
                Threshold(label: "Excellent", value: "100+ Mbps",  color: .scoreExcellent),
                Threshold(label: "Good",      value: "25–100 Mbps", color: .scoreGood),
                Threshold(label: "Fair",      value: "10–25 Mbps",  color: .scoreFair),
                Threshold(label: "Poor",      value: "< 10 Mbps",   color: .scorePoor),
            ]
        case .uploadThroughput:
            return [
                Threshold(label: "Excellent", value: "50+ Mbps",  color: .scoreExcellent),
                Threshold(label: "Good",      value: "10–50 Mbps", color: .scoreGood),
                Threshold(label: "Fair",      value: "5–10 Mbps",  color: .scoreFair),
                Threshold(label: "Poor",      value: "< 5 Mbps",   color: .scorePoor),
            ]
        case .packetLoss:
            return [
                Threshold(label: "Excellent", value: "0%",       color: .scoreExcellent),
                Threshold(label: "Good",      value: "< 0.5%",   color: .scoreGood),
                Threshold(label: "Fair",      value: "0.5–2%",   color: .scoreFair),
                Threshold(label: "Poor",      value: "> 2%",     color: .scorePoor),
            ]
        case .jitter:
            return [
                Threshold(label: "Excellent", value: "< 5 ms",   color: .scoreExcellent),
                Threshold(label: "Good",      value: "5–15 ms",  color: .scoreGood),
                Threshold(label: "Fair",      value: "15–30 ms", color: .scoreFair),
                Threshold(label: "Poor",      value: "> 30 ms",  color: .scorePoor),
            ]
        case .internetLatency:
            return [
                Threshold(label: "Excellent", value: "< 20 ms",   color: .scoreExcellent),
                Threshold(label: "Good",      value: "20–50 ms",  color: .scoreGood),
                Threshold(label: "Fair",      value: "50–100 ms", color: .scoreFair),
                Threshold(label: "Poor",      value: "> 100 ms",  color: .scorePoor),
            ]
        case .routerLatency:
            return [
                Threshold(label: "Excellent", value: "< 5 ms",  color: .scoreExcellent),
                Threshold(label: "Good",      value: "5–20 ms", color: .scoreGood),
                Threshold(label: "Fair",      value: "20–50 ms", color: .scoreFair),
                Threshold(label: "Poor",      value: "> 50 ms", color: .scorePoor),
            ]
        case .dnsSpeed:
            return [
                Threshold(label: "Excellent", value: "< 20 ms",   color: .scoreExcellent),
                Threshold(label: "Good",      value: "20–50 ms",  color: .scoreGood),
                Threshold(label: "Fair",      value: "50–100 ms", color: .scoreFair),
                Threshold(label: "Poor",      value: "> 100 ms",  color: .scorePoor),
            ]
        }
    }
}

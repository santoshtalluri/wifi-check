//
//  TooltipSheet.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Bottom sheet showing plain-English explanation for a metric
struct TooltipSheet: View {
    let metric: MetricType

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Image(systemName: metric.iconName)
                .font(.system(size: 32))
                .foregroundColor(metric.iconColor)

            Text(metric.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.textPrimary)

            Text(metric.explanation)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button("Got it") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

//
//  TVActivityRecommendations.swift
//  WiFi Check TV
//
//  TV-sized pills: 14pt font, 6pt/14pt padding.
//

import SwiftUI

struct TVActivityRecommendations: View {
    let recommendations: [NetworkViewModel.ActivityRecommendation]

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 6)
    ]

    var body: some View {
        TVGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    Text("What You Can Do")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }

                Spacer(minLength: 0)

                // Activity pills grid
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(recommendations, id: \.name) { recommendation in
                        activityPill(recommendation)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func activityPill(_ recommendation: NetworkViewModel.ActivityRecommendation) -> some View {
        let config = pillConfig(for: recommendation.status)

        HStack(spacing: 5) {
            Image(systemName: config.symbol)
                .font(.system(size: 12, weight: .bold))
            Text(recommendation.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundColor(config.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(config.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private struct PillConfig {
        let symbol: String
        let color: Color
    }

    private func pillConfig(for status: NetworkViewModel.ActivityStatus) -> PillConfig {
        switch status {
        case .good:
            return PillConfig(symbol: "checkmark.circle.fill", color: .scoreGood)
        case .borderline:
            return PillConfig(symbol: "minus.circle.fill", color: .scoreFair)
        case .poor:
            return PillConfig(symbol: "xmark.circle.fill", color: .scorePoor)
        }
    }
}

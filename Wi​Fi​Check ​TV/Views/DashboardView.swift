//
//  DashboardView.swift
//  WiFi Check (tvOS)
//
//  Proportional 2-row grid — scales uniformly across 1080p / 4K.
//  Uses a custom Layout to precisely place cards at weighted widths.
//

import SwiftUI

// MARK: - Weighted column layout

/// Places subviews side-by-side at proportional widths derived from `weights`.
private struct WeightedHStack: Layout {
    let weights: [CGFloat]
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let gaps = spacing * CGFloat(max(subviews.count - 1, 0))
        let available = bounds.width - gaps
        let total = weights.prefix(subviews.count).reduce(0 as CGFloat, +)
        guard total > 0 else { return }

        var x = bounds.minX
        for (i, subview) in subviews.enumerated() {
            let w = i < weights.count ? weights[i] : 1
            let colW = available * (w / total)
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: colW, height: bounds.height)
            )
            x += colW + spacing
        }
    }
}

// MARK: - Dashboard

struct DashboardView: View {

    @ObservedObject var networkVM: NetworkViewModel

    private let topW: [CGFloat] = [2.5, 4, 3.5]
    private let botW: [CGFloat] = [3, 4, 3]
    private static let topFraction: CGFloat = 0.55
    private let gap: CGFloat = 28

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Circle()
                .fill(Color.scoreGood.opacity(0.15))
                .frame(width: 600, height: 600)
                .blur(radius: 200)
                .offset(x: -400, y: -300)

            Circle()
                .fill(Color.scoreExcellent.opacity(0.12))
                .frame(width: 700, height: 700)
                .blur(radius: 220)
                .offset(x: 400, y: 300)

            GeometryReader { geo in
                let h = geo.size.height
                let topH = (h - gap) * Self.topFraction
                let botH = (h - gap) * (1 - Self.topFraction)

                VStack(spacing: gap) {
                    WeightedHStack(weights: topW, spacing: gap) {
                        TVGaugeCard(networkVM: networkVM)
                        TVMetricsGrid(metrics: networkVM.metrics, score: networkVM.score)
                        TVScoreBreakdown(score: networkVM.score, bottleneck: networkVM.bottleneckMetric)
                    }
                    .frame(height: topH)

                    WeightedHStack(weights: botW, spacing: gap) {
                        TVNetworkInfoCard(info: networkVM.wifiInfo)
                        TVNetworkPathView(
                            routerLatency: networkVM.metrics.routerLatency,
                            internetLatency: networkVM.metrics.internetLatency,
                            gatewayIP: networkVM.wifiInfo.gatewayIP,
                            publicIP: networkVM.wifiInfo.publicIP
                        )
                        TVActivityRecommendations(recommendations: networkVM.activityRecommendations)
                    }
                    .frame(height: botH)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
        }
    }
}

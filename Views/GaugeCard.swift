//
//  GaugeCard.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// The main gauge card showing SSID, score ring, quality label,
/// activity hint, and frequency selector
struct GaugeCard: View {
    @ObservedObject var vm: NetworkViewModel
    let isVPN: Bool

    private var scoreColor: Color {
        isVPN ? .vpnActive : vm.score.level.color
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                // SSID row with live dot
                ssidRow

                // Gauge ring
                gaugeRing
                    .frame(width: 200, height: 200)

                // Quality label
                if isVPN {
                    Text("Monitoring Paused")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.vpnActive)
                } else {
                    Text(vm.score.level.rawValue)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(scoreColor)
                }

                // Activity hint
                Text(isVPN ? "Disconnect VPN to resume monitoring" : vm.score.level.activityHint)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

                // Frequency selector
                frequencySelector
            }
        }
    }

    // MARK: - SSID Row

    private var ssidRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isVPN ? Color.vpnActive : vm.accentColor)
                .frame(width: 8, height: 8)

            Text(vm.wifiInfo.ssid)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary)
        }
    }

    // MARK: - Gauge Ring

    private var gaugeRing: some View {
        ZStack {
            // Track
            Arc(startAngle: .degrees(-225), endAngle: .degrees(45))
                .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 13, lineCap: .round))

            // Fill arc
            let progress = isVPN ? 0.0 : Double(vm.score.composite) / 100.0
            Arc(startAngle: .degrees(-225), endAngle: .degrees(-225 + 270 * progress))
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .shadow(color: scoreColor.opacity(0.5), radius: 7)
                .shadow(color: scoreColor.opacity(0.3), radius: 16)
                .animation(.easeOut(duration: 1.0), value: vm.score.composite)

            // Center content
            if isVPN {
                vpnLockIcon
            } else {
                VStack(spacing: 2) {
                    Text("\(vm.score.composite)")
                        .font(.system(size: 60, weight: .light, design: .default))
                        .tracking(-3)
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }

    // MARK: - VPN Lock Icon

    private var vpnLockIcon: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 44, weight: .light))
            .foregroundColor(.vpnActive)
    }

    // MARK: - Frequency Selector

    private var frequencySelector: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                frequencyButton(label: "2s", value: 2)
                frequencyButton(label: "5s", value: 5)
                frequencyButton(label: "Manual", value: 0)
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)

            if vm.updateFrequency == 0 {
                Button(action: { vm.manualRefresh() }) {
                    Text("Refresh Now")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(vm.accentColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(vm.accentColor.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
    }

    private func frequencyButton(label: String, value: Int) -> some View {
        Button(action: { vm.setUpdateFrequency(value) }) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(vm.updateFrequency == value ? .white : .textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    vm.updateFrequency == value
                        ? vm.accentColor.opacity(0.3) : Color.clear
                )
                .cornerRadius(8)
        }
    }
}

// MARK: - Arc Shape

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle

    var animatableData: AnimatablePair<Double, Double> {
        get { .init(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius: CGFloat = 78
        var path = Path()
        path.addArc(center: center, radius: radius,
                     startAngle: startAngle, endAngle: endAngle,
                     clockwise: false)
        return path
    }
}

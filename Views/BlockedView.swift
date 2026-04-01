//
//  BlockedView.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Full-screen blocked states:
/// - No Local Network permission
/// - No WiFi connected
struct BlockedView: View {
    let type: BlockedType

    enum BlockedType {
        case noPermission
        case noWiFi
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: type == .noPermission ? "lock.shield" : "wifi.slash")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.textSecondary)

            // Title
            Text(type == .noPermission
                 ? "Local Network Access Needed"
                 : "No WiFi Connected")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            // Body
            Text(type == .noPermission
                 ? "This app measures your WiFi quality by communicating with your router. Without local network access it cannot function."
                 : "Connect to a WiFi network to start monitoring your signal quality. This app works on WiFi only, not on cellular.")
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Reassurance box
            reassuranceBox

            // Action button
            Button(action: openSettings) {
                Text(type == .noPermission
                     ? "Open Settings to Allow Access"
                     : "Open WiFi Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.scoreExcellent)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var reassuranceBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 14))
                    .foregroundColor(.scoreGood)
                Text("Your privacy is protected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.scoreGood)
            }

            Text(type == .noPermission
                 ? "We only ping your router to measure response time. We do not access any devices, store any data, or share anything. All measurements are wiped when you close the app."
                 : "We never store your network data or share it anywhere. Everything stays on your device and is cleared when you close the app.")
                .font(.system(size: 12))
                .foregroundColor(.scoreGood.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.scoreGood.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.scoreGood.opacity(0.20), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

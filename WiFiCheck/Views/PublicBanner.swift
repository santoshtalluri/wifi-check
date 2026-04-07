//
//  PublicBanner.swift
//  WiFi Check
//

import SwiftUI

/// Amber dismissible banner for public network detection
struct PublicBanner: View {
    @Binding var isDismissed: Bool

    var body: some View {
        if !isDismissed {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 16))
                    .foregroundColor(.publicNetwork)

                Text("Public network detected. Your traffic may be visible to others. We recommend using a VPN on public connections.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.publicNetwork)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button(action: { withAnimation { isDismissed = true } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.publicNetwork.opacity(0.6))
                }
                .accessibilityIdentifier("publicBannerDismiss")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.publicNetwork.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.publicNetwork.opacity(0.28), lineWidth: 1)
                    )
            )
        }
    }
}

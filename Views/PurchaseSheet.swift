//
//  PurchaseSheet.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Bottom sheet for Remove Ads IAP
struct PurchaseSheet: View {
    @ObservedObject var purchaseVM: PurchaseViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text("Remove Ads")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)

            Text("One-time purchase. No subscription. No hidden fees.")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)

            // Perks
            VStack(alignment: .leading, spacing: 12) {
                perkRow(icon: "xmark.circle", text: "No more ads ever")
                perkRow(icon: "sparkles", text: "Cleaner distraction-free UI")
                perkRow(icon: "heart", text: "Supports the developer")
                perkRow(icon: "arrow.clockwise.icloud", text: "Restored on all your devices")
            }
            .padding(.horizontal, 24)

            Spacer()

            if let error = purchaseVM.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.scorePoor)
            }

            // CTA
            Button(action: { Task { await purchaseVM.purchase() } }) {
                if purchaseVM.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Remove Ads — $1.99")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "0A84FF"), Color(hex: "5E5CE6")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .padding(.horizontal, 24)
            .disabled(purchaseVM.isPurchasing)

            Button("No thanks, keep ads") { dismiss() }
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func perkRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.scoreExcellent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
        }
    }
}

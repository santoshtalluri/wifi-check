//
//  SupportSheet.swift
//  WiFiQualityMonitor
//

import SwiftUI
import StoreKit

/// Support bottom sheet with 4 options
struct SupportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text("Support")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)

            VStack(spacing: 0) {
                supportRow(
                    icon: "ladybug",
                    title: "Report a Bug",
                    subtitle: "Something isn't working right",
                    action: { openMail(subject: "Bug Report") }
                )
                Divider().background(Color.white.opacity(0.06))

                supportRow(
                    icon: "lightbulb",
                    title: "Feature Request",
                    subtitle: "Share an idea you'd love to see",
                    action: { openMail(subject: "Feature Request") }
                )
                Divider().background(Color.white.opacity(0.06))

                supportRow(
                    icon: "questionmark.circle",
                    title: "General Question",
                    subtitle: "Ask us anything",
                    action: { openMail(subject: "Question") }
                )
                Divider().background(Color.white.opacity(0.06))

                supportRow(
                    icon: "star",
                    title: "Rate the App",
                    subtitle: "Leave a review on the App Store",
                    action: { requestReview() }
                )
            }
            .background(Color.white.opacity(0.04))
            .cornerRadius(14)
            .padding(.horizontal, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private func supportRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.scoreExcellent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func openMail(subject: String) {
        let email = "support@wifiquality.app" // TODO: Update with real email
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        if let url = URL(string: "mailto:\(email)?subject=WiFi%20Quality%20Monitor%20-%20\(encodedSubject)") {
            UIApplication.shared.open(url)
        }
    }
}

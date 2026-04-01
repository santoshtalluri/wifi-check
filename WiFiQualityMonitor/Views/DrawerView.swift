//
//  DrawerView.swift
//  WiFiQualityMonitor
//

import SwiftUI
import AuthenticationServices

/// Side drawer with user section, preferences, info/support
struct DrawerView: View {
    @ObservedObject var networkVM: NetworkViewModel
    @ObservedObject var purchaseVM: PurchaseViewModel
    @Binding var isOpen: Bool

    @State private var showSupport = false
    @State private var showPrivacy = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isOpen = false } }

            // Drawer panel
            VStack(alignment: .leading, spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { withAnimation { isOpen = false } }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // User section
                        userSection
                        sectionDivider

                        // Preferences
                        sectionLabel("PREFERENCES")
                        removeAdsRow
                        accentColorRow
                        sectionDivider

                        // Info & Support
                        sectionLabel("INFO & SUPPORT")
                        shareRow
                        privacyRow
                        termsRow
                        supportRow
                        sectionDivider

                        // Footer
                        appFooter
                    }
                }
            }
            .frame(width: 300)
            .background(Color.appBackground)
        }
        .sheet(isPresented: $showSupport) { SupportSheet() }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicySheet() }
        .sheet(isPresented: $purchaseVM.showPurchaseSheet) {
            PurchaseSheet(purchaseVM: purchaseVM)
        }
    }

    // MARK: - User Section

    private var userSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if UserDefaultsManager.appleUserID != nil {
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.scoreGood, .scoreExcellent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("U")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        )
                    VStack(alignment: .leading) {
                        Text("Signed In")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                }
            } else {
                Text("Sign in to sync your preferences across devices.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                SignInWithAppleButton { request in
                    request.requestedScopes = [.email]
                } onCompletion: { result in
                    if case .success(let auth) = result,
                       let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                        UserDefaultsManager.appleUserID = credential.user
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 44)
                .cornerRadius(10)
            }
        }
        .padding(16)
    }

    // MARK: - Remove Ads

    private var removeAdsRow: some View {
        Button(action: {
            if !purchaseVM.adsRemoved {
                purchaseVM.showPurchaseSheet = true
            }
        }) {
            drawerRow(
                title: "Remove Ads",
                subtitle: purchaseVM.adsRemoved
                    ? "Ads removed — thank you!"
                    : "Tap to unlock ad-free experience",
                trailing: {
                    AnyView(
                        Circle()
                            .fill(purchaseVM.adsRemoved ? networkVM.accentColor : Color.white.opacity(0.1))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: purchaseVM.adsRemoved ? "checkmark" : "")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    )
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Accent Color

    private var accentColorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent Color")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary)
            Text("Customize the app color")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)

            HStack(spacing: 10) {
                ForEach(Color.allAccents, id: \.hex) { accent in
                    Circle()
                        .fill(accent.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: networkVM.accentColorHex == accent.hex ? 2 : 0)
                        )
                        .onTapGesture {
                            networkVM.setAccentColor(accent.hex)
                        }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Info Rows

    private var shareRow: some View {
        Button(action: shareApp) {
            drawerRow(
                title: "Share the Love",
                subtitle: "Tell your friends about this app",
                trailing: { AnyView(chevron) }
            )
        }
        .buttonStyle(.plain)
    }

    private var privacyRow: some View {
        Button(action: { showPrivacy = true }) {
            drawerRow(
                title: "Privacy Policy",
                subtitle: nil,
                trailing: { AnyView(chevron) }
            )
        }
        .buttonStyle(.plain)
    }

    private var termsRow: some View {
        Button(action: { /* TODO: Terms sheet */ }) {
            drawerRow(
                title: "Terms of Service",
                subtitle: nil,
                trailing: { AnyView(chevron) }
            )
        }
        .buttonStyle(.plain)
    }

    private var supportRow: some View {
        Button(action: { showSupport = true }) {
            drawerRow(
                title: "Support",
                subtitle: "Bug . Feature request . Questions",
                trailing: { AnyView(chevron) }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var appFooter: some View {
        VStack(spacing: 4) {
            Text("WiFi Quality Monitor . v1.0.0 (1)")
                .font(.system(size: 11))
                .foregroundColor(.textTertiary)
            Text("Made with love for better home networks")
                .font(.system(size: 10))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(.textTertiary)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    private var sectionDivider: some View {
        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundColor(.textTertiary)
    }

    private func drawerRow(title: String, subtitle: String?, trailing: () -> AnyView) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func shareApp() {
        let text = "Check out WiFi Quality Monitor on the App Store — finally know if your WiFi is actually good!"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Privacy Policy Sheet

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                Text("Privacy Policy")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.textPrimary)

                // Green highlighted box
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Short Version")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.scoreGood)

                    Text("This app measures your WiFi performance entirely on your device. We capture nothing, store nothing, and share nothing. All data is wiped the moment you close the app.")
                        .font(.system(size: 13))
                        .foregroundColor(.scoreGood.opacity(0.9))
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

                // Additional sections placeholder
                Text("What We Collect")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("Local ping measurements processed on your device. Public IP fetched from ipify.org for display only. Apple ID if you sign in. AdMob identifier only with your tracking consent.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                Text("We Never Sell Your Data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("Your data never leaves your device. We have no servers, no databases, and no way to access your information even if we wanted to.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
    }
}

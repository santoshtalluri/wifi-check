//
//  SettingsView.swift
//  WiFi Check v1
//
//  Settings tab — replaces DrawerView with full-page settings

import SwiftUI

struct SettingsView: View {
    @ObservedObject var networkVM: NetworkViewModel

    @State private var showSupport = false
    @State private var showPrivacy = false
    @State private var showTerms = false

    @AppStorage("wqm-font-family")    private var fontFamily: String = "sfpro"
    @AppStorage("wqm-font-size")      private var fontSize: String   = "medium"
    @AppStorage("wqm-color-scheme")   private var colorSchemeRaw: String = "system"
    private var scale: CGFloat { AppFontSize(rawValue: fontSize)?.scale ?? 1.0 }

    @State private var fontFamilyExpanded = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Text("WiFi Check")
                        .font(.system(size: 26 * scale, weight: .bold))
                        .tracking(-0.6)
                        .foregroundColor(.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        // Preferences section
                        preferencesCard

                        // About section
                        aboutCard

                        // Footer
                        appFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
        }
        .sheet(isPresented: $showSupport) { SupportSheet() }
        .sheet(isPresented: $showPrivacy) { PrivacySummarySheet() }
        .sheet(isPresented: $showTerms) { TermsSummarySheet() }
    }

    // MARK: - Preferences Card

    private var preferencesCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17 * scale))
                        .foregroundColor(.textSecondary)
                    Text("Preferences")
                        .font(.system(size: 17 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.textSecondary.opacity(0.08))
                .padding(.horizontal, -16)
                .padding(.top, -16)

                Divider().background(Color.dividerColor)

                // Refresh Cycle
                refreshCycleSection

                Divider().background(Color.dividerColor)

                // Theme
                themeSection

                Divider().background(Color.dividerColor)

                // Accent Color
                accentColorSection

                Divider().background(Color.dividerColor)

                // Font Family
                fontFamilyRow

                Divider().background(Color.dividerColor)

                // Font Size
                fontSizeSection
            }
        }
    }

    // MARK: - Refresh Cycle

    private var refreshCycleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Refresh Cycle")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            Text("How often measurements update")
                .font(.system(size: 11 * scale))
                .foregroundColor(.textSecondary)

            HStack(spacing: 0) {
                refreshPill(label: "5s", value: 5)
                refreshPill(label: "15s", value: 15)
                refreshPill(label: "Manual", value: 0)
            }
            .background(Color.gaugeTrack)
            .cornerRadius(8)

            if networkVM.updateFrequency == 0 {
                Button(action: { networkVM.manualRefresh() }) {
                    Text("Refresh Now")
                        .font(.system(size: 13 * scale, weight: .semibold))
                        .foregroundColor(networkVM.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(networkVM.accentColor.opacity(0.15))
                        .cornerRadius(8)
                }
                .accessibilityIdentifier("refreshNowButton")
            }
        }
        .padding(.vertical, 12)
    }

    private func refreshPill(label: String, value: Int) -> some View {
        Button(action: { networkVM.setUpdateFrequency(value) }) {
            Text(label)
                .font(.system(size: 13 * scale,
                              weight: networkVM.updateFrequency == value ? .bold : .medium))
                .foregroundColor(networkVM.updateFrequency == value ? Color.primary : .textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    networkVM.updateFrequency == value
                        ? networkVM.accentColor.opacity(0.3) : Color.clear
                )
                .cornerRadius(8)
        }
        .accessibilityIdentifier("refreshPill_\(label.lowercased())")
    }

    // MARK: - Theme

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Theme")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
            }

            Text("Applies only to this app")
                .font(.system(size: 11 * scale))
                .foregroundColor(.textSecondary)

            HStack(spacing: 0) {
                themePill(label: "System", icon: "circle.lefthalf.filled", value: "system")
                themePill(label: "Light",  icon: "sun.max",               value: "light")
                themePill(label: "Dark",   icon: "moon",                  value: "dark")
            }
            .background(Color.gaugeTrack)
            .cornerRadius(8)
        }
        .padding(.vertical, 12)
    }

    private func themePill(label: String, icon: String, value: String) -> some View {
        Button(action: { colorSchemeRaw = value }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11 * scale,
                                  weight: colorSchemeRaw == value ? .bold : .medium))
                Text(label)
                    .font(.system(size: 13 * scale,
                                  weight: colorSchemeRaw == value ? .bold : .medium))
            }
            .foregroundColor(colorSchemeRaw == value ? Color.primary : .textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                colorSchemeRaw == value
                    ? networkVM.accentColor.opacity(0.3) : Color.clear
            )
            .cornerRadius(8)
        }
        .accessibilityIdentifier("themePill_\(value)")
    }

    // MARK: - Accent Color

    private var accentColorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent Color")
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 10) {
                ForEach(Color.allAccents, id: \.hex) { accent in
                    Circle()
                        .fill(accent.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(
                                    networkVM.accentColorHex == accent.hex
                                        ? (colorScheme == .dark ? Color.white : Color.black.opacity(0.6))
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .onTapGesture {
                            networkVM.setAccentColor(accent.hex)
                        }
                }
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Font Family

    private var fontFamilyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font Family")
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)

            // Trigger button — opens a bottom sheet so nothing in the scroll view shifts
            Button { fontFamilyExpanded = true } label: {
                HStack(spacing: 8) {
                    let current = AppFontFamily(rawValue: fontFamily) ?? .sfPro
                    Text(current.displayName)
                        .font(current.font(size: 13 * scale, weight: .medium))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.textSecondary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $fontFamilyExpanded) {
                FontFamilyPickerSheet(selection: $fontFamily, accentColorHex: networkVM.accentColorHex)
                    .presentationDetents([.height(CGFloat(AppFontFamily.allCases.count) * 54 + 60)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.appBackground)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Font Size

    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Font Size")
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 10) {
                ForEach(AppFontSize.allCases, id: \.rawValue) { sizeOption in
                    fontSizeTile(sizeOption)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private func fontSizeTile(_ sizeOption: AppFontSize) -> some View {
        let isSelected = fontSize == sizeOption.rawValue
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                fontSize = sizeOption.rawValue
            }
        } label: {
            VStack(spacing: 0) {
                Text("Aa")
                    .font(.system(size: sizeOption.sampleSize, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? Color.primary : .textPrimary)
                    .lineLimit(1)
                    .frame(height: sizeOption.tileHeight)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? networkVM.accentColor.opacity(0.14) : Color.clear)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? networkVM.accentColor : Color.glassBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - About Card

    private var aboutCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17 * scale))
                        .foregroundColor(.textSecondary)
                    Text("About")
                        .font(.system(size: 17 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.textSecondary.opacity(0.08))
                .padding(.horizontal, -16)
                .padding(.top, -16)

                Divider().background(Color.dividerColor)

                // Share
                Button(action: shareApp) {
                    settingsRow(
                        title: "Share with",
                        icon: "heart.fill",
                        iconColor: .red,
                        showChevron: true
                    )
                }
                .buttonStyle(PressableRowStyle())
                .accessibilityIdentifier("shareButton")

                Divider().background(Color.dividerColor)

                // Privacy Policy
                Button(action: { showPrivacy = true }) {
                    settingsRow(title: "Privacy Policy", showChevron: true)
                }
                .buttonStyle(PressableRowStyle())
                .accessibilityIdentifier("privacyPolicyButton")

                Divider().background(Color.dividerColor)

                // Terms of Use
                Button(action: { showTerms = true }) {
                    settingsRow(title: "Terms of Use", showChevron: true)
                }
                .buttonStyle(PressableRowStyle())
                .accessibilityIdentifier("termsOfUseButton")

                Divider().background(Color.dividerColor)

                // Support
                Button(action: { showSupport = true }) {
                    settingsRow(title: "Support", showChevron: true)
                }
                .buttonStyle(PressableRowStyle())
                .accessibilityIdentifier("supportButton")

                Divider().background(Color.dividerColor)

                // Rate on App Store
                Button(action: rateApp) {
                    settingsRow(title: "Rate on App Store", showChevron: true)
                }
                .buttonStyle(PressableRowStyle())
                .accessibilityIdentifier("rateAppButton")

                Divider().background(Color.dividerColor)

                // Version
                HStack {
                    Text("Version")
                        .font(.system(size: 13 * scale, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .font(.system(size: 13 * scale, weight: .light))
                        .foregroundColor(.textSecondary)
                }
                .padding(.vertical, 9)
            }
        }
    }

    private func settingsRow(title: String, icon: String? = nil, iconColor: Color = .textSecondary, showChevron: Bool = false) -> some View {
        HStack {
            if let icon = icon {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13 * scale, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Image(systemName: icon)
                        .font(.system(size: 13 * scale))
                        .foregroundColor(iconColor)
                }
            } else {
                Text(title)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.vertical, 9)
    }

    // MARK: - Footer

    private var appFooter: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("WiFi Check — Made with")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textTertiary)
                Image(systemName: "heart.fill")
                    .font(.system(size: 9 * scale))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func shareApp() {
        let text = "Check out WiFi Check on the App Store — finally know if your WiFi is actually good!"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func rateApp() {
        // TODO: Replace with actual App Store URL
        if let url = URL(string: "https://apps.apple.com/app/id6761551872") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Pressable Row Button Style

struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Privacy Summary Sheet

struct PrivacySummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showLeavingAlert = false
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.textTertiary)
                    .frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                Text("Privacy Policy")
                    .font(.system(size: 22 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)

                // Green summary box
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Short Version")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundColor(.scoreGood)

                    Text("WiFi Check does not collect, store, or transmit any personal data. All measurements happen on your device and are cleared when you close the app. We have no servers, no databases, and no way to access your information.")
                        .font(.system(size: 13 * scale))
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

                Text("What Stays on Your Device")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    bulletPoint("WiFi name, signal strength, and security type")
                    bulletPoint("Speed, latency, jitter, and packet loss measurements")
                    bulletPoint("Devices found on your local network")
                    bulletPoint("Your preferences (refresh interval, accent color)")
                }

                Text("What Leaves Your Device")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    bulletPoint("Public IP lookup via ipify.org (display only)")
                    bulletPoint("200KB download from Cloudflare (speed test)")
                    bulletPoint("TCP ping to Google DNS 8.8.8.8 (latency test)")
                }

                Text("None of this data is sent to us. We have no backend server.")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .italic()

                // Ad notice
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 13 * scale))
                            .foregroundColor(.scoreFair)
                        Text("A Note About Ads")
                            .font(.system(size: 13 * scale, weight: .semibold))
                            .foregroundColor(.scoreFair)
                    }
                    Text("WiFi Check is currently 100% ad-free — no banners, no pop-ups, and absolutely no targeted ads about WiFi routers mysteriously following you around the internet. We may introduce optional ads in a future version to keep the app free. If that day comes, we'll update this policy and quietly add a sad emoji to the changelog. 🫡")
                        .font(.system(size: 12 * scale))
                        .foregroundColor(.scoreFair.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.scoreFair.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.scoreFair.opacity(0.20), lineWidth: 1)
                        )
                )

                // Read full policy link
                Button(action: { showLeavingAlert = true }) {
                    HStack(spacing: 6) {
                        Text("Read Full Privacy Policy")
                            .font(.system(size: 14 * scale, weight: .semibold))
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12 * scale))
                    }
                    .foregroundColor(.scoreExcellent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.scoreExcellent.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.top, 4)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
        .alert("You're leaving WiFi Check", isPresented: $showLeavingAlert) {
            Button("Open in Browser") {
                if let url = URL(string: "https://www.wifi-check.app/privacy.html") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will open the full privacy policy in your browser.")
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.textTertiary)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13 * scale))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Terms Summary Sheet

struct TermsSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showLeavingAlert = false
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.textTertiary)
                    .frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                Text("Terms of Service")
                    .font(.system(size: 22 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)

                // Blue summary box
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Short Version")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .foregroundColor(.scoreExcellent)

                    Text("WiFi Check is provided as-is. Measurements are estimates, not guarantees. Only scan networks you own or have permission to scan. We are not liable for decisions made based on the app's readings.")
                        .font(.system(size: 13 * scale))
                        .foregroundColor(.scoreExcellent.opacity(0.9))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.scoreExcellent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.scoreExcellent.opacity(0.20), lineWidth: 1)
                        )
                )

                Text("Key Points")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)

                VStack(alignment: .leading, spacing: 6) {
                    bulletPoint("Scores and metrics are estimates, not guarantees of network quality")
                    bulletPoint("Only scan networks you own or are authorized to scan")
                    bulletPoint("The app relies on third-party services (Cloudflare, Google DNS, ipify) that may change")
                    bulletPoint("Governed by the laws of the State of California")
                }

                // Ad notice
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 13 * scale))
                            .foregroundColor(.scoreFair)
                        Text("A Note About Ads")
                            .font(.system(size: 13 * scale, weight: .semibold))
                            .foregroundColor(.scoreFair)
                    }
                    Text("WiFi Check does not currently display ads. You are welcome. We may add them someday — probably right around the time the cloud bill arrives and we stare at it in silence. When we do, ads will be disclosed, App Store–compliant, and hopefully less annoying than a 2 Mbps connection on a Monday morning. We'll give you fair warning. Pinky promise. 🤙")
                        .font(.system(size: 12 * scale))
                        .foregroundColor(.scoreFair.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.scoreFair.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.scoreFair.opacity(0.20), lineWidth: 1)
                        )
                )

                // Read full terms link
                Button(action: { showLeavingAlert = true }) {
                    HStack(spacing: 6) {
                        Text("Read Full Terms of Service")
                            .font(.system(size: 14 * scale, weight: .semibold))
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12 * scale))
                    }
                    .foregroundColor(.scoreExcellent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.scoreExcellent.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.top, 4)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
        .alert("You're leaving WiFi Check", isPresented: $showLeavingAlert) {
            Button("Open in Browser") {
                if let url = URL(string: "https://www.wifi-check.app/terms.html") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will open the full terms of service in your browser.")
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.textTertiary)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13 * scale))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Font Family Picker Sheet

/// Compact bottom sheet presenting font family options — floats over content,
/// no layout shift in the parent scroll view.
struct FontFamilyPickerSheet: View {
    @Binding var selection: String
    let accentColorHex: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(AppFontFamily.allCases, id: \.rawValue) { family in
                Button {
                    selection = family.rawValue
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(family.displayName)
                            .font(family.font(size: 16 * scale, weight: .medium))
                            .foregroundColor(
                                selection == family.rawValue
                                    ? Color(hex: accentColorHex) : .textPrimary
                            )
                        Spacer()
                        if selection == family.rawValue {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13 * scale, weight: .semibold))
                                .foregroundColor(Color(hex: accentColorHex))
                        }
                    }
                    .padding(.vertical, 15)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if family.rawValue != AppFontFamily.allCases.last?.rawValue {
                    Divider()
                        .background(Color.dividerColor)
                        .padding(.horizontal, 20)
                }
            }

            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - AppFontFamily

/// Available font families for the app.
/// To add a custom font: drop the .ttf/.otf file into the project, register it in
/// Info.plist under "Fonts provided by application", then add a new case below.
enum AppFontFamily: String, CaseIterable {
    case sfPro      = "sfpro"
    case rounded    = "rounded"
    case newYork    = "newyork"
    case monospaced = "mono"
    // Example custom font (uncomment after adding the file to the project):
    // case interFont = "Inter-Regular"

    var displayName: String {
        switch self {
        case .sfPro:      return "SF Pro (Default)"
        case .rounded:    return "SF Rounded"
        case .newYork:    return "New York"
        case .monospaced: return "SF Mono"
        }
    }

    /// The SwiftUI Font.Design that corresponds to this family.
    /// Used with `.fontDesign(family.fontDesign)` at the root to
    /// propagate the choice to every Font.system(size:weight:) call in the app.
    var fontDesign: Font.Design {
        switch self {
        case .sfPro:      return .default
        case .rounded:    return .rounded
        case .newYork:    return .serif
        case .monospaced: return .monospaced
        }
    }

    /// Returns a SwiftUI Font at the given size and weight rendered in this design.
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .sfPro:      return .system(size: size, weight: weight)
        case .rounded:    return .system(size: size, weight: weight, design: .rounded)
        case .newYork:    return .system(size: size, weight: weight, design: .serif)
        case .monospaced: return .system(size: size, weight: weight, design: .monospaced)
        // Custom font example:
        // case .interFont: return .custom("Inter-Regular", size: size)
        }
    }
}

// MARK: - AppFontSize

enum AppFontSize: String, CaseIterable {
    case short  = "short"
    case medium = "medium"
    case large  = "large"

    var label: String {
        switch self {
        case .short:  return "Short"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }

    /// Size of the "Sample" preview text inside each tile.
    var sampleSize: CGFloat {
        switch self {
        case .short:  return 11
        case .medium: return 14
        case .large:  return 19
        }
    }

    /// Fixed height for the "Aa" text frame so all tiles are the same height.
    var tileHeight: CGFloat { 20 }

    /// Scale multiplier applied to all explicit Font.system(size:) calls app-wide.
    var scale: CGFloat {
        switch self {
        case .short:  return 0.88
        case .medium: return 1.0
        case .large:  return 1.15
        }
    }
}

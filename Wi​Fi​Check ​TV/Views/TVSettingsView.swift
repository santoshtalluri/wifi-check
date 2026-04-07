//
//  TVSettingsView.swift
//  WiFi Check TV
//

import SwiftUI

struct TVSettingsView: View {
    @ObservedObject var networkVM: NetworkViewModel

    @AppStorage("wqm-color-scheme") private var colorSchemeRaw: String = "system"

    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse    = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                HStack(alignment: .top, spacing: 32) {

                    // ── Preferences ──────────────────────────────────────
                    TVGlassCard {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Preferences")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.textPrimary)

                            Divider().background(Color.dividerColor)

                            // Refresh Cycle
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Refresh Cycle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textSecondary)

                                HStack(spacing: 12) {
                                    frequencyButton(label: "5s",     value: 5)
                                    frequencyButton(label: "15s",    value: 15)
                                    frequencyButton(label: "Manual", value: 0)
                                }
                            }

                            Divider().background(Color.dividerColor)

                            // Theme
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Theme")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textSecondary)

                                HStack(spacing: 12) {
                                    themeButton(label: "System", icon: "circle.lefthalf.filled", value: "system")
                                    themeButton(label: "Light",  icon: "sun.max",               value: "light")
                                    themeButton(label: "Dark",   icon: "moon",                  value: "dark")
                                }
                            }

                            Divider().background(Color.dividerColor)

                            // Accent Color
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Accent Color")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.textSecondary)

                                HStack(spacing: 20) {
                                    ForEach(Color.allAccents, id: \.hex) { accent in
                                        Button {
                                            networkVM.setAccentColor(accent.hex)
                                        } label: {
                                            Circle()
                                                .fill(accent.color)
                                                .frame(width: 44, height: 44)
                                        }
                                        .buttonStyle(TVColorCircleStyle(
                                            isSelected: networkVM.accentColorHex == accent.hex,
                                            circleColor: accent.color
                                        ))
                                    }
                                }
                                .padding(.vertical, 8) // breathing room for the glow/ring
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)

                    // ── About ─────────────────────────────────────────────
                    TVGlassCard {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("About")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .padding(.bottom, 16)

                            Divider().background(Color.dividerColor)

                            aboutStaticRow(label: "Version", value: "1.0.0")
                            Divider().background(Color.dividerColor)

                            aboutActionRow(label: "Privacy Policy", identifier: "tvPrivacyPolicyButton") { showPrivacyPolicy = true }
                            Divider().background(Color.dividerColor)

                            aboutActionRow(label: "Terms of Use", identifier: "tvTermsButton") { showTermsOfUse = true }
                            Divider().background(Color.dividerColor)

                            aboutStaticRow(label: "Support", value: "contact@wifi-check.app")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("Made with ❤️ by Santosh T")
                    .font(.system(size: 14))
                    .foregroundColor(.textTertiary)
            }
            .padding(48)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            LegalSheetView(title: "Privacy Policy", content: privacyPolicyText,
                           accentColor: networkVM.accentColor)
        }
        .sheet(isPresented: $showTermsOfUse) {
            LegalSheetView(title: "Terms of Use", content: termsOfUseText,
                           accentColor: networkVM.accentColor)
        }
    }

    // MARK: - Frequency selector button

    @ViewBuilder
    private func frequencyButton(label: String, value: Int) -> some View {
        let selected = networkVM.updateFrequency == value
        Button {
            networkVM.setUpdateFrequency(value)
        } label: {
            Text(label)
                .font(.system(size: 16, weight: selected ? .bold : .medium))
                .foregroundColor(selected ? Color.primary : .textSecondary)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
        }
        .buttonStyle(TVSegmentButtonStyle(isSelected: selected,
                                         accentColor: networkVM.accentColor))
        .accessibilityIdentifier("tvRefreshPill_\(label.lowercased())")
    }

    @ViewBuilder
    private func themeButton(label: String, icon: String, value: String) -> some View {
        let selected = colorSchemeRaw == value
        Button {
            colorSchemeRaw = value
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: selected ? .bold : .medium))
                Text(label)
                    .font(.system(size: 16, weight: selected ? .bold : .medium))
            }
            .foregroundColor(selected ? Color.primary : .textSecondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
        }
        .buttonStyle(TVSegmentButtonStyle(isSelected: selected,
                                         accentColor: networkVM.accentColor))
        .accessibilityIdentifier("tvThemePill_\(value)")
    }

    // MARK: - About rows

    @ViewBuilder
    private func aboutStaticRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.textTertiary)
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func aboutActionRow(label: String, identifier: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(TVRowActionStyle(accentColor: networkVM.accentColor))
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Legal Sheet

struct LegalSheetView: View {
    let title: String
    let content: String
    let accentColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Text(title)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                        .controlSize(.large)
                }
                .padding(.bottom, 20)

                Divider().background(Color.dividerColor)

                ScrollView {
                    Text(content)
                        .font(.system(size: 18))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 24)
                }
            }
            .padding(60)
        }
    }
}

// MARK: - Legal Content

private let privacyPolicyText = """
Last updated: April 2026

WiFi Check does not collect, store, or transmit any personal data.

All network measurements (latency, packet loss, throughput, DNS speed, jitter) are performed entirely on your device and local network. No data is sent to external servers except for standard speed test requests to publicly available CDN endpoints (Cloudflare, Fast.com, Ookla).

No account registration is required. No analytics or crash reporting SDKs are included. No advertising identifiers are used.

Network scan results (IP addresses, device hostnames) are stored only in memory and cleared when the app is closed. They are never persisted to disk or transmitted off-device.

─── A Note About Ads ───────────────────────────────

WiFi Check is currently 100% ad-free — no banners, no pop-ups, and absolutely no targeted ads about WiFi routers mysteriously following you around the internet. We may introduce optional ads in a future version to keep the app free. If that day comes, we'll update this policy and quietly add a sad emoji to the changelog. 🫡

────────────────────────────────────────────────────

For questions, contact: contact@wifi-check.app
"""

private let termsOfUseText = """
Last updated: April 2026

By using WiFi Check, you agree to the following terms:

1. WiFi Check is provided "as is" without warranty of any kind.

2. Network quality scores and measurements are estimates based on real-time conditions and should not be used as the sole basis for technical or purchasing decisions.

3. The network scan feature uses standard ARP and ping techniques to discover devices on your local network. Only use this feature on networks you own or have explicit permission to scan.

4. Speed test results may vary based on server load, network congestion, and other factors outside the app's control.

5. WiFi Check is not responsible for any network configuration changes, service interruptions, or other outcomes resulting from use of this app.

─── A Note About Ads ───────────────────────────────

WiFi Check does not currently display ads. You are welcome. We may add them someday — probably right around the time the cloud bill arrives and we stare at it in silence. When we do, ads will be disclosed, App Store–compliant, and hopefully less annoying than a 2 Mbps connection on a Monday morning. We'll give you fair warning. Pinky promise. 🤙

────────────────────────────────────────────────────

For support, contact: contact@wifi-check.app
"""

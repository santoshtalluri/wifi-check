//
//  TVDeviceDetailView.swift
//  WiFi Check TV
//

import SwiftUI

struct TVDeviceDetailView: View {
    let device: NetworkDevice
    @Binding var isPresented: Bool

    private var fingerprint: FingerprintResult {
        DeviceFingerprintService.shared.fingerprint(
            hostname: device.hostname,
            mDNSServices: device.mDNSServices
        )
    }

    private var displayName: String {
        device.hostname.isEmpty ? "Unknown Device" : device.hostname
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.scoreGood.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: fingerprint.deviceType.sfSymbol)
                            .font(.system(size: 48))
                            .foregroundColor(.scoreGood)
                    }
                    Text(displayName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    HStack(spacing: 12) {
                        if let mfr = fingerprint.manufacturer {
                            Text(mfr)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.textSecondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Text(fingerprint.deviceType.displayName)
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                        if device.isOnline {
                            Text("Online")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.scoreGood)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.scoreGood.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Info card
                TVGlassCard {
                    VStack(spacing: 0) {
                        infoRow(label: "IP Address", value: device.ip.isEmpty ? "—" : device.ip)
                        Divider().background(Color.dividerColor)
                        infoRow(label: "Hostname", value: device.hostname.isEmpty ? "—" : device.hostname)
                        Divider().background(Color.dividerColor)
                        infoRow(label: "Manufacturer", value: fingerprint.manufacturer ?? "Unknown")
                        Divider().background(Color.dividerColor)
                        infoRow(label: "Device Type", value: fingerprint.deviceType.displayName)
                    }
                }
                .frame(maxWidth: 600)

                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .tint(.scoreGood)
                    .controlSize(.large)
            }
            .padding(60)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 18))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
    }
}

// DeviceDetailView.swift (iOS)
import SwiftUI
import SwiftData

struct DeviceDetailView: View {
    let device: NetworkDevice

    @Environment(\.modelContext) private var modelContext
    @State private var savedDevice: SavedDevice?
    @State private var isEditingName = false
    @State private var nameInput = ""

    private var fingerprint: FingerprintResult { device.fingerprint }

    private var displayName: String {
        if let label = savedDevice?.userLabel, !label.isEmpty { return label }
        return device.hostname.isEmpty ? "Unknown Device" : device.hostname
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    deviceHeaderCard
                    deviceInfoCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadOrCreate() }
        .accessibilityIdentifier("deviceDetailView")
    }

    // MARK: Header card
    private var deviceHeaderCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.scoreGood.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: fingerprint.deviceType.sfSymbol)
                        .font(.system(size: 32))
                        .foregroundColor(.scoreGood)
                }

                if isEditingName {
                    HStack(spacing: 8) {
                        TextField("Device name", text: $nameInput)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("deviceNameField")
                        Button(action: saveName) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.scoreGood)
                        }
                        .accessibilityIdentifier("saveNameButton")
                        Button(action: cancelEdit) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.textSecondary)
                        }
                        .accessibilityIdentifier("cancelEditButton")
                    }
                    .padding(.horizontal, 4)
                } else {
                    Button(action: startEdit) {
                        HStack(spacing: 6) {
                            Text(displayName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.textPrimary)
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundColor(.textSecondary.opacity(0.7))
                        }
                    }
                    .accessibilityIdentifier("deviceNameButton")
                }

                if savedDevice?.isUserLabeled == true {
                    Text("You named this")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.scoreGood)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.scoreGood.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityIdentifier("userLabeledBadge")
                }

                HStack(spacing: 8) {
                    if let mfr = fingerprint.manufacturer {
                        Text(mfr)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.textSecondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Text(fingerprint.deviceType.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)

                    if device.isOnline {
                        Text("Online")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.scoreGood)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.scoreGood.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Info card
    private var deviceInfoCard: some View {
        GlassCard {
            VStack(spacing: 0) {
                infoRow(label: "IP Address", value: device.ip.isEmpty ? "—" : device.ip)
                rowDivider
                infoRow(label: "Hostname", value: device.hostname.isEmpty ? "—" : device.hostname)
                rowDivider
                infoRow(label: "Manufacturer", value: fingerprint.manufacturer ?? "Unknown")
                rowDivider
                infoRow(label: "Device Type", value: fingerprint.deviceType.displayName)
            }
        }
    }

    private var rowDivider: some View {
        Divider().background(Color.dividerColor)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
    }

    // MARK: Actions
    private func loadOrCreate() {
        let h = device.hostname
        let descriptor = FetchDescriptor<SavedDevice>(
            predicate: #Predicate<SavedDevice> { d in d.hostname == h }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            savedDevice = existing
            existing.lastSeen = Date()
            existing.lastKnownIP = device.ip
        } else {
            let fp = fingerprint
            let new = SavedDevice(
                hostname: h.isEmpty ? nil : h,
                ip: device.ip,
                type: fp.deviceType,
                manufacturer: fp.manufacturer
            )
            modelContext.insert(new)
            savedDevice = new
        }
        try? modelContext.save()
    }

    private func startEdit() {
        nameInput = savedDevice?.userLabel ?? (device.hostname.isEmpty ? "" : device.hostname)
        isEditingName = true
    }

    private func saveName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        savedDevice?.userLabel = trimmed.isEmpty ? nil : trimmed
        try? modelContext.save()
        isEditingName = false
    }

    private func cancelEdit() {
        isEditingName = false
    }
}

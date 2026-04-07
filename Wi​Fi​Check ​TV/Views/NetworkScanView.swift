//
//  NetworkScanView.swift
//  WiFi Check TV
//

import SwiftUI

struct NetworkScanView: View {
    @ObservedObject var networkVM: NetworkViewModel
    @StateObject private var scanService = NetworkScanService()
    @State private var selectedDevice: NetworkDevice?

    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 20)]

    private struct DeviceGroup: Identifiable {
        let id: String
        let devices: [NetworkDevice]
    }

    private var groupedDevices: [DeviceGroup] {
        var map: [String: [NetworkDevice]] = [:]
        for d in scanService.devices {
            let fp = DeviceFingerprintService.shared.fingerprint(hostname: d.hostname, mDNSServices: d.mDNSServices)
            map[fp.deviceType.groupName, default: []].append(d)
        }
        let order = ["Phones & Tablets", "Computers", "TVs & Speakers", "Network", "Printers", "Smart Home", "Unknown"]
        return map.map { DeviceGroup(id: $0.key, devices: $0.value) }
            .sorted { a, b in
                let ai = order.firstIndex(of: a.id) ?? 99
                let bi = order.firstIndex(of: b.id) ?? 99
                return ai < bi
            }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            TVGlassCard {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 22)).foregroundColor(.textSecondary)
                        Text("Network Scan").font(.system(size: 24, weight: .semibold)).foregroundColor(.textPrimary)
                        Spacer()
                        Text("\(scanService.devices.count) devices found").font(.system(size: 16, weight: .medium)).foregroundColor(.textTertiary)
                        Button(action: { startScan() }) {
                            HStack(spacing: 8) {
                                if scanService.isScanning { ProgressView().tint(.white).scaleEffect(0.85) }
                                Text(scanService.isScanning ? "Scanning…" : "Scan Network").font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent).tint(.scoreGood).controlSize(.large).disabled(scanService.isScanning)
                        .accessibilityIdentifier("tvScanNetworkButton")
                    }

                    Divider().background(Color.dividerColor)

                    if scanService.devices.isEmpty {
                        HStack {
                            Spacer()
                            if scanService.isScanning {
                                VStack(spacing: 12) {
                                    ProgressView().tint(.blue)
                                    Text("Scanning network…").font(.system(size: 16)).foregroundColor(.textTertiary)
                                }
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 36)).foregroundColor(.textTertiary)
                                    Text("Press Scan Network to discover devices").font(.system(size: 16)).foregroundColor(.textTertiary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(groupedDevices) { group in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack(spacing: 6) {
                                            Text(group.id).font(.system(size: 14, weight: .semibold)).foregroundColor(.textSecondary).textCase(.uppercase)
                                            Text("(\(group.devices.count))").font(.system(size: 13)).foregroundColor(.textSecondary.opacity(0.7))
                                            Spacer()
                                        }
                                        LazyVGrid(columns: columns, spacing: 16) {
                                            ForEach(group.devices) { device in
                                                Button(action: { selectedDevice = device }) {
                                                    deviceCard(device: device)
                                                }
                                                .buttonStyle(.card)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(48)
        }
        .fullScreenCover(item: $selectedDevice) { device in
            TVDeviceDetailView(device: device, isPresented: Binding(
                get: { selectedDevice != nil },
                set: { if !$0 { selectedDevice = nil } }
            ))
        }
    }

    @ViewBuilder
    private func deviceCard(device: NetworkDevice) -> some View {
        let fp = DeviceFingerprintService.shared.fingerprint(hostname: device.hostname, mDNSServices: device.mDNSServices)
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(iconBackgroundColor(for: device.hostname)).frame(width: 44, height: 44)
                Image(systemName: fp.deviceType.sfSymbol).font(.system(size: 20)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(deviceDisplayName(device.hostname)).font(.system(size: 16, weight: .bold)).foregroundColor(.textPrimary).lineLimit(1)
                if isRawMACHostname(device.hostname) {
                    Text(device.ip).font(.system(size: 13)).foregroundColor(.textTertiary)
                } else if let mfr = fp.manufacturer {
                    Text(mfr).font(.system(size: 12)).foregroundColor(.textTertiary)
                } else {
                    Text(device.ip).font(.system(size: 13)).foregroundColor(.textTertiary)
                }
            }
            Spacer()
            if device.isOnline { Text("Online").font(.system(size: 13, weight: .medium)).foregroundColor(.scoreGood) }
        }
        .padding(14)
    }

    private func isRawMACHostname(_ hostname: String) -> Bool {
        guard !hostname.isEmpty else { return false }
        let stripped = hostname.lowercased()
            .replacingOccurrences(of: "unknown", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "_", with: "")
        let hexOnly = stripped.unicodeScalars.allSatisfy {
            ($0.value >= 0x30 && $0.value <= 0x39) || ($0.value >= 0x61 && $0.value <= 0x66)
        }
        return hexOnly && stripped.count == 12
    }

    private func deviceDisplayName(_ hostname: String) -> String {
        if hostname.isEmpty || isRawMACHostname(hostname) { return "Unknown Device" }
        return hostname
    }

    private func iconBackgroundColor(for hostname: String) -> Color {
        let h = hostname.lowercased()
        if h.contains("iphone") || h.contains("ipad") || h.contains("ipod") { return Color(hex: "30D158") }
        if h.contains("macbook") || h.contains("laptop") || h.contains("imac") || h.contains("mac") { return Color(hex: "0A84FF") }
        if h.contains("apple tv") || h.contains("appletv") { return Color(hex: "BF5AF2") }
        if h.contains("printer") || h.contains("hp") || h.contains("canon") || h.contains("epson") { return Color(hex: "FF9F0A") }
        if h.contains("playstation") || h.contains("xbox") || h.contains("nintendo") { return Color(hex: "FF453A") }
        if h.contains("homepod") || h.contains("speaker") || h.contains("sonos") { return Color(hex: "30D158") }
        return Color(hex: "0A84FF")
    }

    private func startScan() {
        let gateway = networkVM.wifiInfo.gatewayIP
        let localIP = networkVM.wifiInfo.localIP
        guard gateway != "--" else { return }
        scanService.startScan(localIP: localIP, gatewayIP: gateway)
    }
}

//
//  NetworkScanTab.swift
//  WiFi Check v1
//

import SwiftUI

struct NetworkScanTab: View {
    @ObservedObject var networkVM: NetworkViewModel
    @StateObject private var scanService = NetworkScanService()

    @State private var searchText = ""
    /// Persistent view mode — false = list (default), true = grouped
    @AppStorage("networkScanIsGrouped") private var isGrouped = false
    /// Groups that the user has manually collapsed; reset on each new scan
    @State private var collapsedGroups: Set<String> = []
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    // MARK: - Derived data

    private var filteredDevices: [NetworkDevice] {
        if searchText.isEmpty { return scanService.devices }
        let query = searchText.lowercased()
        return scanService.devices.filter {
            $0.hostname.lowercased().contains(query) || $0.ip.contains(query)
        }
    }

    private var thisDevice: NetworkDevice? {
        filteredDevices.first { $0.isThisDevice }
    }

    private var otherDevices: [NetworkDevice] {
        filteredDevices.filter { !$0.isThisDevice }
    }

    // MARK: - Grouping

    private struct DeviceGroup: Identifiable {
        let id: String    // groupName
        let devices: [NetworkDevice]
    }

    private var groupedDevices: [DeviceGroup] {
        var map: [String: [NetworkDevice]] = [:]
        for d in otherDevices {
            let groupName: String
            if d.isGateway {
                groupName = "Routers"
            } else {
                let fp = d.fingerprint
                groupName = fp.deviceType.groupName == "Network" ? "Routers" : fp.deviceType.groupName
            }
            map[groupName, default: []].append(d)
        }
        let order: [String] = ["Routers", "Phones & Tablets", "Computers",
                                "TVs & Speakers", "Printers", "Smart Home", "Unknown"]
        return map.map { DeviceGroup(id: $0.key, devices: $0.value) }
            .sorted { a, b in
                let ai = order.firstIndex(of: a.id) ?? 99
                let bi = order.firstIndex(of: b.id) ?? 99
                return ai < bi
            }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Circle()
                    .fill(Color.scoreGood)
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .opacity(colorScheme == .dark ? 0.12 : 0.05)
                    .offset(x: 80, y: -150)
                    .ignoresSafeArea()

                if !networkVM.isConnectedToWiFi {
                    BlockedView(type: .noWiFi)
                } else {
                    scanContent
                }
            }
            .navigationDestination(for: NetworkDevice.self) { device in
                DeviceDetailView(device: device)
            }
        }
    }

    // MARK: - Scan content

    private var scanContent: some View {
        VStack(spacing: 0) {
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
                    GlassCard {
                        VStack(spacing: 0) {
                            // Header row with optional view-mode toggle
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Network Scan")
                                        .font(.system(size: 18 * scale, weight: .semibold))
                                        .foregroundColor(.textPrimary)
                                    Text("Discover devices on your local network")
                                        .font(.system(size: 12 * scale))
                                        .foregroundColor(.textSecondary)
                                }
                                Spacer()
                                if !scanService.devices.isEmpty && !scanService.isScanning {
                                    viewModeToggle
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .background(Color.textSecondary.opacity(0.08))
                            .padding(.horizontal, -16)
                            .padding(.top, -16)

                            Divider().background(Color.dividerColor)

                            VStack(spacing: 12) {
                            // Scan button
                            Button(action: startScan) {
                                HStack {
                                    if scanService.isScanning {
                                        ProgressView()
                                            .tint(.scoreGood)
                                            .scaleEffect(0.8)
                                        VStack(spacing: 2) {
                                            Text("\(scanService.discoveredCount) IPs found, \(scanService.devices.count) resolved")
                                                .font(.system(size: 14 * scale, weight: .semibold))
                                                .foregroundColor(.scoreGood)
                                            if !scanService.scanPhase.isEmpty {
                                                Text(scanService.scanPhase)
                                                    .font(.system(size: 11 * scale))
                                                    .foregroundColor(.textSecondary)
                                            }
                                        }
                                    } else {
                                        Text(scanService.devices.isEmpty ? "Scan Network" : "Scan Again")
                                            .font(.system(size: 16 * scale, weight: .semibold))
                                            .foregroundColor(.scoreGood)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.scoreGood.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(scanService.isScanning)
                            .accessibilityIdentifier("scanNetworkButton")

                            // Results area
                            if !scanService.devices.isEmpty {
                                searchBar

                                HStack {
                                    Text("\(filteredDevices.count) device\(filteredDevices.count == 1 ? "" : "s")")
                                        .font(.system(size: 12 * scale))
                                        .foregroundColor(.textSecondary)
                                    if !searchText.isEmpty {
                                        Text("(of \(scanService.devices.count))")
                                            .font(.system(size: 11 * scale))
                                            .foregroundColor(.textSecondary.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.top, 2)

                                // "You" device — always pinned at top in both modes
                                if let me = thisDevice {
                                    youDeviceRow(me)
                                }

                                // List or grouped display.
                                // During scanning, always show the flat list — devices stream in
                                // and hostnames resolve progressively, so grouping mid-scan causes
                                // devices to jump between groups. Switch to grouped view only once
                                // the scan completes and all names are stable.
                                if isGrouped && !scanService.isScanning {
                                    groupedContent
                                } else {
                                    listContent
                                }
                            }
                            } // inner VStack
                            .padding(.top, 12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - View mode toggle

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isGrouped = false }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(isGrouped ? .textSecondary : .scoreGood)
                    .frame(width: 30, height: 26)
                    .background(isGrouped ? Color.clear : Color.scoreGood.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isGrouped = true }
            } label: {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(isGrouped ? .scoreGood : .textSecondary)
                    .frame(width: 30, height: 26)
                    .background(isGrouped ? Color.scoreGood.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(3)
        .background(Color.textSecondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13 * scale))
                .foregroundColor(.textSecondary)
            TextField("Search by name or IP", text: $searchText)
                .font(.system(size: 13 * scale))
                .foregroundColor(.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("deviceSearchField")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13 * scale))
                        .foregroundColor(.textSecondary)
                }
                .accessibilityIdentifier("clearSearchButton")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.textSecondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - List content (flat, no groups)

    private var listContent: some View {
        VStack(spacing: 0) {
            ForEach(otherDevices) { device in
                NavigationLink(value: device) {
                    deviceRow(device)
                }
                .buttonStyle(.plain)
                if device.id != otherDevices.last?.id {
                    Divider().background(Color.dividerColor)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: scanService.devices)
    }

    // MARK: - Grouped content

    private var groupedContent: some View {
        VStack(spacing: 8) {
            ForEach(groupedDevices) { group in
                groupContainer(group)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: scanService.devices)
    }

    private func groupContainer(_ group: DeviceGroup) -> some View {
        let isCollapsed = collapsedGroups.contains(group.id)
        return VStack(spacing: 0) {
            // Tappable section header
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if isCollapsed {
                        collapsedGroups.remove(group.id)
                    } else {
                        collapsedGroups.insert(group.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(group.id.uppercased())
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundColor(.textSecondary)
                    Text("(\(group.devices.count))")
                        .font(.system(size: 11 * scale))
                        .foregroundColor(.textSecondary.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10 * scale, weight: .semibold))
                        .foregroundColor(.textSecondary.opacity(0.5))
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        .animation(.easeInOut(duration: 0.22), value: isCollapsed)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            // Device rows (hidden when collapsed)
            if !isCollapsed {
                Divider()
                    .background(Color.dividerColor.opacity(0.5))
                    .padding(.horizontal, 8)

                VStack(spacing: 0) {
                    ForEach(group.devices) { device in
                        NavigationLink(value: device) {
                            deviceRow(device)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if device.id != group.devices.last?.id {
                            Divider()
                                .background(Color.dividerColor)
                                .padding(.leading, 46) // align with device name
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(isCollapsed ? 0.06 : 0.035)
                        : Color.black.opacity(isCollapsed ? 0.06 : 0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCollapsed
                        ? Color.textSecondary.opacity(0.2)
                        : Color.textSecondary.opacity(0.08),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - "You" row

    @ViewBuilder
    private func youDeviceRow(_ device: NetworkDevice) -> some View {
        NavigationLink(value: device) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.scoreGood.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "iphone")
                        .font(.system(size: 17 * scale))
                        .foregroundColor(.scoreGood)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(device.hostname.isEmpty ? "This Device" : device.hostname)
                            .font(.system(size: 13 * scale, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        Text("you")
                            .font(.system(size: 9 * scale, weight: .bold))
                            .foregroundColor(.scoreGood)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.scoreGood.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text(device.ip)
                        .font(.system(size: 11 * scale))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textSecondary.opacity(0.4))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        Divider().background(Color.dividerColor)
    }

    // MARK: - Device row

    private func deviceRow(_ device: NetworkDevice) -> some View {
        let fp = device.fingerprint
        let roleLabel: String? = device.isGateway ? "Router" : (fp.deviceType == .router ? "Mesh Node" : nil)
        return HStack(spacing: 10) {
            Image(systemName: fp.deviceType.sfSymbol)
                .font(.system(size: 18 * scale))
                .foregroundColor(.textSecondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.hostname.isEmpty ? "Unknown Device" : device.hostname)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Text(device.ip)
                    .font(.system(size: 11 * scale))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if let role = roleLabel {
                    Text(role)
                        .font(.system(size: 9 * scale, weight: .semibold))
                        .foregroundColor(.scoreFair)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.scoreFair.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else if let mfr = fp.manufacturer {
                    Text(mfr)
                        .font(.system(size: 9 * scale, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.textSecondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("Online")
                    .font(.system(size: 10 * scale, weight: .semibold))
                    .foregroundColor(.scoreGood)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.scoreGood.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11 * scale))
                .foregroundColor(.textSecondary.opacity(0.4))
        }
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func startScan() {
        searchText = ""
        collapsedGroups = []
        scanService.startScan(
            localIP: networkVM.wifiInfo.localIP,
            gatewayIP: networkVM.wifiInfo.gatewayIP
        )
    }
}

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    /// SSID of the last network the user explicitly authorized for scanning.
    /// Empty string means no consent has been given on the current network.
    @AppStorage("scan-consented-ssid") private var consentedSSID: String = ""
    @State private var showConsentSheet: Bool = false

    // MARK: - Authorization state

    private enum ScanAuthState {
        /// Public or unauthenticated network — scanning is always disabled
        case publicNetworkBlocked
        /// SSID unavailable (Location permission likely denied) — cannot gate per-network
        case ssidUnknown
        /// Different SSID from last consent, or no consent yet
        case requiresConsent
        /// User has authorized scanning on the current SSID
        case authorized
    }

    private var authState: ScanAuthState {
        guard !networkVM.isPublicNetwork else { return .publicNetworkBlocked }
        let ssid = networkVM.wifiInfo.ssid
        // Treat default / placeholder values as unknown
        guard !ssid.isEmpty, ssid != "Your Network", ssid != "--" else { return .ssidUnknown }
        guard consentedSSID == ssid else { return .requiresConsent }
        return .authorized
    }

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
                } else if networkVM.isPublicNetwork {
                    publicBlockView
                } else {
                    scanContent
                }
            }
            .navigationDestination(for: NetworkDevice.self) { device in
                DeviceDetailView(device: device)
            }
            .sheet(isPresented: $showConsentSheet) {
                ScanConsentSheet(
                    ssid: networkVM.wifiInfo.ssid,
                    accentColor: networkVM.accentColor,
                    onAuthorize: {
                        consentedSSID = networkVM.wifiInfo.ssid
                        showConsentSheet = false
                        startScan()
                    },
                    onCancel: {
                        showConsentSheet = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Public network hard block

    private var publicBlockView: some View {
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

            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.scorePoor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.scorePoor)
                }
                VStack(spacing: 6) {
                    Text("Scanning Unavailable")
                        .font(.system(size: 18 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Network scanning is disabled on public or unsecured networks to protect the privacy of other users.")
                        .font(.system(size: 14 * scale))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
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
                    // VPN warning banner — shown when authorized and VPN is active
                    if authState == .authorized && networkVM.isVPNActive {
                        vpnWarningBanner
                    }

                    GlassCard {
                        VStack(spacing: 0) {
                            // Header row
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
                                if authState == .authorized && !scanService.devices.isEmpty && !scanService.isScanning {
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
                                if authState == .ssidUnknown {
                                    ssidUnknownView
                                } else if authState == .requiresConsent {
                                    authRequiredView
                                } else {
                                    // Authorized — normal scan button
                                    Button(action: startScan) {
                                        HStack {
                                            if scanService.isScanning {
                                                ProgressView()
                                                    .tint(networkVM.accentColor)
                                                    .scaleEffect(0.8)
                                                VStack(spacing: 2) {
                                                    Text("\(scanService.discoveredCount) IPs found, \(scanService.devices.count) resolved")
                                                        .font(.system(size: 14 * scale, weight: .semibold))
                                                        .foregroundColor(Color.primary)
                                                    if !scanService.scanPhase.isEmpty {
                                                        Text(scanService.scanPhase)
                                                            .font(.system(size: 11 * scale))
                                                            .foregroundColor(.textSecondary)
                                                    }
                                                }
                                            } else {
                                                Image(systemName: "checkmark.shield.fill")
                                                    .font(.system(size: 13 * scale))
                                                    .foregroundColor(.scoreExcellent)
                                                Text(scanService.devices.isEmpty ? "Scan Network" : "Scan Again")
                                                    .font(.system(size: 16 * scale, weight: .semibold))
                                                    .foregroundColor(Color.primary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(networkVM.accentColor.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .disabled(scanService.isScanning)
                                    .accessibilityIdentifier("scanNetworkButton")

                                    // Authorized trust indicator
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 10 * scale))
                                            .foregroundColor(.scoreExcellent)
                                        Text("Authorized · \(consentedSSID)")
                                            .font(.system(size: 10 * scale, weight: .medium))
                                            .foregroundColor(.textSecondary)
                                            .lineLimit(1)
                                        Spacer()
                                    }

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

                                        if let me = thisDevice {
                                            youDeviceRow(me)
                                        }

                                        if isGrouped && !scanService.isScanning {
                                            groupedContent
                                        } else {
                                            listContent
                                        }
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

    // MARK: - Authorization required view (no consent for this SSID yet)

    private var authRequiredView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.textSecondary.opacity(0.10))
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.shield")
                    .font(.system(size: 24))
                    .foregroundColor(.textSecondary)
            }

            VStack(spacing: 5) {
                Text("Authorization Required")
                    .font(.system(size: 15 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)

                // Show the network name in a tinted pill
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 10 * scale))
                    Text(networkVM.wifiInfo.ssid)
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundColor(networkVM.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(networkVM.accentColor.opacity(0.12))
                .clipShape(Capsule())

                Text("Only scan networks you own or are authorized to probe.")
                    .font(.system(size: 12 * scale))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 2)
            }

            Button {
                showConsentSheet = true
            } label: {
                Text("Authorize Scanning")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundColor(Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(networkVM.accentColor.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityIdentifier("authorizeScanButton")
        }
        .padding(.vertical, 8)
    }

    // MARK: - SSID unknown view

    private var ssidUnknownView: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.scoreFair.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "shield.slash")
                    .font(.system(size: 24))
                    .foregroundColor(.scoreFair)
            }

            VStack(spacing: 5) {
                Text("Network Identity Unknown")
                    .font(.system(size: 15 * scale, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("WiFi Check needs to identify your network to authorize scanning. Grant Location access in Settings to enable per-network authorization.")
                    .font(.system(size: 12 * scale))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - VPN warning banner

    private var vpnWarningBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 15 * scale))
                .foregroundColor(.scoreFair)

            Text("VPN active — scan results show your local network, not the VPN network.")
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundColor(.scoreFair)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.scoreFair.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.scoreFair.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - View mode toggle

    private var viewModeToggle: some View {
        HStack(spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isGrouped = false }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(isGrouped ? .textSecondary : networkVM.accentColor)
                    .frame(width: 30, height: 26)
                    .background(isGrouped ? Color.clear : networkVM.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isGrouped = true }
            } label: {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundColor(isGrouped ? networkVM.accentColor : .textSecondary)
                    .frame(width: 30, height: 26)
                    .background(isGrouped ? networkVM.accentColor.opacity(0.15) : Color.clear)
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
        // Suppress slide/scale motion when Reduce Motion is enabled
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: scanService.devices)
    }

    // MARK: - Grouped content

    private var groupedContent: some View {
        VStack(spacing: 8) {
            ForEach(groupedDevices) { group in
                groupContainer(group)
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.25), value: scanService.devices)
    }

    private func groupContainer(_ group: DeviceGroup) -> some View {
        let isCollapsed = collapsedGroups.contains(group.id)
        return VStack(spacing: 0) {
            Button {
                // Reduce Motion: skip spring animation to avoid vestibular triggers
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
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
                        // Reduce Motion: suppress rotation animation
                        .animation(reduceMotion ? .none : .easeInOut(duration: 0.22), value: isCollapsed)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

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
                                .padding(.leading, 46)
                        }
                    }
                }
                // Reduce Motion: use opacity-only transition, no directional movement
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
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
                        .fill(networkVM.accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "iphone")
                        .font(.system(size: 17 * scale))
                        .foregroundColor(networkVM.accentColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(device.hostname.isEmpty ? "This Device" : device.hostname)
                            .font(.system(size: 13 * scale, weight: .semibold))
                            .foregroundColor(.textPrimary)
                            .lineLimit(1)
                        Text("you")
                            .font(.system(size: 9 * scale, weight: .bold))
                            .foregroundColor(networkVM.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(networkVM.accentColor.opacity(0.15))
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

// MARK: - Scan Consent Sheet

private struct ScanConsentSheet: View {
    let ssid: String
    let accentColor: Color
    let onAuthorize: () -> Void
    let onCancel: () -> Void

    @AppStorage("wqm-font-size") private var fontSizeRaw: String = "medium"
    private var scale: CGFloat { AppFontSize(rawValue: fontSizeRaw)?.scale ?? 1.0 }

    var body: some View {
        VStack(spacing: 0) {
            // Pull indicator spacer
            Spacer().frame(height: 8)

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(accentColor)
                }
                .padding(.top, 8)

                // Title + network name
                VStack(spacing: 10) {
                    Text("Authorize Network Scan")
                        .font(.system(size: 20 * scale, weight: .bold))
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 5) {
                        Image(systemName: "wifi")
                            .font(.system(size: 11 * scale, weight: .semibold))
                        Text(ssid)
                            .font(.system(size: 13 * scale, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }

                // Explanation
                VStack(alignment: .leading, spacing: 10) {
                    explanationRow(
                        icon: "checkmark.circle.fill",
                        color: .scoreExcellent,
                        text: "You own this network or have explicit permission to scan it."
                    )
                    explanationRow(
                        icon: "xmark.circle.fill",
                        color: .scorePoor,
                        text: "Scanning networks without authorization may violate laws and network policies."
                    )
                    explanationRow(
                        icon: "arrow.counterclockwise.circle.fill",
                        color: .textSecondary,
                        text: "You will be asked again if you connect to a different network."
                    )
                }
                .padding(.horizontal, 4)

                // Buttons
                VStack(spacing: 10) {
                    Button(action: onAuthorize) {
                        Text("I own or manage this network")
                            .font(.system(size: 16 * scale, weight: .semibold))
                            .foregroundColor(Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(accentColor.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityIdentifier("confirmScanAuthButton")

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 15 * scale, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .accessibilityIdentifier("cancelScanAuthButton")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.appBackground)
    }

    private func explanationRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14 * scale))
                .foregroundColor(color)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13 * scale))
                .foregroundColor(.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

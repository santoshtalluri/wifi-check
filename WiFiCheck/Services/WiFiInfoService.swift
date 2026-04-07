//
//  WiFiInfoService.swift
//  WiFi Check
//
//  Uses NEHotspotNetwork.fetchCurrent() with the wifi-info entitlement to get the real SSID.
//  Falls back to reverse-DNS of gateway IP if SSID fetch fails.

import Foundation
import Combine
import CoreLocation
import Network
import NetworkExtension

/// Retrieves WiFi network information: SSID, IP addresses, ISP, DNS, IPv6
final class WiFiInfoService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var wifiInfo = WiFiInfo()

    private var locationManager: CLLocationManager?
    private var locationAuthorized = false
    private var ispFetched = false  // Fetch ISP info once per session

    // Throttle public IP fetch — at most once every 5 minutes
    private var lastPublicIPFetch: Date?
    private let publicIPInterval: TimeInterval = 300

    // Short-timeout URLSession for external IP lookups (avoids blocking on slow networks)
    private static let ipSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }()

    override init() {
        super.init()
        if Thread.isMainThread {
            setupLocationManager()
        } else {
            DispatchQueue.main.sync { setupLocationManager() }
        }
        // Immediately populate IP addresses and network name
        // (doesn't require location — only CNCopyCurrentNetworkInfo did)
        refreshInfo()
    }

    private func setupLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        self.locationManager = manager
        let status = manager.authorizationStatus
        locationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    // MARK: - Location

    func requestLocationPermission() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let status = self.locationManager?.authorizationStatus ?? .notDetermined
            if status == .notDetermined {
                self.locationManager?.requestWhenInUseAuthorization()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        locationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        if locationAuthorized { refreshInfo() }
    }

    // MARK: - Refresh

    func refreshInfo() {
        wifiInfo.localIP = getLocalIP() ?? "--"
        wifiInfo.gatewayIP = getGatewayIP() ?? "--"
        wifiInfo.localIPv6 = getLocalIPv6() ?? ""
        wifiInfo.dnsServers = readDNSServers()
        fetchPublicIP()
        if !ispFetched { fetchISPInfo() }
        resolveNetworkName()
    }

    // MARK: - Network Name (SSID via NEHotspotNetwork)

    private func resolveNetworkName() {
        guard locationAuthorized else {
            wifiInfo.ssid = "WiFi"
            return
        }

        // Use NEHotspotNetwork.fetchCurrent() — requires wifi-info entitlement + location
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let net = network {
                    self.wifiInfo.ssid = net.ssid.isEmpty ? "WiFi" : net.ssid
                    self.wifiInfo.bssid = net.bssid
                    self.wifiInfo.signalStrength = net.signalStrength
                    if #available(iOS 15, *) {
                        self.wifiInfo.securityType = self.mapSecurityType(net.securityType)
                    }
                    self.wifiInfo.routerManufacturer = ""
                } else {
                    // Fallback: show gateway IP if SSID unavailable
                    let gw = self.wifiInfo.gatewayIP
                    self.wifiInfo.ssid = gw != "--" ? "WiFi (\(gw))" : "WiFi"
                    self.wifiInfo.bssid = "--"
                    self.wifiInfo.signalStrength = 0.0
                    self.wifiInfo.securityType = "--"
                    self.wifiInfo.routerManufacturer = ""
                }
            }
        }
    }

    // MARK: - Security Type Mapping

    @available(iOS 15, *)
    private func mapSecurityType(_ type: NEHotspotNetworkSecurityType) -> String {
        switch type {
        case .open: return "Open"
        case .WEP: return "WEP"
        case .personal: return "WPA/WPA2"
        case .enterprise: return "Enterprise"
        case .unknown: return "Secured"
        @unknown default: return "Secured"
        }
    }

    // MARK: - Local IP

    private func getLocalIP() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            let addrFamily = iface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        return address
    }

    // MARK: - Gateway IP (reads actual default route from routing table)

    private func getGatewayIP() -> String? {
        if let realGateway = readDefaultGateway() {
            return realGateway
        }
        // Fallback: derive from local IP
        guard let localIP = getLocalIP() else { return nil }
        let components = localIP.split(separator: ".")
        if components.count == 4 {
            return "\(components[0]).\(components[1]).\(components[2]).1"
        }
        return nil
    }

    /// Rounds up sockaddr length to long alignment (Darwin SA_SIZE macro)
    private func saRoundedSize(_ saLen: Int) -> Int {
        let longSize = MemoryLayout<Int>.size // 8 on arm64
        if saLen == 0 { return longSize }
        return 1 + ((saLen - 1) | (longSize - 1))
    }

    /// Read the default gateway from the BSD routing table via sysctl
    private func readDefaultGateway() -> String? {
        // NET_RT_FLAGS = 2, RTF_GATEWAY = 0x2
        var mib: [Int32] = [CTL_NET, AF_ROUTE, 0, AF_INET, 2 /* NET_RT_FLAGS */, 0x2 /* RTF_GATEWAY */]
        var needed: size_t = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &needed, nil, 0) == 0, needed > 0 else {
            return nil
        }

        let buf = UnsafeMutableRawPointer.allocate(byteCount: needed, alignment: 1)
        defer { buf.deallocate() }

        guard sysctl(&mib, UInt32(mib.count), buf, &needed, nil, 0) == 0 else {
            return nil
        }

        // rt_msghdr layout on arm64 iOS:
        //   offset 0:  rtm_msglen  (UInt16)  — total message length
        //   offset 2:  rtm_version (UInt8)
        //   offset 3:  rtm_type    (UInt8)
        //   offset 4:  rtm_index   (UInt16)
        //   offset 6:  (2 bytes padding)
        //   offset 8:  rtm_flags   (Int32)   ← gateway flag lives here
        //   offset 12: rtm_addrs   (Int32)   ← bitmask of which sockaddrs follow
        //   ...
        //   Total rt_msghdr = 92 bytes on arm64 (36 header + 56 rt_metrics)
        let headerSize = 92
        var offset = 0

        while offset + headerSize <= needed {
            let msgPtr = buf.advanced(by: offset)
            let msgLen = Int(msgPtr.load(fromByteOffset: 0, as: UInt16.self))
            guard msgLen > 0 else { break }

            // rtm_flags at offset 8 (NOT 24 — that was rtm_errno!)
            let flags = msgPtr.load(fromByteOffset: 8, as: Int32.self)
            // rtm_addrs at offset 12
            let addrs = msgPtr.load(fromByteOffset: 12, as: Int32.self)

            // Check RTF_GATEWAY flag (0x2)
            if flags & 0x2 != 0 {
                // sockaddr structures start after the rt_msghdr
                let saBase = buf.advanced(by: offset + headerSize)

                // RTA_DST = 0x1 (destination), RTA_GATEWAY = 0x2
                // If RTA_DST is present, skip the destination sockaddr first
                var gwOffset = 0
                if addrs & 0x1 != 0 {
                    // Destination sockaddr present — read its length and skip it
                    let destLen = Int(saBase.load(fromByteOffset: 0, as: UInt8.self))
                    gwOffset = saRoundedSize(destLen)
                }

                if addrs & 0x2 != 0 {
                    // Gateway sockaddr present
                    let gwBase = saBase.advanced(by: gwOffset)
                    let gwFamily = gwBase.load(fromByteOffset: 1, as: UInt8.self)

                    if gwFamily == UInt8(AF_INET) {
                        // sockaddr_in: sin_addr is at offset 4, 4 bytes
                        let b0 = gwBase.load(fromByteOffset: 4, as: UInt8.self)
                        let b1 = gwBase.load(fromByteOffset: 5, as: UInt8.self)
                        let b2 = gwBase.load(fromByteOffset: 6, as: UInt8.self)
                        let b3 = gwBase.load(fromByteOffset: 7, as: UInt8.self)
                        let ip = "\(b0).\(b1).\(b2).\(b3)"
                        if ip != "0.0.0.0" && !ip.hasPrefix("127.") {
                            return ip
                        }
                    }
                }
            }
            offset += msgLen
        }
        return nil
    }

    // MARK: - Public IP

    private func fetchPublicIP() {
        // Only re-fetch if the IP is unset or the throttle interval has elapsed
        if let last = lastPublicIPFetch,
           Date().timeIntervalSince(last) < publicIPInterval,
           wifiInfo.publicIP != "--", wifiInfo.publicIP != "Unavailable" {
            return
        }
        lastPublicIPFetch = Date()

        guard let url = URL(string: "https://api.ipify.org?format=json") else { return }

        WiFiInfoService.ipSession.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let ip = json["ip"] else {
                self?.fetchPublicIPv6()
                return
            }
            DispatchQueue.main.async { self?.wifiInfo.publicIP = ip }
        }.resume()
    }

    private func fetchPublicIPv6() {
        guard let url = URL(string: "https://api64.ipify.org?format=json") else { return }

        WiFiInfoService.ipSession.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let ip = json["ip"] else {
                DispatchQueue.main.async { self?.wifiInfo.publicIP = "Unavailable" }
                return
            }
            DispatchQueue.main.async { self?.wifiInfo.publicIP = ip }
        }.resume()
    }

    // MARK: - ISP Info (fetched once per session from ipinfo.io)

    private func fetchISPInfo() {
        ispFetched = true
        guard let url = URL(string: "https://ipinfo.io/json") else { return }

        WiFiInfoService.ipSession.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }

            DispatchQueue.main.async {
                guard let self = self else { return }
                // org format: "AS7922 Comcast Cable Communications, LLC" — strip AS number
                if let org = json["org"] {
                    let parts = org.components(separatedBy: " ")
                    self.wifiInfo.ispName = parts.count > 1
                        ? parts.dropFirst().joined(separator: " ")
                        : org
                }
                let city = json["city"] ?? ""
                let region = json["region"] ?? ""
                if !city.isEmpty && !region.isEmpty {
                    self.wifiInfo.ispCity = "\(city), \(region)"
                } else if !city.isEmpty {
                    self.wifiInfo.ispCity = city
                }
            }
        }.resume()
    }

    // MARK: - Local IPv6

    private func getLocalIPv6() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET6),
                  String(cString: iface.ifa_name) == "en0" else { continue }
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
            let ipv6 = String(cString: hostname)
            // Skip link-local (fe80::) — only report global or ULA addresses
            if !ipv6.lowercased().hasPrefix("fe80") && !ipv6.isEmpty {
                return ipv6
            }
        }
        return nil
    }

    // MARK: - DNS Servers

    /// Reads DNS nameserver entries from /etc/resolv.conf
    private func readDNSServers() -> [String] {
        guard let content = try? String(contentsOfFile: "/etc/resolv.conf", encoding: .utf8) else {
            return []
        }
        return content
            .components(separatedBy: "\n")
            .compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("nameserver") else { return nil }
                let parts = trimmed.components(separatedBy: .whitespaces)
                return parts.count > 1 ? parts[1] : nil
            }
    }
}

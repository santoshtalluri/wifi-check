//
//  WiFiInfoService.swift
//  WiFi Check (tvOS)
//
//  Detects the active network interface dynamically (en0 WiFi, en1/en2 Ethernet/USB-C).
//  Uses NEHotspotNetwork + CoreLocation for SSID on WiFi.
//  Falls back to UPnP router name, then "Wi-Fi Network" — never exposes the gateway IP.

import Foundation
import Combine
import CoreLocation
import Darwin

/// Retrieves WiFi/network information for the active interface on Apple TV.
final class WiFiInfoService: ObservableObject {

    @Published var wifiInfo = WiFiInfo()

    // Throttle public IP fetch — at most once every 5 minutes
    private var lastPublicIPFetch: Date?
    private let publicIPInterval: TimeInterval = 300

    // Short-timeout URLSession for external IP lookups
    private static let ipSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        return URLSession(configuration: config)
    }()

    init() {
        refreshInfo()
    }

    // MARK: - Refresh

    func refreshInfo() {
        // Detect active interface first — every other lookup uses it
        let (iface, connType) = detectActiveInterface()
        wifiInfo.activeInterface = iface
        wifiInfo.connectionType = connType

        wifiInfo.localIP   = getDeviceIP(on: iface)
        wifiInfo.localIPv6 = getIPv6Address(on: iface) ?? "--"
        wifiInfo.gatewayIP = getGatewayIP(fallbackIface: iface) ?? "--"
        fetchPublicIP()

        if connType == "Wi-Fi" {
            fetchSSID()
        } else {
            // Wired connection — no SSID to resolve
            wifiInfo.ssid = connType == "Ethernet" ? "Wired Network" : "USB-C LAN"
            wifiInfo.signalStrength = 0.0
            wifiInfo.securityType = "--"
        }
    }

    // MARK: - Active Interface Detection
    // Priority: en0 (WiFi) → en1 (built-in Ethernet on ATV 4K) → en2+ (USB-C adapter)

    private func detectActiveInterface() -> (name: String, type: String) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else {
            return ("en0", "Wi-Fi")
        }
        defer { freeifaddrs(ifaddr) }

        // Ordered preference: en0 first (WiFi), then en1, en2, en3 (Ethernet / USB-C)
        let candidates = ["en0", "en1", "en2", "en3"]
        var found: [String: String] = [:]  // iface name → IPv4

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            let flags = Int32(iface.ifa_flags)
            guard let ifaAddr = iface.ifa_addr else { continue }
            let name = String(cString: iface.ifa_name)
            guard candidates.contains(name),
                  (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING),
                  ifaAddr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let saLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            if getnameinfo(ifaAddr, saLen, &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostname)
                if !ip.isEmpty && ip != "0.0.0.0" && !ip.hasPrefix("127.") {
                    found[name] = ip
                }
            }
        }

        // Pick highest-priority active interface
        for name in candidates {
            if found[name] != nil {
                let connType = connectionType(for: name)
                return (name, connType)
            }
        }
        return ("en0", "Wi-Fi")
    }

    private func connectionType(for iface: String) -> String {
        switch iface {
        case "en0": return "Wi-Fi"
        case "en1": return "Ethernet"
        default:    return "USB-C LAN"
        }
    }

    // MARK: - SSID (WiFi only, real Apple TV with wifi-info entitlement + location)

    private func fetchSSID() {
        let locManager = LocationAuthorizationManager.shared
        if locManager.status == .notDetermined {
            locManager.requestAuthorization()
        }

        WiFiSSIDHelper.fetchCurrentSSID { [weak self] ssid, bssid in
            DispatchQueue.main.async {
                if let ssid = ssid, !ssid.isEmpty {
                    self?.wifiInfo.ssid = ssid
                    self?.wifiInfo.bssid = bssid ?? "--"
                } else {
                    // Try router UPnP friendly-name; fall back to "Wi-Fi Network"
                    self?.fetchSSIDFromGateway()
                }
            }
        }
        wifiInfo.signalStrength = 0.0
        wifiInfo.securityType = "--"
    }

    private func fetchSSIDFromGateway() {
        guard let gateway = getGatewayIP(fallbackIface: wifiInfo.activeInterface) else {
            wifiInfo.ssid = "Wi-Fi Network"
            return
        }
        let urls = [
            "http://\(gateway):49152/wps_device.xml",
            "http://\(gateway):8200/rootDesc.xml",
            "http://\(gateway):49000/igddesc.xml"
        ]
        Task {
            for urlString in urls {
                if let name = await fetchFriendlyName(from: urlString) {
                    await MainActor.run { self.wifiInfo.ssid = name }
                    return
                }
            }
            // Clean fallback — never expose the gateway IP in the network name
            await MainActor.run { self.wifiInfo.ssid = "Wi-Fi Network" }
        }
    }

    private func fetchFriendlyName(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await WiFiInfoService.ipSession.data(from: url)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            if let range = xml.range(of: "(?<=<friendlyName>)[^<]+", options: .regularExpression) {
                let name = String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? nil : name
            }
        } catch {}
        return nil
    }

    // MARK: - Device IP

    private func getDeviceIP(on iface: String) -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "--" }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: ifaddr!, next: { $0.pointee.ifa_next }) {
            let i = ptr.pointee
            let flags = Int32(i.ifa_flags)
            guard let ifaAddr = i.ifa_addr else { continue }
            let name = String(cString: i.ifa_name)
            guard name == iface,
                  (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING),
                  ifaAddr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let saLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            if getnameinfo(ifaAddr, saLen, &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: hostname)
            }
        }
        return "--"
    }

    // MARK: - IPv6 Address

    private func getIPv6Address(on iface: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = ptr.pointee
            guard let ifaAddr = i.ifa_addr,
                  ifaAddr.pointee.sa_family == UInt8(AF_INET6),
                  String(cString: i.ifa_name) == iface else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(ifaAddr, socklen_t(ifaAddr.pointee.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST)
            let addr = String(cString: hostname)
            // Skip link-local (fe80::) addresses
            if !addr.hasPrefix("fe80") && !addr.isEmpty {
                return addr
            }
        }
        return nil
    }

    // MARK: - Gateway IP

    private func getGatewayIP(fallbackIface: String) -> String? {
        if let gw = readDefaultGateway() { return gw }
        // Fallback: derive .1 from device IP
        let ip = getDeviceIP(on: fallbackIface)
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2]).1"
    }

    /// Rounds up sockaddr length to long alignment (Darwin SA_SIZE macro)
    private func saRoundedSize(_ saLen: Int) -> Int {
        let longSize = MemoryLayout<Int>.size
        if saLen == 0 { return longSize }
        return 1 + ((saLen - 1) | (longSize - 1))
    }

    /// Read the default gateway from the BSD routing table via sysctl
    private func readDefaultGateway() -> String? {
        var mib: [Int32] = [CTL_NET, AF_ROUTE, 0, AF_INET, 2 /* NET_RT_FLAGS */, 0x2 /* RTF_GATEWAY */]
        var needed: size_t = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &needed, nil, 0) == 0, needed > 0 else { return nil }

        let buf = UnsafeMutableRawPointer.allocate(byteCount: needed, alignment: 1)
        defer { buf.deallocate() }
        guard sysctl(&mib, UInt32(mib.count), buf, &needed, nil, 0) == 0 else { return nil }

        let headerSize = 92  // rt_msghdr size on arm64
        var offset = 0
        while offset + headerSize <= needed {
            let msgPtr = buf.advanced(by: offset)
            let msgLen = Int(msgPtr.load(fromByteOffset: 0, as: UInt16.self))
            guard msgLen > 0 else { break }

            let flags = msgPtr.load(fromByteOffset: 8,  as: Int32.self)
            let addrs = msgPtr.load(fromByteOffset: 12, as: Int32.self)

            if flags & 0x2 != 0 {
                let saBase = buf.advanced(by: offset + headerSize)
                var gwOffset = 0
                if addrs & 0x1 != 0 {
                    let destLen = Int(saBase.load(fromByteOffset: 0, as: UInt8.self))
                    gwOffset = saRoundedSize(destLen)
                }
                if addrs & 0x2 != 0 {
                    let gwBase = saBase.advanced(by: gwOffset)
                    if gwBase.load(fromByteOffset: 1, as: UInt8.self) == UInt8(AF_INET) {
                        let b0 = gwBase.load(fromByteOffset: 4, as: UInt8.self)
                        let b1 = gwBase.load(fromByteOffset: 5, as: UInt8.self)
                        let b2 = gwBase.load(fromByteOffset: 6, as: UInt8.self)
                        let b3 = gwBase.load(fromByteOffset: 7, as: UInt8.self)
                        let ip = "\(b0).\(b1).\(b2).\(b3)"
                        if ip != "0.0.0.0" && !ip.hasPrefix("127.") { return ip }
                    }
                }
            }
            offset += msgLen
        }
        return nil
    }

    // MARK: - Public IP

    private func fetchPublicIP() {
        if let last = lastPublicIPFetch,
           Date().timeIntervalSince(last) < publicIPInterval,
           wifiInfo.publicIP != "--", wifiInfo.publicIP != "Unavailable" {
            return
        }
        lastPublicIPFetch = Date()

        guard let url = URL(string: "https://api.ipify.org?format=json") else { return }
        WiFiInfoService.ipSession.dataTask(with: url) { [weak self] data, _, error in
            guard let data, error == nil,
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
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let ip = json["ip"] else {
                DispatchQueue.main.async { self?.wifiInfo.publicIP = "Unavailable" }
                return
            }
            DispatchQueue.main.async { self?.wifiInfo.publicIP = ip }
        }.resume()
    }
}

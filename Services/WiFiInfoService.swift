//
//  WiFiInfoService.swift
//  WiFiQualityMonitor
//

import Foundation
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import Network
import Combine

/// Retrieves WiFi network information: SSID, IP addresses
final class WiFiInfoService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var wifiInfo = WiFiInfo()

    private let locationManager = CLLocationManager()
    private var locationAuthorized = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // MARK: - Location (required for SSID)

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        locationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
        if locationAuthorized {
            refreshInfo()
        }
    }

    // MARK: - Refresh All Info

    func refreshInfo() {
        wifiInfo.ssid = fetchSSID()
        wifiInfo.localIP = getLocalIP() ?? "--"
        wifiInfo.gatewayIP = getGatewayIP() ?? "--"
        fetchPublicIP()
    }

    // MARK: - SSID

    private func fetchSSID() -> String {
        guard locationAuthorized else { return "Your Network" }

        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for iface in interfaces {
                if let info = CNCopyCurrentNetworkInfo(iface as CFString) as? [String: Any],
                   let ssid = info[kCNNetworkInfoKeySSID as String] as? String {
                    return ssid
                }
            }
        }
        return "Your Network"
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

    // MARK: - Gateway IP

    private func getGatewayIP() -> String? {
        // Try reading real default gateway from BSD routing table
        if let realGateway = getDefaultGatewayFromRoutingTable() {
            return realGateway
        }
        // Fallback: derive from local IP (may be wrong on mesh networks)
        guard let localIP = getLocalIP() else { return nil }
        let components = localIP.split(separator: ".")
        if components.count == 4 {
            return "\(components[0]).\(components[1]).\(components[2]).1"
        }
        return nil
    }

    /// Read the default IPv4 gateway from the kernel routing table via sysctl.
    /// Works on all network types including mesh (Eero, Google Nest, Orbi).
    private func getDefaultGatewayFromRoutingTable() -> String? {
        // Constants from <net/route.h>
        let RTF_GATEWAY: Int32 = 0x2
        let NET_RT_FLAGS: Int32 = 2
        let RTA_DST: Int32 = 0x1
        let RTA_GATEWAY: Int32 = 0x2

        // rt_msghdr layout offsets (ARM64):
        // rtm_msglen at offset 0 (UInt16)
        // rtm_addrs  at offset 12 (Int32)
        // Total header size: 92 bytes on ARM64 (includes rt_metrics)
        let rtMsghdrSize = 92

        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY]
        var bufferSize: size_t = 0

        // First call: get required buffer size
        guard sysctl(&mib, UInt32(mib.count), nil, &bufferSize, nil, 0) == 0,
              bufferSize > 0 else {
            return nil
        }

        // Allocate and fill buffer
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &bufferSize, nil, 0) == 0 else {
            return nil
        }

        // Parse routing messages looking for default route (dest = 0.0.0.0)
        var offset = 0
        while offset + rtMsghdrSize <= bufferSize {
            // Read rtm_msglen (UInt16 at offset 0)
            let msgLen = Int(buffer[offset]) | (Int(buffer[offset + 1]) << 8)
            guard msgLen > 0 else { break }

            // Read rtm_addrs (Int32 at offset 12)
            let addrsOffset = offset + 12
            let rtmAddrs = Int32(buffer[addrsOffset])
                | (Int32(buffer[addrsOffset + 1]) << 8)
                | (Int32(buffer[addrsOffset + 2]) << 16)
                | (Int32(buffer[addrsOffset + 3]) << 24)

            // Only process if both DST and GATEWAY are present
            if rtmAddrs & RTA_DST != 0 && rtmAddrs & RTA_GATEWAY != 0 {
                let saStart = offset + rtMsghdrSize

                // Read destination sockaddr_in
                if saStart + MemoryLayout<sockaddr_in>.size <= bufferSize {
                    let gateway: String? = buffer.withUnsafeBufferPointer { buf in
                        let dstPtr = UnsafeRawPointer(buf.baseAddress!.advanced(by: saStart))
                        let dstSa = dstPtr.assumingMemoryBound(to: sockaddr_in.self).pointee

                        // Default route has destination 0.0.0.0
                        guard dstSa.sin_family == UInt8(AF_INET),
                              dstSa.sin_addr.s_addr == 0 else {
                            return nil
                        }

                        // Gateway follows destination, aligned to 4-byte boundary
                        let dstLen = Int(max(
                            dstPtr.assumingMemoryBound(to: sockaddr.self).pointee.sa_len,
                            UInt8(MemoryLayout<sockaddr_in>.size)
                        ))
                        let alignedDstLen = (dstLen + 3) & ~3
                        let gwOffset = saStart + alignedDstLen

                        guard gwOffset + MemoryLayout<sockaddr_in>.size <= bufferSize else {
                            return nil
                        }

                        let gwPtr = UnsafeRawPointer(buf.baseAddress!.advanced(by: gwOffset))
                        let gwSa = gwPtr.assumingMemoryBound(to: sockaddr_in.self).pointee

                        guard gwSa.sin_family == UInt8(AF_INET) else { return nil }

                        var gwAddr = gwSa.sin_addr
                        var addrBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        guard let cString = inet_ntop(AF_INET, &gwAddr, &addrBuf,
                                                       socklen_t(addrBuf.count)) else {
                            return nil
                        }
                        return String(cString: cString)
                    }

                    if let gw = gateway {
                        return gw
                    }
                }
            }

            offset += msgLen
        }
        return nil
    }

    // MARK: - Public IP

    private func fetchPublicIP() {
        guard let url = URL(string: "https://api.ipify.org?format=json") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let ip = json["ip"] else {
                // Try IPv6 fallback
                self?.fetchPublicIPv6()
                return
            }
            DispatchQueue.main.async {
                self?.wifiInfo.publicIP = ip
            }
        }.resume()
    }

    private func fetchPublicIPv6() {
        guard let url = URL(string: "https://api64.ipify.org?format=json") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let ip = json["ip"] else {
                DispatchQueue.main.async {
                    self?.wifiInfo.publicIP = "Unavailable"
                }
                return
            }
            DispatchQueue.main.async {
                self?.wifiInfo.publicIP = ip
            }
        }.resume()
    }
}

//
//  WiFiInfoService.swift
//  WiFiQualityMonitor
//

import Foundation
import Combine
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import Network

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
        refreshInfo()
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
        // Read default gateway from routing table
        // Simplified: derive from local IP (e.g., 192.168.1.x -> 192.168.1.1)
        guard let localIP = getLocalIP() else { return nil }
        let components = localIP.split(separator: ".")
        if components.count == 4 {
            return "\(components[0]).\(components[1]).\(components[2]).1"
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

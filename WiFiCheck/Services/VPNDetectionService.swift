//
//  VPNDetectionService.swift
//  WiFi Check
//
//  Detects VPN using network interface names — no entitlements needed

import Foundation
import Combine
import Network

/// Detects VPN connection by checking for VPN-related network interfaces
/// Uses NWPathMonitor instead of NEVPNManager (no entitlement required)
final class VPNDetectionService: ObservableObject {

    @Published var isVPNActive: Bool = false

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Check for VPN interfaces: utun (IPSec/IKEv2), ipsec, ppp, tap, tun
            let vpnProtocols: [String] = ["tap", "tun", "ppp", "ipsec"]
            let interfaces = path.availableInterfaces.map { $0.name.lowercased() }

            let vpnDetected = interfaces.contains { iface in
                vpnProtocols.contains(where: { iface.hasPrefix($0) }) ||
                (iface.hasPrefix("utun") && iface != "utun0") // utun0 is system, utun1+ is VPN
            }

            DispatchQueue.main.async {
                self?.isVPNActive = vpnDetected
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.wificheck.vpn"))
    }

    deinit {
        monitor.cancel()
    }
}

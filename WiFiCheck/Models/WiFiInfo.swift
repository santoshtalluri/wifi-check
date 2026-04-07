//
//  WiFiInfo.swift
//  WiFi Check
//

import Foundation
import Combine

/// WiFi network information displayed in the info card
struct WiFiInfo {
    var ssid: String = "Your Network"
    var localIP: String = "--"
    var gatewayIP: String = "--"
    var publicIP: String = "Fetching..."
    var isPublicNetwork: Bool = false
    var isEnterprise: Bool = false
    // Enhanced network info (v1)
    var bssid: String = "--"
    var signalStrength: Double = 0.0   // 0.0–1.0 from NEHotspotNetwork
    var securityType: String = "--"    // WPA2, WPA3, etc.
    // Extended info
    var routerManufacturer: String = ""   // OUI lookup on BSSID
    var ispName: String = ""              // From ipinfo.io org field
    var ispCity: String = ""             // From ipinfo.io city + region
    var dnsServers: [String] = []        // From /etc/resolv.conf
    var localIPv6: String = ""           // Global IPv6 on active interface
    // Connection type detection
    var connectionType: String = "Wi-Fi" // "Wi-Fi", "Ethernet", "USB-C LAN"
    var activeInterface: String = "en0"  // BSD interface name (en0, en1, en2…)
}

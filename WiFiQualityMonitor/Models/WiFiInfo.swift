//
//  WiFiInfo.swift
//  WiFiQualityMonitor
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
}

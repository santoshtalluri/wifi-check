//
//  NetworkMetrics.swift
//  WiFiQualityMonitor
//

import Foundation

/// Holds raw measurement values from each ping cycle
struct NetworkMetrics {
    var routerLatency: Double?    // ms — ping gateway
    var packetLoss: Double?       // percentage 0-100
    var internetLatency: Double?  // ms — ping 8.8.8.8
    var dnsSpeed: Double?         // ms — resolve apple.com
    var throughput: Double?       // Mbps — download probe
    var jitter: Double?           // ms — std dev of ping RTTs

    static let empty = NetworkMetrics()
}

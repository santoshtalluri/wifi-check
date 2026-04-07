//
//  NetworkMonitor.swift
//  WiFi Check
//

import Foundation
import Network
import Combine

/// Monitors network connectivity using NWPathMonitor
/// Detects WiFi vs cellular, notifies on changes
final class NetworkMonitor: ObservableObject {

    @Published var isConnectedToWiFi: Bool = false
    @Published var isConnected: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.wificheck.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isConnectedToWiFi = path.usesInterfaceType(.wifi)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

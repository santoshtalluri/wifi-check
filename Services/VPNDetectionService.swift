//
//  VPNDetectionService.swift
//  WiFiQualityMonitor
//

import Foundation
import NetworkExtension
import Combine

/// Detects VPN connection status using NEVPNManager
/// Observes NEVPNStatusDidChange for real-time updates
final class VPNDetectionService: ObservableObject {

    @Published var isVPNActive: Bool = false

    init() {
        checkVPNStatus()
        observeVPNChanges()
    }

    private func checkVPNStatus() {
        NEVPNManager.shared().loadFromPreferences { [weak self] error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                let status = NEVPNManager.shared().connection.status
                self?.isVPNActive = (status == .connected || status == .connecting)
            }
        }
    }

    private func observeVPNChanges() {
        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let status = NEVPNManager.shared().connection.status
            self?.isVPNActive = (status == .connected || status == .connecting)
        }
    }
}

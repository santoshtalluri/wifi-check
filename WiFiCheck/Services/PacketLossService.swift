//
//  PacketLossService.swift
//  WiFi Check
//

import Foundation
import Network

/// Measures packet loss by sending multiple TCP probes
/// and counting timeouts
final class PacketLossService {

    private let pingCount = 10
    private let timeout: TimeInterval = 1.5

    /// Measure packet loss percentage to a host
    /// Sends `pingCount` probes and returns failure percentage
    func measurePacketLoss(host: String) async -> Double {
        var failures = 0

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<pingCount {
                group.addTask { [self] in
                    return await self.probe(host: host)
                }
            }
            for await success in group {
                if !success { failures += 1 }
            }
        }

        return Double(failures) / Double(pingCount) * 100.0
    }

    /// Single TCP probe — returns true if connection succeeded
    private func probe(host: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.wificheck.packetloss")
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: 53,
                using: .tcp
            )

            var resolved = false
            let resolveOnce: (Bool) -> Void = { value in
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resolveOnce(true)
                case .failed, .cancelled:
                    resolveOnce(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                resolveOnce(false)
            }
        }
    }
}

//
//  PacketLossService.swift
//  WiFiQualityMonitor
//

import Foundation
import Network

/// Measures packet loss by sending UDP DNS query probes
/// and counting how many get responses.
final class PacketLossService {

    private let probeCount = 10
    private let timeout: TimeInterval = 1.5

    /// Measure packet loss percentage to a host.
    /// Uses UDP DNS probes to the gateway (most reliable for routers).
    /// Falls back to TCP:443 probes to an internet host if gateway ignores DNS.
    func measurePacketLoss(host: String) async -> Double {
        let gatewayResults = await runUDPDNSProbes(host: host)

        // If ALL probes failed, gateway probably doesn't run DNS.
        // Fall back to internet TCP probes.
        if gatewayResults.allSatisfy({ !$0 }) {
            let internetResults = await runTCPProbes(host: "1.1.1.1", port: 443)
            let failures = internetResults.filter { !$0 }.count
            return Double(failures) / Double(probeCount) * 100.0
        }

        let failures = gatewayResults.filter { !$0 }.count
        return Double(failures) / Double(probeCount) * 100.0
    }

    // MARK: - UDP DNS Probes

    /// Run probes sequentially with small gaps to avoid burst congestion artifacts.
    private func runUDPDNSProbes(host: String) async -> [Bool] {
        var results: [Bool] = []
        for _ in 0..<probeCount {
            let success = await udpDNSProbe(host: host)
            results.append(success)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms gap
        }
        return results
    }

    /// Send a real DNS query over UDP and check if we get a response.
    private func udpDNSProbe(host: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.wqm.packetloss.udp")
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: 53,
                using: .udp
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
                    let dnsQuery = PingService.buildDNSQuery(for: "apple.com")
                    connection.send(content: dnsQuery, completion: .contentProcessed { error in
                        if error != nil {
                            resolveOnce(false)
                            return
                        }
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { data, _, _, recvError in
                            resolveOnce(data != nil && recvError == nil)
                        }
                    })
                case .failed, .cancelled, .waiting:
                    resolveOnce(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + self.timeout) {
                resolveOnce(false)
            }
        }
    }

    // MARK: - TCP Probes (fallback)

    private func runTCPProbes(host: String, port: UInt16) async -> [Bool] {
        var results: [Bool] = []
        for _ in 0..<probeCount {
            let success = await tcpProbe(host: host, port: port)
            results.append(success)
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return results
    }

    /// TCP handshake probe — returns true if handshake completes.
    private func tcpProbe(host: String, port: UInt16) async -> Bool {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.wqm.packetloss.tcp")
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
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
                case .failed, .cancelled, .waiting:
                    resolveOnce(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + self.timeout) {
                resolveOnce(false)
            }
        }
    }
}

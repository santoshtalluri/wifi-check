//
//  PingService.swift
//  WiFiQualityMonitor
//

import Foundation
import Network

/// Measures latency by probing hosts via UDP/TCP connections
final class PingService {

    /// Ping an internet host using TCP connection to port 53 (DNS)
    func ping(host: String, timeout: TimeInterval = 2.0) async -> Double? {
        return await tcpProbe(host: host, port: 53, timeout: timeout)
    }

    /// Ping gateway IP using UDP port 53 (DNS) — most routers respond to this
    func pingGateway(ip: String, timeout: TimeInterval = 2.0) async -> Double? {
        // Try UDP port 53 first (DNS — nearly all routers respond)
        if let result = await udpProbe(host: ip, port: 53, timeout: timeout) {
            return result
        }
        // Fallback to TCP port 53
        return await tcpProbe(host: ip, port: 53, timeout: timeout)
    }

    // MARK: - TCP Probe

    private func tcpProbe(host: String, port: UInt16, timeout: TimeInterval) async -> Double? {
        let start = CFAbsoluteTimeGetCurrent()

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.wqm.ping.tcp")
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )

            var resolved = false
            let resolveOnce: (Double?) -> Void = { value in
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                    resolveOnce(elapsed)
                case .failed, .cancelled:
                    resolveOnce(nil)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                resolveOnce(nil)
            }
        }
    }

    // MARK: - UDP Probe

    private func udpProbe(host: String, port: UInt16, timeout: TimeInterval) async -> Double? {
        let start = CFAbsoluteTimeGetCurrent()

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.wqm.ping.udp")
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .udp
            )

            var resolved = false
            let resolveOnce: (Double?) -> Void = { value in
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // UDP "ready" means path is available — send a DNS query to measure RTT
                    let dnsQuery = self.buildDNSQuery()
                    connection.send(content: dnsQuery, completion: .contentProcessed { error in
                        if error != nil {
                            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                            resolveOnce(elapsed) // Still got to .ready, count it
                            return
                        }
                        // Wait for response
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { data, _, _, _ in
                            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                            resolveOnce(elapsed)
                        }
                    })
                case .failed, .cancelled:
                    resolveOnce(nil)
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                resolveOnce(nil)
            }
        }
    }

    /// Build a minimal DNS query for "apple.com" (type A)
    private func buildDNSQuery() -> Data {
        var data = Data()
        // Transaction ID
        data.append(contentsOf: [0x00, 0x01])
        // Flags: standard query
        data.append(contentsOf: [0x01, 0x00])
        // Questions: 1
        data.append(contentsOf: [0x00, 0x01])
        // Answer/Authority/Additional RRs: 0
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Query: apple.com
        data.append(5) // length of "apple"
        data.append(contentsOf: "apple".utf8)
        data.append(3) // length of "com"
        data.append(contentsOf: "com".utf8)
        data.append(0) // null terminator
        // Type A (1), Class IN (1)
        data.append(contentsOf: [0x00, 0x01, 0x00, 0x01])
        return data
    }
}

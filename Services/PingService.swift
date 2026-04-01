//
//  PingService.swift
//  WiFiQualityMonitor
//

import Foundation
import Network

/// Measures latency using TCP handshake time (SYN -> SYN-ACK = one RTT).
/// NWConnection reports .ready when the TCP handshake completes.
final class PingService {

    // MARK: - Internet Latency

    /// Ping an internet host by measuring TCP handshake to port 443.
    /// Port 443 is reliably open on major DNS providers.
    /// Falls back through multiple targets for reliability.
    func ping(host: String, timeout: TimeInterval = 3.0) async -> Double? {
        let targets: [(String, UInt16)] = [
            (host, 443),
            ("1.1.1.1", 443),
            ("8.8.4.4", 443),
        ]

        for (targetHost, port) in targets {
            if let result = await tcpHandshakeLatency(host: targetHost, port: port, timeout: timeout) {
                return result
            }
        }
        return nil
    }

    // MARK: - Jitter Measurement

    /// Measures jitter by performing multiple pings and computing the standard
    /// deviation of RTTs. Jitter = variation in latency, which causes buffering
    /// and stuttering even when average latency is acceptable.
    func measureJitter(host: String = "8.8.8.8", sampleCount: Int = 5) async -> Double? {
        var samples: [Double] = []

        for _ in 0..<sampleCount {
            if let rtt = await tcpHandshakeLatency(host: host, port: 443, timeout: 3.0) {
                samples.append(rtt)
            }
            // Small gap between samples to avoid burst effects
            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
        }

        guard samples.count >= 3 else { return nil }

        // Jitter = standard deviation of RTT samples
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
        return sqrt(variance)
    }

    // MARK: - Gateway Latency

    /// Ping gateway using multiple strategies for maximum reliability.
    /// Strategy 1: TCP to port 53 (DNS forwarder — most common on routers)
    /// Strategy 2: TCP to port 80 (router admin interface)
    /// Strategy 3: UDP DNS query (send real packet, measure round-trip)
    func pingGateway(ip: String, timeout: TimeInterval = 2.0) async -> Double? {
        if let result = await tcpHandshakeLatency(host: ip, port: 53, timeout: timeout) {
            return result
        }
        if let result = await tcpHandshakeLatency(host: ip, port: 80, timeout: timeout) {
            return result
        }
        if let result = await udpDNSProbeLatency(host: ip, timeout: timeout) {
            return result
        }
        return nil
    }

    // MARK: - TCP Handshake Measurement

    /// Measures pure TCP handshake latency. NWConnection transitions
    /// to .ready when the 3-way handshake completes, giving accurate RTT.
    private func tcpHandshakeLatency(host: String, port: UInt16, timeout: TimeInterval) async -> Double? {
        let start = CFAbsoluteTimeGetCurrent()

        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.wqm.ping.\(host).\(port)")
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
                case .waiting:
                    // Path not available — treat as failure instead of hanging
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

    // MARK: - UDP DNS Probe (fallback for gateways)

    /// Sends a real DNS query over UDP and waits for the response.
    /// Measures actual round-trip time, unlike bare UDP connection state.
    private func udpDNSProbeLatency(host: String, timeout: TimeInterval) async -> Double? {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue(label: "com.wqm.udpdns")
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: 53,
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
                    let dnsQuery = Self.buildDNSQuery(for: "apple.com")
                    let sendStart = CFAbsoluteTimeGetCurrent()

                    connection.send(content: dnsQuery, completion: .contentProcessed { error in
                        if error != nil {
                            resolveOnce(nil)
                            return
                        }
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { data, _, _, recvError in
                            if data != nil && recvError == nil {
                                let elapsed = (CFAbsoluteTimeGetCurrent() - sendStart) * 1000.0
                                resolveOnce(elapsed)
                            } else {
                                resolveOnce(nil)
                            }
                        }
                    })

                case .failed, .cancelled, .waiting:
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

    // MARK: - DNS Query Builder

    /// Build a minimal DNS A-record query packet.
    nonisolated static func buildDNSQuery(for domain: String) -> Data {
        var data = Data()
        // Transaction ID
        data.append(contentsOf: [0x00, 0x01])
        // Flags: standard query, recursion desired
        data.append(contentsOf: [0x01, 0x00])
        // Questions: 1
        data.append(contentsOf: [0x00, 0x01])
        // Answer, Authority, Additional RRs: 0
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Encode domain name labels
        for label in domain.split(separator: ".") {
            data.append(UInt8(label.count))
            data.append(contentsOf: label.utf8)
        }
        data.append(0x00) // null terminator
        // Type: A (1)
        data.append(contentsOf: [0x00, 0x01])
        // Class: IN (1)
        data.append(contentsOf: [0x00, 0x01])
        return data
    }
}

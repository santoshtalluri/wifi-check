//
//  ThroughputService.swift
//  WiFi Check
//

import Foundation

/// Measures download and upload throughput using a globally distributed CDN endpoint.
/// Uses 75 MB download / 25 MB upload so transfer time dominates HTTPS handshake overhead
/// and TCP slow-start, giving accurate readings on fast connections (100 Mbps–1+ Gbps).
final class ThroughputService {

    /// Measure download throughput in Mbps.
    /// Downloads 75 MB from a globally distributed CDN endpoint.
    func measureThroughput() async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=75000000") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  elapsed > 0 else { return nil }

            let bytes = Double(data.count)
            let mbps = (bytes * 8.0) / (elapsed * 1_000_000.0)
            return mbps
        } catch {
            return nil
        }
    }

    /// Measure upload throughput in Mbps.
    /// POSTs 25 MB to a CDN upload endpoint.
    func measureUploadThroughput() async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return nil }

        let payloadSize = 25_000_000  // 25 MB
        let payload = Data(count: payloadSize)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (_, response) = try await URLSession.shared.upload(for: request, from: payload)
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  elapsed > 0 else { return nil }

            let mbps = (Double(payloadSize) * 8.0) / (elapsed * 1_000_000.0)
            return mbps
        } catch {
            return nil
        }
    }
}

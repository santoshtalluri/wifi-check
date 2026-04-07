//
//  ThroughputService.swift
//  WiFi Check
//

import Foundation

/// Measures download and upload throughput using a globally distributed CDN endpoint.
/// Uses 5 MB download / 3 MB upload so transfer time dominates HTTPS handshake overhead,
/// giving accurate readings across the full range from 5 Mbps to 1+ Gbps.
final class ThroughputService {

    /// Measure download throughput in Mbps.
    /// Downloads 5 MB from a globally distributed CDN endpoint.
    func measureThroughput() async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=5000000") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
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
    /// POSTs 3 MB to a CDN upload endpoint.
    func measureUploadThroughput() async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return nil }

        let payloadSize = 3_000_000  // 3 MB
        let payload = Data(count: payloadSize)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
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

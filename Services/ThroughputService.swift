//
//  ThroughputService.swift
//  WiFiQualityMonitor
//

import Foundation

/// Measures actual download throughput by fetching a small payload from a CDN.
/// Uses Cloudflare's speed test endpoint — reliable, fast, globally distributed.
final class ThroughputService {

    /// Download a small payload and return throughput in Mbps.
    /// Uses ~200KB to balance accuracy vs data usage.
    func measureThroughput() async -> Double? {
        // Cloudflare speed test endpoint — returns exactly the requested bytes
        let url = URL(string: "https://speed.cloudflare.com/__down?bytes=200000")!

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10.0

        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  data.count > 1000 else {
                return nil
            }

            let elapsed = CFAbsoluteTimeGetCurrent() - start
            guard elapsed > 0.01 else { return nil } // Sanity check

            // Convert bytes/sec to Megabits/sec
            let bytesPerSecond = Double(data.count) / elapsed
            let mbps = bytesPerSecond * 8.0 / 1_000_000.0

            return mbps
        } catch {
            return nil
        }
    }
}

import Foundation
import Network

struct SiteTestResult {
    var dnsTime: Double?       // milliseconds
    var latency: Double?       // milliseconds
    var downloadSpeed: Double? // Mbps — site page download speed
    var error: String?         // nil if success
}

final class SiteSpeedService: Sendable {

    /// Test a single site — returns DNS time, latency, and download speed
    nonisolated func testSite(domain: String) async -> SiteTestResult {
        // 1. DNS Resolution
        let dnsTime = await measureDNS(domain: domain)

        // 2. TCP Latency (port 443)
        let latency = await measureLatency(host: domain)

        // 3. Download speed
        let speed = await measureDownload(domain: domain)

        // If all nil, site is unreachable
        if dnsTime == nil && latency == nil && speed == nil {
            return SiteTestResult(error: "Unreachable")
        }

        return SiteTestResult(dnsTime: dnsTime, latency: latency, downloadSpeed: speed)
    }

    nonisolated private func measureDNS(domain: String) async -> Double? {
        // Use CFHost for DNS resolution timing
        let start = CFAbsoluteTimeGetCurrent()

        return await withCheckedContinuation { continuation in
            let host = CFHostCreateWithName(nil, domain as CFString).takeRetainedValue()
            var context = CFHostClientContext()
            CFHostSetClient(host, nil, &context)

            var error = CFStreamError()
            let resolved = CFHostStartInfoResolution(host, .addresses, &error)

            if resolved {
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                continuation.resume(returning: max(elapsed, 0.1))
            } else {
                continuation.resume(returning: nil)
            }
        }
    }

    nonisolated private func measureLatency(host: String) async -> Double? {
        let start = CFAbsoluteTimeGetCurrent()

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: 443,
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

            connection.start(queue: DispatchQueue(label: "com.wificheck.sitelatency"))

            // Timeout after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                resolveOnce(nil)
            }
        }
    }

    nonisolated private func measureDownload(domain: String) async -> Double? {
        guard let url = URL(string: "https://\(domain)") else { return nil }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)

        let start = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await session.data(from: url)
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode < 400,
                  elapsed > 0 else { return nil }

            let bytes = Double(data.count)
            let mbps = (bytes * 8.0) / (elapsed * 1_000_000.0)
            return mbps
        } catch {
            return nil
        }
    }
}

//
//  DNSService.swift
//  WiFiQualityMonitor
//

import Foundation

/// Measures DNS resolution speed using getaddrinfo with cache busting.
/// Uses a random subdomain prefix to bypass OS DNS cache and force a real lookup.
final class DNSService {

    /// Measure DNS resolution time for a known domain.
    /// Uses a random subdomain to bypass DNS cache at all levels.
    /// - Returns: Resolution time in milliseconds, or nil if failed.
    func measureDNSSpeed(domain: String = "apple.com") async -> Double? {
        // Random subdomain forces a real recursive DNS lookup (not cached)
        let randomPrefix = UUID().uuidString.prefix(8).lowercased()
        let cacheBustDomain = "\(randomPrefix).\(domain)"

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let start = CFAbsoluteTimeGetCurrent()

                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC
                hints.ai_socktype = SOCK_STREAM

                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(cacheBustDomain, nil, &hints, &result)
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

                if result != nil {
                    freeaddrinfo(result)
                }

                if status == 0 {
                    // Resolved successfully
                    continuation.resume(returning: elapsed)
                } else if status == EAI_NONAME {
                    // NXDOMAIN — expected for random subdomains, but the DNS
                    // round-trip still happened so the timing is valid
                    continuation.resume(returning: elapsed)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

//
//  DNSService.swift
//  WiFiQualityMonitor
//

import Foundation

/// Measures DNS resolution speed by timing a hostname lookup
final class DNSService {

    /// Measure DNS resolution time for a known domain
    /// - Returns: Resolution time in milliseconds
    func measureDNSSpeed(domain: String = "apple.com") async -> Double? {
        let start = CFAbsoluteTimeGetCurrent()

        // Force a fresh DNS lookup via CFHost
        return await withCheckedContinuation { continuation in
            let hostRef = CFHostCreateWithName(kCFAllocatorDefault, domain as CFString).takeRetainedValue()
            var error = CFStreamError()

            CFHostStartInfoResolution(hostRef, .addresses, &error)

            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

            if error.domain == 0 {
                continuation.resume(returning: elapsed)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

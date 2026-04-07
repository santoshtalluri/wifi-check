//
//  DeviceBandwidthService.swift
//  WiFi Check TV
//
//  Reads network interface statistics via getifaddrs() to track
//  this device's real-time upload/download bandwidth.
//  Works on tvOS (en0 = WiFi) and iOS (en0 = WiFi, pdp_ip0 = cellular).
//

import Foundation
import Darwin

final class DeviceBandwidthService {

    // MARK: - Types

    struct InterfaceSnapshot {
        let timestamp: Date
        let bytesIn: UInt64
        let bytesOut: UInt64
        let packetsIn: UInt64
        let packetsOut: UInt64
        let interface: String           // "en0" or "pdp_ip0"
    }

    struct BandwidthReading {
        let downloadBytesPerSec: Double
        let uploadBytesPerSec: Double
        let sessionBytesIn: UInt64
        let sessionBytesOut: UInt64
        let packetsIn: UInt64
        let packetsOut: UInt64
        let interface: String
        let timestamp: Date

        var downloadFormatted: String { Self.formatBytes(downloadBytesPerSec) + "/s" }
        var uploadFormatted: String   { Self.formatBytes(uploadBytesPerSec) + "/s" }
        var sessionInFormatted: String  { Self.formatBytes(Double(sessionBytesIn)) }
        var sessionOutFormatted: String { Self.formatBytes(Double(sessionBytesOut)) }
        var sessionTotalFormatted: String { Self.formatBytes(Double(sessionBytesIn + sessionBytesOut)) }

        static func formatBytes(_ bytes: Double) -> String {
            if bytes >= 1_073_741_824 { return String(format: "%.1f GB", bytes / 1_073_741_824) }
            if bytes >= 1_048_576     { return String(format: "%.1f MB", bytes / 1_048_576) }
            if bytes >= 1024          { return String(format: "%.1f KB", bytes / 1024) }
            return String(format: "%.0f B", bytes)
        }

        static let zero = BandwidthReading(
            downloadBytesPerSec: 0, uploadBytesPerSec: 0,
            sessionBytesIn: 0, sessionBytesOut: 0,
            packetsIn: 0, packetsOut: 0,
            interface: "en0", timestamp: Date()
        )
    }

    // MARK: - State

    private var previousSnapshot: InterfaceSnapshot?
    private var sessionStartSnapshot: InterfaceSnapshot?

    // MARK: - Public API

    /// Call once at session start to record the baseline
    func recordSessionStart() {
        if let snap = readActiveInterfaceStats() {
            sessionStartSnapshot = snap
            previousSnapshot = snap
        }
    }

    /// Call periodically (every 1-2s) to get the current bandwidth reading
    func measure() -> BandwidthReading {
        guard let current = readActiveInterfaceStats() else {
            return .zero
        }

        var downloadRate: Double = 0
        var uploadRate: Double = 0

        if let prev = previousSnapshot {
            let dt = current.timestamp.timeIntervalSince(prev.timestamp)
            if dt > 0 {
                // ifi_ibytes/ifi_obytes are u_int32_t on Darwin — handle 4 GB wrap
                let dIn  = wrappingDelta(current.bytesIn,  prev.bytesIn)
                let dOut = wrappingDelta(current.bytesOut, prev.bytesOut)
                downloadRate = Double(dIn) / dt
                uploadRate   = Double(dOut) / dt
            }
        }

        let sessionIn:  UInt64
        let sessionOut: UInt64
        if let start = sessionStartSnapshot {
            sessionIn  = current.bytesIn  >= start.bytesIn  ? current.bytesIn  - start.bytesIn  : current.bytesIn
            sessionOut = current.bytesOut >= start.bytesOut ? current.bytesOut - start.bytesOut : current.bytesOut
        } else {
            sessionIn  = 0
            sessionOut = 0
        }

        previousSnapshot = current

        return BandwidthReading(
            downloadBytesPerSec: downloadRate,
            uploadBytesPerSec: uploadRate,
            sessionBytesIn: sessionIn,
            sessionBytesOut: sessionOut,
            packetsIn: current.packetsIn,
            packetsOut: current.packetsOut,
            interface: current.interface,
            timestamp: current.timestamp
        )
    }

    // MARK: - BSD Interface Reading

    /// Detects the active network interface (en0 Wi-Fi → en1 Ethernet → en2/en3 USB-C)
    /// and returns its stats. Mirrors the logic in WiFiInfoService.detectActiveInterface().
    private func readActiveInterfaceStats() -> InterfaceSnapshot? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        let candidates = ["en0", "en1", "en2", "en3"]
        var activeInterface: String? = nil

        // Find the first UP+RUNNING interface with a valid IPv4 address
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            let flags = Int32(iface.ifa_flags)
            guard let ifaAddr = iface.ifa_addr else { continue }
            let name = String(cString: iface.ifa_name)
            guard candidates.contains(name),
                  (flags & (IFF_UP | IFF_RUNNING | IFF_LOOPBACK)) == (IFF_UP | IFF_RUNNING),
                  ifaAddr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let saLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            if getnameinfo(ifaAddr, saLen, &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: hostname)
                if !ip.isEmpty && ip != "0.0.0.0" && !ip.hasPrefix("127.") {
                    activeInterface = name
                    break
                }
            }
        }

        // Fall back to en0 if nothing detected (e.g. simulator)
        return readInterfaceStats(for: activeInterface ?? "en0")
    }

    /// Correct delta accounting for 32-bit BSD counters that wrap at ~4 GB
    private func wrappingDelta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        if current >= previous { return current - previous }
        // Counter wrapped — add the remaining space before wrap plus the new value
        return (UInt64(UInt32.max) + 1 - previous) + current
    }

    private func readInterfaceStats(for interfaceName: String) -> InterfaceSnapshot? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var totalBytesIn:   UInt64 = 0
        var totalBytesOut:  UInt64 = 0
        var totalPacketsIn: UInt64 = 0
        var totalPacketsOut: UInt64 = 0
        var found = false

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = ptr {
            let name = String(cString: addr.pointee.ifa_name)
            if name == interfaceName,
               let ifaAddr = addr.pointee.ifa_addr,
               ifaAddr.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                totalBytesIn   += UInt64(data.pointee.ifi_ibytes)
                totalBytesOut  += UInt64(data.pointee.ifi_obytes)
                totalPacketsIn += UInt64(data.pointee.ifi_ipackets)
                totalPacketsOut += UInt64(data.pointee.ifi_opackets)
                found = true
            }
            ptr = addr.pointee.ifa_next
        }

        guard found else { return nil }

        return InterfaceSnapshot(
            timestamp: Date(),
            bytesIn: totalBytesIn,
            bytesOut: totalBytesOut,
            packetsIn: totalPacketsIn,
            packetsOut: totalPacketsOut,
            interface: interfaceName
        )
    }
}

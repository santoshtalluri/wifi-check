//
//  ScoreCalculator.swift
//  WiFiQualityMonitor
//

import Foundation

/// Calculates WiFi quality scores from raw network metrics
/// Weights: Router 40%, PacketLoss 30%, Internet 20%, DNS 10%
struct ScoreCalculator {

    // MARK: - Public

    static func calculate(from metrics: NetworkMetrics) -> QualityScore {
        let router   = routerSubScore(latency: metrics.routerLatency)
        let loss     = packetLossSubScore(loss: metrics.packetLoss)
        let internet = internetSubScore(latency: metrics.internetLatency)
        let dns      = dnsSubScore(speed: metrics.dnsSpeed)

        let composite = Int(
            Double(router) * 0.40 +
            Double(loss) * 0.30 +
            Double(internet) * 0.20 +
            Double(dns) * 0.10
        )

        let clamped = min(100, max(0, composite))

        return QualityScore(
            composite: clamped,
            routerSubScore: router,
            packetLossSubScore: loss,
            internetSubScore: internet,
            dnsSubScore: dns,
            level: qualityLevel(for: clamped)
        )
    }

    // MARK: - Quality Level

    static func qualityLevel(for score: Int) -> QualityLevel {
        switch score {
        case 80...100: return .excellent
        case 60..<80:  return .good
        case 40..<60:  return .fair
        case 20..<40:  return .poor
        default:       return .veryPoor
        }
    }

    // MARK: - Sub-Scores

    /// Router Latency: <10ms=100, 10-40ms=60-99, 40-100ms=20-59, >100ms=0-19
    static func routerSubScore(latency: Double?) -> Int {
        guard let ms = latency else { return 0 }
        if ms < 10 { return 100 }
        if ms <= 40 { return 60 + Int((40.0 - ms) / 30.0 * 39.0) }
        if ms <= 100 { return 20 + Int((100.0 - ms) / 60.0 * 39.0) }
        return max(0, 19 - Int((ms - 100.0) / 50.0 * 19.0))
    }

    /// Packet Loss: 0%=100, 0-1%=90-99, 1-5%=50-89, 5-15%=10-49, >15%=0-9
    static func packetLossSubScore(loss: Double?) -> Int {
        guard let pct = loss else { return 0 }
        if pct <= 0 { return 100 }
        if pct <= 1 { return 90 + Int((1.0 - pct) * 9.0) }
        if pct <= 5 { return 50 + Int((5.0 - pct) / 4.0 * 39.0) }
        if pct <= 15 { return 10 + Int((15.0 - pct) / 10.0 * 39.0) }
        return max(0, 9 - Int((pct - 15.0) / 10.0 * 9.0))
    }

    /// Internet Latency: <30ms=100, 30-80ms=60-99, 80-150ms=20-59, >150ms=0-19
    static func internetSubScore(latency: Double?) -> Int {
        guard let ms = latency else { return 0 }
        if ms < 30 { return 100 }
        if ms <= 80 { return 60 + Int((80.0 - ms) / 50.0 * 39.0) }
        if ms <= 150 { return 20 + Int((150.0 - ms) / 70.0 * 39.0) }
        return max(0, 19 - Int((ms - 150.0) / 100.0 * 19.0))
    }

    /// DNS Speed: <12ms=100, 12-40ms=60-99, 40-100ms=20-59, >100ms=0-19
    static func dnsSubScore(speed: Double?) -> Int {
        guard let ms = speed else { return 0 }
        if ms < 12 { return 100 }
        if ms <= 40 { return 60 + Int((40.0 - ms) / 28.0 * 39.0) }
        if ms <= 100 { return 20 + Int((100.0 - ms) / 60.0 * 39.0) }
        return max(0, 19 - Int((ms - 100.0) / 50.0 * 19.0))
    }
}

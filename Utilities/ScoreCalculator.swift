//
//  ScoreCalculator.swift
//  WiFiQualityMonitor
//

import Foundation

/// Calculates WiFi quality scores from raw network metrics.
/// 6-metric weights: Throughput 30%, Packet Loss 25%, Jitter 15%,
/// Internet Latency 15%, Router Latency 10%, DNS 5%.
/// When a metric is nil, its weight is redistributed proportionally.
struct ScoreCalculator {

    // MARK: - Public

    static func calculate(from metrics: NetworkMetrics) -> QualityScore {
        // Only compute sub-scores for metrics that have data
        let throughputVal: Int? = metrics.throughput != nil
            ? throughputSubScore(mbps: metrics.throughput) : nil
        let loss: Int? = metrics.packetLoss != nil
            ? packetLossSubScore(loss: metrics.packetLoss) : nil
        let jitterVal: Int? = metrics.jitter != nil
            ? jitterSubScore(jitter: metrics.jitter) : nil
        let internet: Int? = metrics.internetLatency != nil
            ? internetSubScore(latency: metrics.internetLatency) : nil
        let router: Int? = metrics.routerLatency != nil
            ? routerSubScore(latency: metrics.routerLatency) : nil
        let dns: Int? = metrics.dnsSpeed != nil
            ? dnsSubScore(speed: metrics.dnsSpeed) : nil

        // Collect available scores with their base weights
        let available: [(score: Int, baseWeight: Double)] = [
            (throughputVal, 0.30),
            (loss, 0.25),
            (jitterVal, 0.15),
            (internet, 0.15),
            (router, 0.10),
            (dns, 0.05),
        ].compactMap { item in
            guard let s = item.0 else { return nil }
            return (score: s, baseWeight: item.1)
        }

        let composite: Int
        if available.isEmpty {
            composite = 0
        } else {
            // Redistribute weights proportionally among available metrics
            let totalWeight = available.reduce(0.0) { $0 + $1.baseWeight }
            let weightedSum = available.reduce(0.0) { sum, item in
                let normalized = item.baseWeight / totalWeight
                return sum + Double(item.score) * normalized
            }
            composite = min(100, max(0, Int(weightedSum)))
        }

        return QualityScore(
            composite: composite,
            routerSubScore: router ?? -1,
            packetLossSubScore: loss ?? -1,
            internetSubScore: internet ?? -1,
            dnsSubScore: dns ?? -1,
            throughputSubScore: throughputVal ?? -1,
            jitterSubScore: jitterVal ?? -1,
            level: qualityLevel(for: composite)
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

    /// Throughput: >50Mbps=100, 25-50=70-99, 10-25=40-69, 5-10=20-39, <5=0-19
    static func throughputSubScore(mbps: Double?) -> Int {
        guard let speed = mbps else { return 0 }
        if speed >= 50 { return 100 }
        if speed >= 25 { return 70 + Int((speed - 25.0) / 25.0 * 29.0) }
        if speed >= 10 { return 40 + Int((speed - 10.0) / 15.0 * 29.0) }
        if speed >= 5 { return 20 + Int((speed - 5.0) / 5.0 * 19.0) }
        return max(0, Int(speed / 5.0 * 19.0))
    }

    /// Jitter: <5ms=100, 5-15ms=70-99, 15-30ms=40-69, 30-50ms=20-39, >50ms=0-19
    static func jitterSubScore(jitter: Double?) -> Int {
        guard let ms = jitter else { return 0 }
        if ms < 5 { return 100 }
        if ms <= 15 { return 70 + Int((15.0 - ms) / 10.0 * 29.0) }
        if ms <= 30 { return 40 + Int((30.0 - ms) / 15.0 * 29.0) }
        if ms <= 50 { return 20 + Int((50.0 - ms) / 20.0 * 19.0) }
        return max(0, 19 - Int((ms - 50.0) / 30.0 * 19.0))
    }

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

//
//  ScoreCalculator.swift
//  WiFi Check
//
//  6-metric scoring with bottleneck multiplier
//  Weights: Throughput 30%, PacketLoss 25%, Jitter 15%, Internet 15%, Router 10%, DNS 5%

import Foundation

struct ScoreCalculator {

    // MARK: - Weights

    private static let weights: [(keyPath: KeyPath<SubScores, Int?>, weight: Double)] = [
        (\.throughput, 0.30),
        (\.packetLoss, 0.25),
        (\.jitter, 0.15),
        (\.internet, 0.15),
        (\.router, 0.10),
        (\.dns, 0.05),
    ]

    private struct SubScores {
        let throughput: Int?
        let packetLoss: Int?
        let jitter: Int?
        let internet: Int?
        let router: Int?
        let dns: Int?
    }

    // MARK: - Public

    static func calculate(from metrics: NetworkMetrics) -> QualityScore {
        let tp     = metrics.throughput != nil ? throughputSubScore(mbps: metrics.throughput!) : nil
        let loss   = packetLossSubScore(loss: metrics.packetLoss)
        let jit    = metrics.jitter != nil ? jitterSubScore(jitter: metrics.jitter!) : nil
        let inet   = internetSubScore(latency: metrics.internetLatency)
        let router = routerSubScore(latency: metrics.routerLatency)
        let dns    = dnsSubScore(speed: metrics.dnsSpeed)

        let subs = SubScores(
            throughput: tp, packetLoss: loss, jitter: jit,
            internet: inet, router: router, dns: dns
        )

        // Layer 1: Nil-aware weighted average
        let baseScore = weightedAverage(subs)

        // Layer 2: Bottleneck multiplier
        let multiplier = bottleneckMultiplier(throughputSub: tp, packetLossSub: loss)

        // Layer 3: Apply multiplier and clamp
        let finalScore = min(100, max(0, Int(Double(baseScore) * multiplier)))

        return QualityScore(
            composite: finalScore,
            throughputSubScore: tp ?? -1,
            packetLossSubScore: loss ?? 0,
            jitterSubScore: jit ?? -1,
            internetSubScore: inet ?? 0,
            routerSubScore: router ?? 0,
            dnsSubScore: dns ?? 0,
            level: qualityLevel(for: finalScore)
        )
    }

    // MARK: - Weighted Average (nil-aware redistribution)

    private static func weightedAverage(_ subs: SubScores) -> Int {
        var totalWeight: Double = 0
        var totalScore: Double = 0

        for (kp, weight) in weights {
            if let score = subs[keyPath: kp] {
                totalWeight += weight
                totalScore += Double(score) * weight
            }
        }

        guard totalWeight > 0 else { return 0 }
        return Int(totalScore / totalWeight)
    }

    // MARK: - Bottleneck Multiplier

    /// If throughput or packet loss is terrible, the whole score drops
    private static func bottleneckMultiplier(throughputSub: Int?, packetLossSub: Int?) -> Double {
        // Find the worst critical metric
        var worstCritical = 100
        if let tp = throughputSub { worstCritical = min(worstCritical, tp) }
        if let pl = packetLossSub { worstCritical = min(worstCritical, pl) }

        switch worstCritical {
        case 80...100: return 1.0    // No penalty
        case 60..<80:  return 0.9    // Mild
        case 40..<60:  return 0.75   // Moderate
        case 20..<40:  return 0.55   // Significant
        default:       return 0.35   // Severe — score tanks
        }
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

    // MARK: - Throughput Sub-Score
    /// >=100 Mbps=100, 50-100=80-99, 25-50=55-79, 10-25=25-54, 5-10=10-24, <5=0-9

    static func throughputSubScore(mbps: Double) -> Int {
        if mbps >= 100 { return 100 }
        if mbps >= 50  { return 80 + Int((mbps - 50.0)  / 50.0  * 19.0) }
        if mbps >= 25  { return 55 + Int((mbps - 25.0)  / 25.0  * 24.0) }
        if mbps >= 10  { return 25 + Int((mbps - 10.0)  / 15.0  * 29.0) }
        if mbps >= 5   { return 10 + Int((mbps - 5.0)   / 5.0   * 14.0) }
        return max(0, Int(mbps / 5.0 * 9.0))
    }

    // MARK: - Jitter Sub-Score
    /// <5ms=100, 5-15=70-99, 15-30=40-69, 30-50=20-39, >50=0-19

    static func jitterSubScore(jitter: Double) -> Int {
        if jitter < 5  { return 100 }
        if jitter <= 15 { return 70 + Int((15.0 - jitter) / 10.0 * 29.0) }
        if jitter <= 30 { return 40 + Int((30.0 - jitter) / 15.0 * 29.0) }
        if jitter <= 50 { return 20 + Int((50.0 - jitter) / 20.0 * 19.0) }
        return max(0, 19 - Int((jitter - 50.0) / 30.0 * 19.0))
    }

    // MARK: - Packet Loss Sub-Score

    static func packetLossSubScore(loss: Double?) -> Int? {
        guard let pct = loss else { return nil }
        if pct <= 0 { return 100 }
        if pct <= 1 { return 90 + Int((1.0 - pct) * 9.0) }
        if pct <= 5 { return 50 + Int((5.0 - pct) / 4.0 * 39.0) }
        if pct <= 15 { return 10 + Int((15.0 - pct) / 10.0 * 39.0) }
        return max(0, 9 - Int((pct - 15.0) / 10.0 * 9.0))
    }

    // MARK: - Router Latency Sub-Score

    static func routerSubScore(latency: Double?) -> Int? {
        guard let ms = latency else { return nil }
        if ms < 10 { return 100 }
        if ms <= 40 { return 60 + Int((40.0 - ms) / 30.0 * 39.0) }
        if ms <= 100 { return 20 + Int((100.0 - ms) / 60.0 * 39.0) }
        return max(0, 19 - Int((ms - 100.0) / 50.0 * 19.0))
    }

    // MARK: - Internet Latency Sub-Score

    static func internetSubScore(latency: Double?) -> Int? {
        guard let ms = latency else { return nil }
        if ms < 30 { return 100 }
        if ms <= 80 { return 60 + Int((80.0 - ms) / 50.0 * 39.0) }
        if ms <= 150 { return 20 + Int((150.0 - ms) / 70.0 * 39.0) }
        return max(0, 19 - Int((ms - 150.0) / 100.0 * 19.0))
    }

    // MARK: - DNS Sub-Score

    static func dnsSubScore(speed: Double?) -> Int? {
        guard let ms = speed else { return nil }
        if ms < 12 { return 100 }
        if ms <= 40 { return 60 + Int((40.0 - ms) / 28.0 * 39.0) }
        if ms <= 100 { return 20 + Int((100.0 - ms) / 60.0 * 39.0) }
        return max(0, 19 - Int((ms - 100.0) / 50.0 * 19.0))
    }
}

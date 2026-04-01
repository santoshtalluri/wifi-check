//
//  QualityScore.swift
//  WiFiQualityMonitor
//

import SwiftUI

/// Quality level derived from composite score
enum QualityLevel: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case veryPoor = "Very Poor"

    var activityHint: String {
        switch self {
        case .excellent: return "4K streaming, video calls, gaming — all smooth"
        case .good:      return "HD streaming and calls work fine"
        case .fair:      return "Browsing works, video calls may stutter"
        case .poor:      return "Basic browsing only, expect interruptions"
        case .veryPoor:  return "Barely connected — move closer to your router"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return Color(hex: "0A84FF")
        case .good:      return Color(hex: "30D158")
        case .fair:      return Color(hex: "FF9F0A")
        case .poor:      return Color(hex: "FF453A")
        case .veryPoor:  return Color(hex: "FF453A")
        }
    }
}

/// Composite quality score with sub-scores
struct QualityScore {
    let composite: Int              // 0-100
    let routerSubScore: Int         // 0-100
    let packetLossSubScore: Int     // 0-100
    let internetSubScore: Int       // 0-100
    let dnsSubScore: Int            // 0-100
    let throughputSubScore: Int     // 0-100
    let jitterSubScore: Int         // 0-100
    let level: QualityLevel

    /// Whether a sub-score has valid data (-1 means not measured)
    var hasRouterScore: Bool { routerSubScore >= 0 }
    var hasPacketLossScore: Bool { packetLossSubScore >= 0 }
    var hasInternetScore: Bool { internetSubScore >= 0 }
    var hasDnsScore: Bool { dnsSubScore >= 0 }
    var hasThroughputScore: Bool { throughputSubScore >= 0 }
    var hasJitterScore: Bool { jitterSubScore >= 0 }

    static let zero = QualityScore(
        composite: 0,
        routerSubScore: -1,
        packetLossSubScore: -1,
        internetSubScore: -1,
        dnsSubScore: -1,
        throughputSubScore: -1,
        jitterSubScore: -1,
        level: .veryPoor
    )
}

//
//  QualityScore.swift
//  WiFiQualityMonitor
//

import SwiftUI
import Combine

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
    let level: QualityLevel

    static let zero = QualityScore(
        composite: 0,
        routerSubScore: 0,
        packetLossSubScore: 0,
        internetSubScore: 0,
        dnsSubScore: 0,
        level: .veryPoor
    )
}

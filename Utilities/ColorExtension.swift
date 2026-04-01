//
//  ColorExtension.swift
//  WiFiQualityMonitor
//

import SwiftUI

extension Color {
    /// Initialize Color from hex string (e.g. "0A84FF" or "#0A84FF")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Design System Colors
extension Color {
    static let appBackground = Color(hex: "080B14")
    static let glassBackground = Color.white.opacity(0.055)
    static let glassBorder = Color.white.opacity(0.10)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.45)
    static let textTertiary = Color.white.opacity(0.22)

    // Score colors
    static let scoreExcellent = Color(hex: "0A84FF")
    static let scoreGood = Color(hex: "30D158")
    static let scoreFair = Color(hex: "FF9F0A")
    static let scorePoor = Color(hex: "FF453A")

    // State colors
    static let vpnActive = Color(hex: "FF9F0A")
    static let enterprise = Color(hex: "5E5CE6")
    static let publicNetwork = Color(hex: "FF9F0A")
    static let weakSignal = Color(hex: "FF453A")

    // Accent options
    static let accentGreen = Color(hex: "30D158")
    static let accentBlue = Color(hex: "0A84FF")
    static let accentAmber = Color(hex: "FF9F0A")
    static let accentRed = Color(hex: "FF453A")
    static let accentPurple = Color(hex: "BF5AF2")
    static let accentPink = Color(hex: "FF375F")

    static let allAccents: [(name: String, hex: String, color: Color)] = [
        ("Green", "30D158", .accentGreen),
        ("Blue", "0A84FF", .accentBlue),
        ("Amber", "FF9F0A", .accentAmber),
        ("Red", "FF453A", .accentRed),
        ("Purple", "BF5AF2", .accentPurple),
        ("Pink", "FF375F", .accentPink),
    ]
}

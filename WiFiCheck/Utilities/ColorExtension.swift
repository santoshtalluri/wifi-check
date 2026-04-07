//
//  ColorExtension.swift
//  WiFi Check v1
//

import SwiftUI
import UIKit

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

// MARK: - Adaptive Design System Colors (Dark + Light)
extension Color {
    // Background
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.031, green: 0.043, blue: 0.078, alpha: 1) // #080B14
            : UIColor.white
    })

    // Glass card
    static let glassBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.055)
            : UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 0.6) // #F2F2F7 @0.6
    })

    static let glassBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.08)
    })

    // Text
    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1) // #1C1C1E
    })

    static let textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.45)
            : UIColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6) // #3C3C43 @0.6
    })

    static let textTertiary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.22)
            : UIColor.black.withAlphaComponent(0.15)
    })

    // Divider
    static let dividerColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.06)
    })

    // Gauge track
    static let gaugeTrack = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.07)
            : UIColor.black.withAlphaComponent(0.07)
    })

    // Score colors — vibrant in both modes
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

// MARK: - Font Scale Environment Key

private struct AppFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var appFontScale: CGFloat {
        get { self[AppFontScaleKey.self] }
        set { self[AppFontScaleKey.self] = newValue }
    }
}

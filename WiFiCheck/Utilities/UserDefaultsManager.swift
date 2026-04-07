//
//  UserDefaultsManager.swift
//  WiFi Check
//

import Foundation

/// Centralized access to all UserDefaults keys
struct UserDefaultsManager {

    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let updateFrequency = "wqm-update-frequency"
        static let accentColor     = "wqm-accent-color"
        static let fontFamily      = "wqm-font-family"
        static let fontSize        = "wqm-font-size"
    }

    // MARK: - Update Frequency

    /// 5, 15, or 0 (manual). Default: 5
    static var updateFrequency: Int {
        get {
            let val = defaults.integer(forKey: Keys.updateFrequency)
            return val == 0 && !defaults.bool(forKey: "\(Keys.updateFrequency)-set")
                ? 5 : val
        }
        set {
            defaults.set(newValue, forKey: Keys.updateFrequency)
            defaults.set(true, forKey: "\(Keys.updateFrequency)-set")
        }
    }

    // MARK: - Accent Color

    /// Hex string e.g. "30D158". Default: "30D158" (green)
    static var accentColorHex: String {
        get { defaults.string(forKey: Keys.accentColor) ?? "30D158" }
        set { defaults.set(newValue, forKey: Keys.accentColor) }
    }

    // MARK: - Font Family

    /// Raw value of AppFontFamily. Default: "sfpro"
    static var fontFamily: String {
        get { defaults.string(forKey: Keys.fontFamily) ?? "sfpro" }
        set { defaults.set(newValue, forKey: Keys.fontFamily) }
    }

    // MARK: - Font Size

    /// Raw value of AppFontSize ("short", "medium", "large"). Default: "medium"
    static var fontSize: String {
        get { defaults.string(forKey: Keys.fontSize) ?? "medium" }
        set { defaults.set(newValue, forKey: Keys.fontSize) }
    }

}

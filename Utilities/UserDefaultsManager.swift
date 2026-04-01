//
//  UserDefaultsManager.swift
//  WiFiQualityMonitor
//

import Foundation

/// Centralized access to all UserDefaults keys
struct UserDefaultsManager {

    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let updateFrequency = "wqm-update-frequency"
        static let accentColor = "wqm-accent-color"
        static let adsRemoved = "wqm-ads-removed"
        static let appleUserID = "wqm-apple-user-id"
    }

    // MARK: - Update Frequency

    /// 2, 5, or 0 (manual). Default: 2
    static var updateFrequency: Int {
        get {
            let val = defaults.integer(forKey: Keys.updateFrequency)
            return val == 0 && !defaults.bool(forKey: "\(Keys.updateFrequency)-set")
                ? 2 : val
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

    // MARK: - Ads Removed

    static var adsRemoved: Bool {
        get { defaults.bool(forKey: Keys.adsRemoved) }
        set { defaults.set(newValue, forKey: Keys.adsRemoved) }
    }

    // MARK: - Apple User ID

    static var appleUserID: String? {
        get { defaults.string(forKey: Keys.appleUserID) }
        set { defaults.set(newValue, forKey: Keys.appleUserID) }
    }
}

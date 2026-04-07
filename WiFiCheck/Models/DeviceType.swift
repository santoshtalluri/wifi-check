// DeviceType.swift
import Foundation

enum DeviceType: String, Codable, CaseIterable {
    case phone, tablet, laptop, desktop, tv, speaker, printer, router, smartPlug, unknown

    var sfSymbol: String {
        switch self {
        case .phone:     return "iphone"
        case .tablet:    return "ipad"
        case .laptop:    return "laptopcomputer"
        case .desktop:   return "desktopcomputer"
        case .tv:        return "appletv"
        case .speaker:   return "hifispeaker"
        case .printer:   return "printer"
        case .router:    return "wifi.router"
        case .smartPlug: return "lightbulb"
        case .unknown:   return "questionmark.circle"
        }
    }

    var displayName: String {
        switch self {
        case .phone:     return "Phone"
        case .tablet:    return "Tablet"
        case .laptop:    return "Laptop"
        case .desktop:   return "Desktop"
        case .tv:        return "TV"
        case .speaker:   return "Speaker"
        case .printer:   return "Printer"
        case .router:    return "Router"
        case .smartPlug: return "Smart Device"
        case .unknown:   return "Unknown Device"
        }
    }

    var groupName: String {
        switch self {
        case .phone, .tablet:   return "Phones & Tablets"
        case .laptop, .desktop: return "Computers"
        case .tv, .speaker:     return "TVs & Speakers"
        case .router:           return "Network"
        case .printer:          return "Printers"
        case .smartPlug:        return "Smart Home"
        case .unknown:          return "Unknown"
        }
    }

    var groupSortOrder: Int {
        switch self {
        case .phone, .tablet:   return 0
        case .laptop, .desktop: return 1
        case .tv, .speaker:     return 2
        case .router:           return 3
        case .printer:          return 4
        case .smartPlug:        return 5
        case .unknown:          return 6
        }
    }
}

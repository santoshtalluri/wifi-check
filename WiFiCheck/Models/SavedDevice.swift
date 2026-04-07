// SavedDevice.swift
import SwiftData
import Foundation

@Model
final class SavedDevice {
    var id: UUID
    var userLabel: String?
    var hostname: String?
    var lastKnownIP: String?
    var detectedTypeRaw: String?
    var manufacturer: String?
    var firstSeen: Date
    var lastSeen: Date

    init(hostname: String?, ip: String?, type: DeviceType, manufacturer: String?) {
        self.id = UUID()
        self.hostname = hostname
        self.lastKnownIP = ip
        self.detectedTypeRaw = type.rawValue
        self.manufacturer = manufacturer
        self.firstSeen = Date()
        self.lastSeen = Date()
    }

    var detectedType: DeviceType {
        DeviceType(rawValue: detectedTypeRaw ?? "") ?? .unknown
    }

    var displayName: String {
        userLabel ?? hostname ?? lastKnownIP ?? "Unknown Device"
    }

    var isUserLabeled: Bool { userLabel != nil && userLabel?.isEmpty == false }
}

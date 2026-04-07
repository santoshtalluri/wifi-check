// DeviceFingerprintService.swift
// Two-tier device classification:
//   Tier 1 — on-device LLM via FoundationModels (iOS + Apple Intelligence)
//   Tier 2 — structured keyword/pattern matching (always available, tvOS safe)

import Foundation
#if os(iOS)
import FoundationModels
#endif

struct FingerprintResult {
    let deviceType: DeviceType
    let manufacturer: String?
    let confidence: Double // 0.0 – 1.0
}

// MARK: - Generable types (iOS 26+ / Apple Intelligence only)

#if os(iOS)
@available(iOS 26.0, *)
@Generable
struct MLDeviceClassification {
    @Guide(description: "Device type. Must be exactly one of: phone, tablet, laptop, desktop, tv, speaker, printer, router, smartPlug, unknown")
    var deviceType: String

    @Guide(description: "Manufacturer or brand name (e.g. Apple, Samsung, LG, Bosch, Ecobee). Use empty string if unknown.")
    var manufacturer: String
}

@available(iOS 26.0, *)
@Generable
struct MLBatchClassification {
    @Guide(description: "One classification per hostname in the input list, in the same order.")
    var results: [MLDeviceClassification]
}
#endif

// MARK: - Service

struct DeviceFingerprintService {
    static let shared = DeviceFingerprintService()

    // MARK: - Sync (immediate — called by views on every render)

    func fingerprint(hostname: String, mDNSServices: [String] = []) -> FingerprintResult {
        if let r = fingerprintFromMDNS(mDNSServices) { return r }
        if let r = fingerprintFromHostname(hostname) { return r }
        return FingerprintResult(deviceType: .unknown, manufacturer: nil, confidence: 0.0)
    }

    // MARK: - Async ML enrichment (runs once after scan, iOS only)
    // Returns a map of IP → FingerprintResult for devices that were enriched.

    func enrich(_ devices: [NetworkDevice]) async -> [String: FingerprintResult] {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            return await enrichWithML(devices)
        }
        #endif
        return [:]
    }

    // MARK: - Layer 1: mDNS service records (highest confidence)

    private func fingerprintFromMDNS(_ services: [String]) -> FingerprintResult? {
        for service in services {
            switch service {
            case "_airplay._tcp":
                return FingerprintResult(deviceType: .tv, manufacturer: "Apple", confidence: 0.95)
            case "_raop._tcp":
                return FingerprintResult(deviceType: .speaker, manufacturer: "Apple", confidence: 0.95)
            case "_apple-mobdev2._tcp":
                return FingerprintResult(deviceType: .phone, manufacturer: "Apple", confidence: 0.95)
            case "_googlecast._tcp":
                return FingerprintResult(deviceType: .tv, manufacturer: "Google", confidence: 0.92)
            case "_ipp._tcp", "_printer._tcp", "_pdl-datastream._tcp":
                return FingerprintResult(deviceType: .printer, manufacturer: nil, confidence: 0.92)
            case "_ssh._tcp", "_sftp-ssh._tcp":
                return FingerprintResult(deviceType: .desktop, manufacturer: nil, confidence: 0.80)
            case "_http._tcp":
                return FingerprintResult(deviceType: .router, manufacturer: nil, confidence: 0.60)
            default:
                break
            }
        }
        return nil
    }

    // MARK: - Layer 2: Hostname parsing (improved fallback, always available)

    private func fingerprintFromHostname(_ hostname: String) -> FingerprintResult? {
        let h = hostname.lowercased()
        guard !h.isEmpty else { return nil }

        // Step A: extract manufacturer prefix (e.g. "LG-Dryer-A4B2" → manufacturer=LG, rest="dryer-a4b2")
        let (manufacturer, remainder) = extractManufacturerPrefix(h)
        let searchIn = remainder ?? h

        // Step B: scan for device-type keywords in the remainder (and full hostname)
        if let result = matchTypeKeyword(in: searchIn, fullHostname: h, manufacturer: manufacturer) {
            return result
        }

        // Step C: specific model/pattern matching
        if let result = matchSpecificPatterns(h, manufacturer: manufacturer) {
            return result
        }

        // Step D: manufacturer-only default (when no type keyword was found)
        if let manufacturer = manufacturer,
           let (defaultType, conf) = Self.manufacturerOnlyDefaults[manufacturer.lowercased()] {
            return FingerprintResult(deviceType: defaultType, manufacturer: manufacturer, confidence: conf)
        }

        return nil
    }

    // MARK: - Manufacturer prefix extractor

    /// Tries to match a known manufacturer at the start of the hostname.
    /// Returns (displayName, remainder) where remainder is the part after "Manufacturer-" or "Manufacturer ".
    private func extractManufacturerPrefix(_ h: String) -> (String?, String?) {
        for (prefix, displayName) in Self.manufacturerPrefixes {
            if h.hasPrefix(prefix + "-") {
                let rest = String(h.dropFirst(prefix.count + 1))
                return (displayName, rest.isEmpty ? nil : rest)
            }
            if h.hasPrefix(prefix + " ") {
                let rest = String(h.dropFirst(prefix.count + 1))
                return (displayName, rest.isEmpty ? nil : rest)
            }
            if h == prefix {
                return (displayName, nil)
            }
        }
        return (nil, nil)
    }

    // MARK: - Type keyword matcher

    private func matchTypeKeyword(in text: String, fullHostname: String, manufacturer: String?) -> FingerprintResult? {
        // Handle TV — require whole-word match to avoid false positives (e.g. "activate")
        let tvPatterns = ["-tv", " tv", "tv-", "tv ", ".tv"]
        if fullHostname.hasPrefix("tv") || fullHostname.hasSuffix("tv")
            || tvPatterns.contains(where: { fullHostname.contains($0) }) {
            return FingerprintResult(deviceType: .tv, manufacturer: manufacturer, confidence: manufacturer != nil ? 0.88 : 0.80)
        }

        // Handle "galaxy" — disambiguate phone vs tablet
        if text.contains("galaxy") {
            let type: DeviceType = text.contains("tab") ? .tablet : .phone
            return FingerprintResult(deviceType: type, manufacturer: manufacturer ?? "Samsung", confidence: 0.82)
        }

        // Handle "switch" — Nintendo console vs network switch
        if text.contains("switch") {
            if text.contains("nintendo") || fullHostname.contains("nintendo") {
                return FingerprintResult(deviceType: .desktop, manufacturer: "Nintendo", confidence: 0.85)
            }
            if text.contains("net") || text.contains("cisco") || text.contains("unifi") {
                return FingerprintResult(deviceType: .router, manufacturer: manufacturer, confidence: 0.75)
            }
            return nil // ambiguous — let ML or manufacturer default handle it
        }

        // Flat keyword table scan
        for (keyword, type) in Self.typeKeywords {
            if text.contains(keyword) {
                let confidence: Double = manufacturer != nil ? 0.88 : 0.80
                return FingerprintResult(deviceType: type, manufacturer: manufacturer, confidence: confidence)
            }
        }

        return nil
    }

    // MARK: - Specific model/pattern matching

    private func matchSpecificPatterns(_ h: String, manufacturer: String?) -> FingerprintResult? {
        // Apple
        if h.contains("iphone") || h.contains("ipod") {
            return FingerprintResult(deviceType: .phone, manufacturer: "Apple", confidence: 0.92)
        }
        if h.contains("ipad") {
            return FingerprintResult(deviceType: .tablet, manufacturer: "Apple", confidence: 0.92)
        }
        if h.contains("macbook") {
            return FingerprintResult(deviceType: .laptop, manufacturer: "Apple", confidence: 0.92)
        }
        if h.contains("imac") || h.contains("mac-") || h.contains("mac pro") || h.contains("mac mini") || h == "mac" {
            return FingerprintResult(deviceType: .desktop, manufacturer: "Apple", confidence: 0.88)
        }
        if h.contains("appletv") || h.contains("apple-tv") {
            return FingerprintResult(deviceType: .tv, manufacturer: "Apple", confidence: 0.95)
        }
        if h.contains("homepod") {
            return FingerprintResult(deviceType: .speaker, manufacturer: "Apple", confidence: 0.95)
        }
        // Android
        if h.contains("android") || h.contains("pixel") {
            return FingerprintResult(deviceType: .phone, manufacturer: manufacturer, confidence: 0.82)
        }
        // Windows computers
        if h.contains("desktop-") || (h.contains("windows") && !h.contains("server")) {
            return FingerprintResult(deviceType: .desktop, manufacturer: manufacturer, confidence: 0.80)
        }
        if h.contains("thinkpad") || h.contains("xps") || h.contains("inspiron")
            || h.contains("pavilion") || h.contains("elitebook") || h.contains("latitude") {
            return FingerprintResult(deviceType: .laptop, manufacturer: manufacturer, confidence: 0.82)
        }
        // Smart TVs / streamers
        if h.contains("firetv") || h.contains("fire-tv") || (h.contains("amazon") && h.contains("tv")) {
            return FingerprintResult(deviceType: .tv, manufacturer: "Amazon", confidence: 0.88)
        }
        if h.contains("chromecast") {
            return FingerprintResult(deviceType: .tv, manufacturer: "Google", confidence: 0.90)
        }
        if h.contains("tizen") || (h.contains("samsung") && h.contains("tv")) {
            return FingerprintResult(deviceType: .tv, manufacturer: "Samsung", confidence: 0.88)
        }
        if matchesSamsungTVModel(h) {
            return FingerprintResult(deviceType: .tv, manufacturer: "Samsung", confidence: 0.75)
        }
        if h.contains("webos") {
            return FingerprintResult(deviceType: .tv, manufacturer: "LG", confidence: 0.85)
        }
        if h.contains("sony-bravia") || h.contains("bravia") || h.hasPrefix("xbr") || h.hasPrefix("kd-") {
            return FingerprintResult(deviceType: .tv, manufacturer: "Sony", confidence: 0.85)
        }
        if h.contains("vizio") {
            return FingerprintResult(deviceType: .tv, manufacturer: "Vizio", confidence: 0.85)
        }
        // Smart speakers
        if h.contains("echo") || h.contains("alexa") {
            return FingerprintResult(deviceType: .speaker, manufacturer: "Amazon", confidence: 0.88)
        }
        if h.contains("wha") {
            return FingerprintResult(deviceType: .speaker, manufacturer: manufacturer, confidence: 0.72)
        }
        // HP printers — "HP" + 6 hex chars from MAC (e.g. HPC36B44)
        if matchesHPPrinterHostname(h) {
            return FingerprintResult(deviceType: .printer, manufacturer: "HP", confidence: 0.80)
        }
        // Gaming consoles
        if h.contains("xbox") {
            return FingerprintResult(deviceType: .desktop, manufacturer: "Microsoft", confidence: 0.88)
        }
        if h.contains("playstation") || h.contains("ps4") || h.contains("ps5") || h.hasPrefix("ps-") {
            return FingerprintResult(deviceType: .desktop, manufacturer: "Sony", confidence: 0.88)
        }
        if h.contains("nintendo") {
            return FingerprintResult(deviceType: .desktop, manufacturer: "Nintendo", confidence: 0.82)
        }
        // NAS / servers
        if h.contains("synology") || h.contains("qnap") || h.contains("mycloud") || h.contains("readynas") {
            return FingerprintResult(deviceType: .desktop, manufacturer: manufacturer, confidence: 0.80)
        }

        return nil
    }

    // MARK: - Static keyword / lookup tables

    private static let typeKeywords: [(String, DeviceType)] = [
        // Phones
        ("iphone", .phone), ("android", .phone), ("pixel", .phone),
        // Tablets
        ("ipad", .tablet),
        // Laptops
        ("macbook", .laptop), ("laptop", .laptop), ("thinkpad", .laptop),
        ("surface", .laptop), ("xps", .laptop), ("inspiron", .laptop),
        ("pavilion", .laptop), ("elitebook", .laptop), ("latitude", .laptop),
        // Desktops
        ("imac", .desktop), ("desktop", .desktop),
        // TVs & streamers
        ("appletv", .tv), ("firetv", .tv), ("chromecast", .tv),
        ("roku", .tv), ("tizen", .tv), ("webos", .tv), ("bravia", .tv), ("vizio", .tv),
        // Speakers
        ("homepod", .speaker), ("sonos", .speaker), ("echo", .speaker),
        ("alexa", .speaker), ("soundbar", .speaker),
        // Printers
        ("printer", .printer), ("laserjet", .printer), ("pixma", .printer),
        ("officejet", .printer), ("deskjet", .printer), ("pagewide", .printer),
        ("envy", .printer), ("mfp", .printer), ("scanner", .printer),
        // Routers / network
        ("router", .router), ("gateway", .router), ("eero", .router),
        ("orbi", .router), ("nighthawk", .router), ("velop", .router),
        ("amplifi", .router), ("unifi", .router), ("ubiquiti", .router),
        ("deco", .router), ("mesh", .router),
        // Smart home & appliances
        ("thermostat", .smartPlug), ("doorbell", .smartPlug),
        ("camera", .smartPlug), ("vacuum", .smartPlug), ("roomba", .smartPlug),
        ("washer", .smartPlug), ("dryer", .smartPlug), ("laundry", .smartPlug),
        ("dishwasher", .smartPlug), ("refrigerator", .smartPlug),
        ("fridge", .smartPlug), ("freezer", .smartPlug),
        ("oven", .smartPlug), ("microwave", .smartPlug),
        ("blinds", .smartPlug), ("shade", .smartPlug), ("curtain", .smartPlug),
        ("garage", .smartPlug), ("motion", .smartPlug), ("alarm", .smartPlug),
        ("hue", .smartPlug), ("lifx", .smartPlug), ("kasa", .smartPlug),
        ("wemo", .smartPlug), ("shelly", .smartPlug), ("tasmota", .smartPlug),
        ("tuya", .smartPlug), ("wyze", .smartPlug),
        ("ring", .smartPlug), ("nest", .smartPlug), ("ecobee", .smartPlug),
        ("plug", .smartPlug),
    ]

    private static let manufacturerPrefixes: [(String, String)] = [
        ("apple", "Apple"), ("samsung", "Samsung"), ("lg", "LG"), ("sony", "Sony"),
        ("google", "Google"), ("amazon", "Amazon"), ("microsoft", "Microsoft"),
        ("hp", "HP"), ("canon", "Canon"), ("epson", "Epson"), ("brother", "Brother"),
        ("ricoh", "Ricoh"), ("xerox", "Xerox"), ("kyocera", "Kyocera"), ("konica", "Konica"),
        ("bosch", "Bosch"), ("whirlpool", "Whirlpool"), ("ge", "GE"), ("maytag", "Maytag"),
        ("electrolux", "Electrolux"), ("miele", "Miele"), ("frigidaire", "Frigidaire"),
        ("nest", "Nest"), ("ring", "Ring"), ("arlo", "Arlo"), ("eufy", "Eufy"),
        ("wyze", "Wyze"), ("ecobee", "Ecobee"), ("honeywell", "Honeywell"),
        ("philips", "Philips"), ("lifx", "LIFX"), ("kasa", "Kasa"), ("wemo", "Wemo"),
        ("shelly", "Shelly"), ("sonos", "Sonos"), ("bose", "Bose"), ("denon", "Denon"),
        ("yamaha", "Yamaha"), ("marantz", "Marantz"), ("jbl", "JBL"),
        ("netgear", "Netgear"), ("asus", "Asus"), ("linksys", "Linksys"),
        ("tplink", "TP-Link"), ("tp-link", "TP-Link"), ("mikrotik", "MikroTik"),
        ("cisco", "Cisco"), ("ubiquiti", "Ubiquiti"), ("aruba", "Aruba"),
        ("nintendo", "Nintendo"), ("roku", "Roku"), ("vizio", "Vizio"),
        ("toshiba", "Toshiba"), ("panasonic", "Panasonic"),
        ("hisense", "Hisense"), ("tcl", "TCL"),
    ]

    /// When only a manufacturer prefix is recognized and no type keyword follows.
    private static let manufacturerOnlyDefaults: [String: (DeviceType, Double)] = [
        "hp":         (.printer,   0.70),
        "canon":      (.printer,   0.78),
        "epson":      (.printer,   0.78),
        "brother":    (.printer,   0.78),
        "ricoh":      (.printer,   0.75),
        "xerox":      (.printer,   0.75),
        "kyocera":    (.printer,   0.75),
        "lg":         (.tv,        0.75),
        "hisense":    (.tv,        0.75),
        "tcl":        (.tv,        0.75),
        "vizio":      (.tv,        0.80),
        "toshiba":    (.tv,        0.72),
        "panasonic":  (.tv,        0.72),
        "sonos":      (.speaker,   0.88),
        "bose":       (.speaker,   0.78),
        "denon":      (.speaker,   0.75),
        "marantz":    (.speaker,   0.75),
        "jbl":        (.speaker,   0.75),
        "roku":       (.tv,        0.90),
        "ring":       (.smartPlug, 0.82),
        "arlo":       (.smartPlug, 0.85),
        "eufy":       (.smartPlug, 0.82),
        "ecobee":     (.smartPlug, 0.88),
        "honeywell":  (.smartPlug, 0.72),
        "netgear":    (.router,    0.78),
        "ubiquiti":   (.router,    0.85),
        "mikrotik":   (.router,    0.85),
        "cisco":      (.router,    0.82),
        "aruba":      (.router,    0.82),
        "nintendo":   (.desktop,   0.82),
    ]

    // MARK: - Helpers

    private func matchesSamsungTVModel(_ h: String) -> Bool {
        let prefixes = ["ks", "ku", "nu", "ru", "tu", "au", "bu", "cu", "du", "qu", "qn", "un"]
        for prefix in prefixes {
            if h.hasPrefix(prefix) {
                let rest = h.dropFirst(prefix.count)
                if let first = rest.first, (first.isNumber || first.isLetter), rest.count >= 3,
                   rest.allSatisfy({ $0.isNumber || $0.isLetter }) {
                    return true
                }
            }
        }
        return false
    }

    private func matchesHPPrinterHostname(_ h: String) -> Bool {
        guard h.hasPrefix("hp") else { return false }
        let suffix = h.dropFirst(2)
        let hexOnly = suffix.replacingOccurrences(of: "-", with: "")
        return hexOnly.count >= 6 && hexOnly.allSatisfy({ $0.isHexDigit })
    }
}

// MARK: - ML enrichment (iOS 26+ / Apple Intelligence)

#if os(iOS)
extension DeviceFingerprintService {
    @available(iOS 26.0, *)
    private func enrichWithML(_ devices: [NetworkDevice]) async -> [String: FingerprintResult] {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return [:] }

        // Only enrich devices where sync classification was low-confidence
        let candidates = devices.filter { d in
            guard !d.isThisDevice, !d.isGateway else { return false }
            guard !d.hostname.hasPrefix("Device ("), !d.hostname.isEmpty else { return false }
            let fp = fingerprint(hostname: d.hostname, mDNSServices: d.mDNSServices)
            return fp.confidence < 0.85
        }
        guard !candidates.isEmpty else { return [:] }

        let list = candidates.enumerated()
            .map { "\($0.offset + 1). \($0.element.hostname)" }
            .joined(separator: "\n")

        let session = LanguageModelSession(instructions: Instructions("""
            Classify network device hostnames for a home network scanner.
            Use only these device types: phone, tablet, laptop, desktop, tv, speaker, printer, router, smartPlug, unknown
            Hostnames follow patterns like "Manufacturer-DeviceType-XXXX".
            Appliances (washer, dryer, dishwasher, fridge, oven, thermostat, camera, lock, vacuum, blinds, etc.) → smartPlug.
            Gaming consoles (Xbox, PlayStation, Nintendo Switch) → desktop.
            """))

        do {
            let response = try await session.respond(
                to: "Classify these device hostnames:\n\(list)",
                generating: MLBatchClassification.self
            )
            let classifications = response.content.results
            var enriched: [String: FingerprintResult] = [:]
            for (idx, device) in candidates.enumerated() {
                guard idx < classifications.count else { break }
                let c = classifications[idx]
                guard let type = DeviceType(rawValue: c.deviceType) else { continue }
                let mfr = c.manufacturer.trimmingCharacters(in: .whitespaces)
                enriched[device.ip] = FingerprintResult(
                    deviceType: type,
                    manufacturer: mfr.isEmpty ? nil : mfr,
                    confidence: 0.90
                )
            }
            return enriched
        } catch {
            return [:]
        }
    }
}
#endif

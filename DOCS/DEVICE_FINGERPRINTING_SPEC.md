# Device Fingerprinting & Naming — Feature Spec v0.3

## Summary
Allow users to identify, name, and remember network devices across scans. Works on both iOS and tvOS.

---

## Scope
- **Platforms:** iOS + tvOS (built simultaneously)
- **Target version:** v0.3 (pre-release, internal)

---

## Device List (Network Scan Tab)
- Shows only devices **currently online** in active scan
- No offline / historical devices shown
- Each row displays:
  - Device type icon (SF Symbols, iOS/tvOS native)
  - Friendly name (user-assigned) OR auto-identified name OR "Unknown Device"
  - IP address
  - Manufacturer chip (from OUI)
- Tap any row → **pushes detail screen** (navigation push within tab)

---

## Device Detail Screen (Navigation Push)
**Read mode:**
| Field | Source |
|---|---|
| Friendly name | User-assigned or auto-detected |
| MAC address | Scan result (note: Apple devices rotate MACs) |
| IP address | Scan result |
| Manufacturer | MAC OUI offline database |
| Device type | Fingerprint engine (see below) |
| First seen | SwiftData timestamp |
| Last seen | Current scan time (if online) |

**Edit mode:**
- Tap name field → becomes editable text input
- ✓ checkmark (SF Symbol: `checkmark.circle.fill`) → save
- ✕ cancel (SF Symbol: `xmark.circle.fill`) → discard
- tvOS: uses focus engine + remote for editing

---

## Fingerprinting Engine (4 Layers)

### Layer 1 — mDNS Service Discovery (highest confidence)
Bonjour service → device type mapping:
| mDNS Service | Device Type |
|---|---|
| `_airplay._tcp` | Apple TV / HomePod |
| `_apple-mobdev2._tcp` | iPhone / iPad |
| `_googlecast._tcp` | Chromecast / Google Home |
| `_ipp._tcp` | Printer |
| `_ssh._tcp` | Computer / Server / NAS |
| `_http._tcp` | Router / Smart Device |
| `_raop._tcp` | AirPlay speaker |

### Layer 2 — MAC OUI Database (offline, bundled ~2MB)
- First 3 bytes of MAC → manufacturer name
- Bundled offline JSON, zero network calls, fully private
- ⚠️ Apple devices: MAC is randomized (iOS 14+) — use Layer 1 for Apple ID

### Layer 3 — Hostname Pattern Matching
| Pattern | Device |
|---|---|
| `iPhone`, `iPad`, `iPod` | Apple mobile |
| `MacBook`, `iMac`, `Mac-` | Apple computer |
| `AppleTV` | Apple TV |
| `DESKTOP-`, `LAPTOP-` | Windows PC |
| `android`, `Galaxy`, `Pixel` | Android |
| `ring`, `nest`, `hue`, `tplink` | IoT / smart home |

### Layer 4 — CoreML On-device Classifier (fallback)
- Runs only when layers 1-3 produce low confidence
- Small bundled model, no data leaves device
- Input: hostname, OUI manufacturer, mDNS services, port patterns
- Output: device type + confidence score

**Confidence threshold:** Only show auto-identified type if score > 70%. Below that → "Unknown Device."

---

## Persistence (SwiftData)
```swift
@Model class SavedDevice {
    var id: UUID
    var userLabel: String?           // user-assigned name
    var hostname: String?            // primary lookup key
    var lastKnownMAC: String?        // fallback key (may rotate on Apple devices)
    var lastKnownIP: String?
    var detectedType: DeviceType?    // Phone, Laptop, TV, Printer, Router, SmartPlug, Unknown
    var manufacturer: String?
    var firstSeen: Date
    var lastSeen: Date
}
```

**Lookup priority:** hostname (primary) → MAC (fallback for non-Apple)

---

## Device Type Icons (SF Symbols — iOS & tvOS native)
| Type | SF Symbol |
|---|---|
| Phone | `iphone` |
| Tablet | `ipad` |
| Laptop | `laptopcomputer` |
| Desktop | `desktopcomputer` |
| TV | `appletv` |
| Speaker | `hifispeaker` |
| Printer | `printer` |
| Router | `wifi.router` |
| Smart plug / IoT | `lightbulb` |
| Unknown | `questionmark.circle` |

---

## What Will NOT Change
- TabRootView, WiFiInfoTab, SpeedTestTab, SettingsView — zero modifications
- Existing NetworkScanTab layout — only additive (tap handler + icon + chip)
- All 123 existing UI tests remain intact

## New Test Cases (Added automatically)
- Unit: OUILookupService — MAC → manufacturer mapping
- Unit: HostnamePatternMatcher — pattern → device type
- Unit: FingerprintEngine — layer priority + confidence scoring
- UI: Device row tap → detail screen push
- UI: Edit name → save (checkmark) → persists
- UI: Edit name → cancel (X) → discards
- UI: Unknown device shows correct icon + label
- UI: Named device shows user label + "You named this" badge

---

## Open Items / Notes
- CoreML model: evaluate using Create ML with synthetic training data; can ship without if accuracy insufficient
- tvOS: focus engine navigation for detail screen editing needs separate testing pass
- mDNS scanning: verify entitlements (Local Network permission already in app)

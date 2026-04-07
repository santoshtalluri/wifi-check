# WiFiCheck Changelog

## v0.3 (In Progress — April 2026)

### UI & Preferences (April 7, 2026)

#### Theme Selector
- **System / Light / Dark theme** — new 3-pill selector in the Preferences card, between Refresh Cycle and Accent Color. Stored via `@AppStorage("wqm-color-scheme")`. Applied with `.preferredColorScheme()` at `TabView` level — affects only this app, not the system.

#### Font Preferences Consolidation
- **Merged Font Preferences into Preferences card** — Font Family and Font Size rows moved inside the Preferences card; the standalone "Font Preferences" `GlassCard` removed to save screen real estate.
- **App-wide font scaling** — All views now subscribe directly to `@AppStorage("wqm-font-size")` rather than relying on environment propagation. Ensures immediate scale update on all tabs regardless of whether the tab is currently visible.
- **Font family bottom-sheet picker** — `FontFamilyPickerSheet` replaces inline expand/collapse. Opens at a fixed detent height; each option renders in its own typeface. Eliminates scroll-view layout shift when toggling the dropdown.
- **Tab bar font scaling** — `UITabBarAppearance` updated via `UITabBar` view-hierarchy walk whenever font size changes, so the tab bar labels scale instantly alongside the rest of the app.

#### Visual Hierarchy
- **Section header backgrounds** — All 5 card section headers (Metrics, Network Info, Network Scan, Preferences, About) now have a consistent tinted background (`Color.textSecondary.opacity(0.08)`) to visually separate headers from content rows. Implemented using a negative-padding breakout technique.
- **`GlassCard` clip shape** — Added `.clipShape(RoundedRectangle(cornerRadius: 22))` so header backgrounds are correctly clipped to the card's rounded corners.

#### Pill Selection Contrast
- Selected pills in Refresh Cycle, Theme, and Font Size selectors now use `Color.primary` (black in light mode, white in dark mode) with `.bold` weight. Eliminates the light-on-light contrast failure when light theme is active.
- Removed accent-color dependency from selected pill text — contrast is now correct for all 6 accent color choices and both themes.

#### Font Size Tile Height
- Font size tile `.padding(.vertical)` reduced from `14` to `8`; `tileHeight` reduced from `24` to `20`. Total tile height now matches Refresh Cycle and Theme pill row height (~36 pt vs prior ~52 pt).

### Network Scan Improvements (April 7, 2026)
- **ARP-based MAC address enrichment** — after scan completes, `readARPCache(subnet:)` reads the kernel ARP table via `sysctl(NET_RT_FLAGS)` and populates `device.mac` on each `NetworkDevice`.
- **Randomized MAC detection** — `isRandomizedMAC` checks the locally-administered bit (bit 1 of the first MAC octet) to flag iOS/Android/Windows privacy-mode devices.

### Device Detail View (April 7, 2026)
- Removed unreliable fields: **MAC Address** (ARP data unreliable in practice), **First Seen**, **Last Seen**.
- Retained fields: IP Address, Hostname, Manufacturer, Device Type.

---

### Bug Fixes
- **Sign in with Apple button unresponsive** — replaced `.cornerRadius()` with `.clipShape()`, added `.allowsHitTesting(true)` and `.contentShape(Rectangle())` in `SettingsView.swift`. This was the Apple Review rejection reason.
- **Force cast crash risk** — replaced `as! [String: String]` with safe two-step fallback in `NetworkScanService.swift`
- **Broken Rate App URL** — updated placeholder `id000000000` to real App ID `6761551872` in `SettingsView.swift`
- **WiFi name blank on home screen** — `NSLocationWhenInUseUsageDescription` was missing from `Info.plist`, causing iOS to silently ignore `requestWhenInUseAuthorization()`. Added the key with a user-facing explanation string.
- **Download speed stuck at ~30 Mbps on fast connections** — the 200 KB probe was dominated by HTTPS handshake overhead on connections faster than ~50 Mbps. Increased probe size to 5 MB and timeout to 15 s in `ThroughputService.swift`.

### Removed
- **Sign in with Apple** — removed entirely (`SettingsView.swift`, `UserDefaultsManager.swift`, UITests). StoreKit restores purchases using the device Apple ID; a separate sign-in flow adds no value.

### New Features
- **Upload Speed measurement** — `ThroughputService.measureUploadThroughput()` POSTs 3 MB to `speed.cloudflare.com/__up`. Runs concurrently with the 6 existing measurements. Displayed as a new always-visible row ("Upload Speed") in the Metrics card (card now shows 4 of 7 by default).
- **ISP name & city** — fetched once per session from `ipinfo.io/json` (no API key required, 50K/month free). Shown in the expanded Network Info card as e.g. "Comcast Cable · San Jose, CA".
- **DNS servers in use** — reads `/etc/resolv.conf`; labels well-known resolvers (Google, Cloudflare, Quad9, OpenDNS). Shown in expanded Network Info card.
- **Local IPv6 address** — reads `en0` via `getifaddrs`; link-local (fe80::) addresses filtered out. Shown in expanded Network Info card only when a global IPv6 address exists.
- **Router manufacturer** — OUI lookup on the BSSID (using the existing `OUILookupService`). Shown as a new always-visible "Router" row in the Network Info card (e.g. "Netgear", "Asus", "TP-Link"). Only displayed when the manufacturer is identified.
- **Score Info Sheet** — tapping the `ⓘ` icon on the Gauge card opens a compact non-scrolling sheet explaining the scoring formula. Includes score range table, 6-metric weights, and a "Contact Support" button that opens the Support sheet with "Got a question" pre-expanded.
- **Manual mode UX** — footer text updated to "Manual mode — pull down to refresh". Pull-to-refresh gesture added (`ScrollView.refreshable`). Manual refresh icon (`arrow.clockwise`) appears in the Gauge card header only when refresh is set to Manual.
- **GaugeCard header redesign** — SSID is centred in a `ZStack`; `ⓘ` icon pinned to the left, refresh icon (manual only) pinned to the right.
- **Download speed scoring updated** — thresholds raised to match modern connections: ≥100 Mbps = 100, linear interpolation below that. Previously capped at 50 Mbps.

### Network Scan Improvements
- **Real device name** — uses `ProcessInfo.processInfo.hostName` (e.g. "Santosh-iPhoneMaxx.local" → "Santosh iPhoneMaxx") instead of `UIDevice.current.name` which returns the generic "iPhone" on iOS 16+ for privacy.
- **"You" device pinned at top** — always rendered as a standalone accented row with a green `you` pill badge above all other content in both list and grouped modes.
- **Routers group** — gateway labelled "Router" (was "Router / Gateway"). All router-type devices grouped under **Routers** pinned first. Gateway shows "Router" badge; additional router-type devices show "Mesh Node" badge.
- **List / Group view toggle** — icon buttons (`list.bullet` / `rectangle.3.group`) appear in the scan card header after a scan completes. Selection persists via `@AppStorage`.
- **Default view is List** — flat list of all devices with dividers, no section headers. Simpler to scroll through.
- **Collapsible groups** — in grouped mode, each section has a tappable header with a chevron that rotates on collapse. All groups start expanded; collapsed state is reset on each new scan.
- **Group container styling** — each group is wrapped in a rounded-corner container with a tinted background (slightly darker when collapsed) and a thin border, making collapsed sections visually distinct from expanded ones and from the card background.
- **New flags on `NetworkDevice`** — `isThisDevice: Bool` and `isGateway: Bool` added to the model; used for deterministic UI placement and role badges.

### Device Naming & Fingerprinting
- Users can name unknown devices on their network. Names persist across scans using SwiftData, keyed by hostname. 4-layer fingerprinting: mDNS → MAC OUI → hostname patterns → hostname-based fallback. Implemented for both iOS and tvOS. New files: `DeviceType.swift`, `SavedDevice.swift` (SwiftData model), `OUILookupService.swift` (~500-entry OUI database), `DeviceFingerprintService.swift`, `DeviceDetailView.swift`.

### tvOS App — UI Parity Fixes (April 7, 2026)
- **[tvOS] Theme selector** — 3-pill row (System/Light/Dark) added to `TVSettingsView` between Refresh Cycle and Accent Color. `@AppStorage("wqm-color-scheme")` shared key. `.preferredColorScheme(activeColorScheme)` applied to `TabView` in `WiFiCheckTVApp.swift`
- **[tvOS] Refresh pill contrast fix** — selected text in `frequencyButton` changed from hardcoded `.white` to `Color.primary` (adaptive black/white) with `.bold` weight; same pattern applied to new `themeButton`
- **[tvOS] `TVDeviceDetailView` bug fix** — removed `mac:` parameter from `DeviceFingerprintService.fingerprint()` call (parameter does not exist on the shared service); removed MAC Address row (was a compiler type error: `device.mac` is non-optional `String`, `??` operator invalid)
- **[tvOS] Device detail fields** — now shows only: IP Address, Hostname, Manufacturer, Device Type (matches iOS)

### tvOS App (New Platform — Apple TV)
- **New target: `Wi​Fi​Check ​TV`** — full tvOS companion app sharing all model/service/utility code with the iOS target via `PBXFileSystemSynchronizedRootGroup`
- **5-tab layout** — Dashboard, Bandwidth, Speed Test, Network Scan, Settings; all optimised for 10-foot TV viewing with large fonts and focus-based navigation
- **Dashboard** — proportional `WeightedHStack` layout with TVGaugeCard, TVMetricsGrid, TVScoreBreakdown, TVNetworkInfoCard, TVNetworkPathView, TVActivityRecommendations
- **Score Breakdown legend** — compact color key (Green ≥80, Blue 60-79, Orange 40-59, Red <40) and weight footnote ("Throughput 30 · Latency 25 · Packet Loss 20 · Jitter 15 · DNS 10") added to TVScoreBreakdown
- **Bandwidth Monitor** — `DeviceBandwidthService` uses BSD `getifaddrs()` + `if_data` for real-time per-interface download/upload rates; sparklines, session totals, packet counts, peak records
- **SSID resolution** — `WiFiSSIDHelper` ObjC shim (`NSClassFromString` + `objc_msgSend`) bypasses `NEHotspotNetwork` compile-time `API_UNAVAILABLE(tvos)` to fetch SSID at runtime. Requires `com.apple.developer.networking.wifi-info` entitlement + CoreLocation permission
- **Dynamic interface detection** — `detectActiveInterface()` probes `en0→en1→en2→en3` in priority order, picks the first UP+RUNNING interface with a valid IPv4 address. Covers WiFi (`en0`), built-in Ethernet (`en1`), and USB-C LAN adapters (`en2+`)
- **Connection type display** — `WiFiInfo` gains `connectionType` (`"Wi-Fi"` / `"Ethernet"` / `"USB-C LAN"`) and `activeInterface` fields. TVNetworkInfoCard shows the live connection type and hides the SSID row for wired connections
- **Clean SSID fallback** — fallback chain: NEHotspotNetwork → UPnP router friendly-name → `"Wi-Fi Network"`. Gateway IP is never exposed in the network name field
- **ObjC bridging header** — `WiFiCheckTV-Bridging-Header.h` imports `WiFiSSIDHelper.h`; `SWIFT_OBJC_BRIDGING_HEADER` set in both Debug and Release build configs
- **Entitlement** — `WiFiCheckTV.entitlements` with `com.apple.developer.networking.wifi-info = true`; `CODE_SIGN_ENTITLEMENTS` set in both configs
- **Network Scan** — grouped device grid using existing `NetworkScanService`, `DeviceFingerprintService`, `OUILookupService`; `TVDeviceDetailView` replaces iOS `DeviceDetailView` (no SwiftData dependency)
- **Speed Test** — concurrent per-site testing (Google / Facebook / Apple) via `SiteSpeedService`; large-format download speed display
- **Settings** — refresh cycle selector, accent color picker, Privacy Policy and Terms of Use sheets with full legal content
- **Throughput throttle** — download/upload speed test runs at most once every 5 minutes (`throughputInterval = 300`); resets on manual refresh

### Bug Fixes
- **`LocationAuthorizationManager` Combine dependency** — removed `ObservableObject` and `@Published`; class is an internal singleton, not observed by views directly
- **`WiFiInfoService` `ipv6Address` field** — renamed to match `WiFiInfo.localIPv6`

### Testing
- Added `WiFiCheckUITests` target with UI tests covering all critical flows (tab navigation, core buttons, graceful no-WiFi handling)
- Added tests for Upload Speed metric row, Score Info Sheet, and Network Info expanded toggle
- Added `WiFiCheckTVUITests` target with 22 tests covering all 5 tvOS tabs, settings interactions, speed test, network scan, and lifecycle events
- Accessibility identifiers added across all major views (both iOS and tvOS) for reliable test targeting

### Docs
- Added `BACKLOG.md` — feature pipeline and pre-submission checklist
- Added `RELEASE_NOTES.md` — version history
- Added `DEVICE_FINGERPRINTING_SPEC.md` — full spec for device naming feature
- Added `CHANGELOG.md` — this file
- Updated `PRD` — reflects tvOS platform, 7 metrics, new network info fields, removed Sign in with Apple

---

## v0.2 (April 2, 2026 — Submitted to Apple, Rejected April 3)
- First App Store submission
- Rejected: Sign in with Apple button unresponsive on iPhone 17 Pro Max / iOS 26.3.1

---

## v0.1 (Internal)
- Initial build, never submitted

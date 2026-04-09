# WiFi Check — tvOS Release Notes

> Version numbers are kept in sync with the iOS app.
> tvOS launched at v0.4, matching the iOS milestone at which the Apple TV target shipped.
>
> v0.x = internal / pre-release (no public users)
> v1.0 = first public App Store release
> v1.x = post-launch updates

---

## v0.4 (In Progress — April 2026)
**Status:** Development — first tvOS build, internal only
**Platform:** tvOS 26.4+
**Bundle ID:** Personal.Wi-Fi-Check--TV

### First Release — What's In This Build

#### App Structure
- 5-tab layout: Dashboard · Bandwidth · Speed Test · Network Scan · Settings
- Shared codebase with iOS — all Models, Services, and Utilities compiled into both targets via `PBXFileSystemSynchronizedRootGroup`
- SwiftData model container for device naming (shared with iOS)

#### Dashboard
- Proportional `WeightedHStack` layout — scales cleanly across 1080p and 4K displays
- **TVGaugeCard** — 180pt circular arc gauge, score + quality level, activity hint, SSID display
- **TVMetricsGrid** — 2-column grid of 6 metric tiles (Download, Internet Latency, Router Latency, Packet Loss, DNS, Jitter) with sub-score bars
- **TVScoreBreakdown** — same 6 metrics as sub-scores (/100), bottleneck badge, color legend (Green ≥80 · Blue 60–79 · Orange 40–59 · Red <40), weight footnote (Throughput 30 · Latency 25 · Packet Loss 20 · Jitter 15 · DNS 10)
- **TVNetworkInfoCard** — Device IP, Gateway, Public IP, IPv6, Connection Type; SSID row shown only when on Wi-Fi
- **TVNetworkPathView** — three-node topology (Apple TV → Router → Internet) with latency labels
- **TVActivityRecommendations** — adaptive pill grid rating activities (4K Streaming, Video Calls, Gaming, etc.)

#### Bandwidth Monitor
- Live per-interface download and upload rates via BSD `getifaddrs()` + `if_data`
- Session totals (downloaded, uploaded, combined) with duration timer
- Packet in/out counters
- 60-sample sparkline history for download and upload
- Peak speed records (download and upload)
- Interface badge showing active interface name

#### Speed Test
- Concurrent per-site testing: Google · Facebook · Apple
- Per-site: Latency (ms), Download (Mbps), DNS (ms)
- Average download speed displayed as large hero number
- Powered by shared `SiteSpeedService`

#### Network Scan
- Grouped device grid (Phones & Tablets, Computers, TVs & Speakers, Network, etc.)
- Device fingerprinting via `DeviceFingerprintService` (mDNS → OUI → hostname → fallback)
- `TVDeviceDetailView` — TV-native device detail sheet (no SwiftData editing; read-only display)
- Powered by shared `NetworkScanService`

#### Settings
- Refresh cycle: 5s / 15s / Manual (3-pill selector)
- **Theme selector** — System / Light / Dark 3-pill row; stored via `@AppStorage("wqm-color-scheme")`; applied with `.preferredColorScheme()` at `TabView` level — affects only this app
- Accent color picker (6 colors)
- Privacy Policy sheet (full legal text)
- Terms of Use sheet (full legal text)
- Version display

#### Network Intelligence
- **Dynamic interface detection** — probes `en0` (Wi-Fi) → `en1` (Ethernet) → `en2` → `en3` (USB-C adapter); uses first UP+RUNNING interface with a valid IPv4 address
- **Connection type** — reported as `"Wi-Fi"`, `"Ethernet"`, or `"USB-C LAN"`; SSID row hidden for wired connections
- **SSID resolution** — `WiFiSSIDHelper` ObjC runtime shim bypasses `NEHotspotNetwork` compile-time `API_UNAVAILABLE(tvos)` restriction; works on real Apple TV with `wifi-info` entitlement + Location permission
- **SSID fallback chain** — NEHotspotNetwork → UPnP router friendly-name → `"Wi-Fi Network"` (gateway IP never exposed)
- **Public IP throttle** — fetched at most once every 5 minutes
- **Throughput throttle** — speed measurement runs at most once every 5 minutes; resets on manual refresh

#### Infrastructure
- `WiFiSSIDHelper.h/.m` — ObjC shim using `NSClassFromString` + `objc_msgSend` for runtime SSID access
- `WiFiCheckTV-Bridging-Header.h` — imports `WiFiSSIDHelper.h` for Swift interop
- `WiFiCheckTV.entitlements` — `com.apple.developer.networking.wifi-info = true`
- `LocationAuthorizationManager` — CLLocationManager singleton for SSID authorization
- `DeviceBandwidthService` — BSD interface snapshot service with `measure()` / `recordSessionStart()` API
- **`ThroughputService` payload update (shared with iOS)** — 75 MB download + 25 MB upload per test (100 MB total); 45-second timeout; eliminates TCP slow-start distortion on connections above 100 Mbps

#### Bug Fixes
- **`TVDeviceDetailView` compiler error** — `device.mac` is `String` (non-optional); `?? "Unavailable"` was a type error. Fixed by removing the MAC row entirely (consistent with iOS v0.3 decision)
- **`fingerprint()` wrong call signature** — `TVDeviceDetailView` was calling `fingerprint(hostname:mac:mDNSServices:)` which does not exist; corrected to `fingerprint(hostname:mDNSServices:)` matching the actual `DeviceFingerprintService` API
- **Device detail fields** — `TVDeviceDetailView` now shows only reliable fields: IP Address, Hostname, Manufacturer, Device Type (matching iOS v0.3)
- **Refresh pill selected-text contrast** — `TVSegmentButtonStyle` selected text was hardcoded `.white`, invisible in Light theme; changed to `Color.primary` (black/white adaptive) with `.bold` weight

#### Testing
- 22 XCUITests covering all 5 tabs, settings interactions, score legend, connection type row, scan placeholder, rapid tab switching, and background/foreground cycle
- Accessibility identifiers: `tvRefreshPill_5s`, `tvRefreshPill_15s`, `tvRefreshPill_manual`, `tvThemePill_system`, `tvThemePill_light`, `tvThemePill_dark`, `tvPrivacyPolicyButton`, `tvTermsButton`, `tvScanNetworkButton`, `tvTestAllButton`

---

> Future entries will be added here as the tvOS app receives updates.
> Cross-platform changes that affect both iOS and tvOS will be noted in both files.

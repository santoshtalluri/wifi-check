# WiFiCheck Release Notes

## v0.3 (In Progress)
**Status:** Development — targeting first public App Store release
**Platforms:** iOS 17+ · tvOS 26.4+
**Focus:** tvOS companion app, device naming & memory, Speed Test overhaul, bug fixes from Apple review, personalization

### New Platform — Apple TV
- ✅ Full tvOS app (`Wi​Fi​Check ​TV` target) sharing all models, services, and utilities with iOS
- ✅ 5-tab TV layout: Dashboard, Bandwidth, Speed Test, Network Scan, Settings
- ✅ SSID resolution via ObjC runtime shim + wifi-info entitlement + CoreLocation
- ✅ Dynamic network interface detection — WiFi (en0), Ethernet (en1), USB-C LAN (en2+)
- ✅ Live device bandwidth monitoring (DeviceBandwidthService via BSD getifaddrs)
- ✅ Score breakdown legend with weights and color key
- ✅ Connection type display — hides SSID row on wired connections

### Speed Test Overhaul [iOS]
- ✅ **On-demand only** — speed test no longer runs automatically; a prominent "Test Your Speed" CTA triggers each test
- ✅ **Shimmer animation** — card pulses while measuring, giving clear visual feedback that a test is in progress
- ✅ **Re-run button** — appears after each completed test for one-tap re-measurement
- ✅ **Gauge bars removed** — cleaner, minimal numeric result display (Download Mbps / Upload Mbps)
- ✅ **100 MB test payload** — 75 MB download + 25 MB upload per test; ensures TCP is fully ramped before measurement completes, giving accurate readings at 100 Mbps–1 Gbps+
- ✅ **Methodology note** — inline explanation of why results may differ from Speedtest.net (single-stream vs. multi-stream)
- ✅ **Measurement loop gated to WiFi Info tab** — the 5-second polling loop pauses whenever the user is on Speed Test, Network Scan, or Settings; no background interference
- ✅ **Accent color on selection pills** — Speed Unit and other selector pills highlight with the user's chosen accent color instead of a hardcoded green
- ✅ **Data Usage card expanded by default** — data estimate visible without an extra tap
- ✅ **Help buttons removed** — Speed Unit and Data Usage ⓘ buttons removed; UI is self-explanatory

### Connection Diagnosis Redesign [iOS]
- ✅ **Green pulsing banner** — healthy connections display a prominent animated banner
- ✅ **Contextual headlines** — banner rotates through creative, context-aware messages: "Lightning Fast", "Blazing Smooth", "Running at Full Speed", "Solid & Steady", "Fast & Reliable", "All Systems Clear"

### Network Info [iOS]
- ✅ **Network Path card header** — now shows the connected WiFi network SSID ("Connected via [Network Name]") instead of a generic label

### New Features (iOS)
- ✅ Device naming — name unknown devices on your network, names persist across scans
- ✅ Apple device identification via mDNS hostname (handles rotating MAC addresses)
- ✅ "You named this" badge on recognized saved devices
- ✅ Device fingerprinting — auto-identify device type from MAC OUI + hostname patterns
- ✅ **Theme selector** — choose System / Light / Dark mode, applies only to this app
- ✅ **Font family picker** — bottom-sheet selector; each option previews in its own typeface
- ✅ **Font size** — Small / Medium / Large; scales all text app-wide including tab bar and Settings
- ✅ **Section header backgrounds** — clear visual separation between card headers and content rows

### Bug Fixes (from Apple Review rejection)
- ✅ Fixed Sign in with Apple button unresponsive on iPhone 17 Pro Max (iOS 26.3.1)
- ✅ Fixed force cast crash risk in NetworkScanService (safe fallback added)
- ✅ Fixed Rate App button pointing to placeholder App Store URL

### Bug Fixes (UI/UX polish)
- ✅ Selected pill text now uses `Color.primary` (high-contrast black/white) — was invisible in light theme
- ✅ Font size tile height normalized to match pill row height
- ✅ Device detail view shows only reliable fields (removed MAC, First Seen, Last Seen)

### Testing
- ✅ iOS XCUITest suite — 41 tests covering all tabs, buttons, sheets, flows, and new preference features
- ✅ tvOS XCUITest suite — 22 tests covering all 5 tabs, lifecycle, and key interactions

---

## v0.2 (Submitted to Apple 2026-04-02, Rejected 2026-04-03)
**Status:** Rejected — Guideline 2.1(a) App Completeness
**Submission ID:** 59131357-2a77-4090-aa06-c4e2d09c9d2f

### Rejection Reason
- Sign in with Apple button was not responsive on iPhone 17 Pro Max / iOS 26.3.1

### What Was In This Build
- WiFi quality monitoring (ping, latency, packet loss, throughput)
- Speed test against Google, Facebook, Apple
- Network device scanner
- Sign in with Apple
- Settings (refresh interval, appearance)

---

## v0.1 (Internal — First Build)
**Status:** Internal only, never submitted

### Initial Features
- Core WiFi monitoring
- Basic UI scaffold

---

> **Version Policy:**
> v0.x = internal/pre-release builds (no public users)
> v1.0 = first public App Store release to general public
> v1.x = post-launch updates

---

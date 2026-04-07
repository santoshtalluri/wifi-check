# WiFiCheck Release Notes

## v0.3 (In Progress)
**Status:** Development — targeting first public App Store release
**Platforms:** iOS 17+ · tvOS 26.4+
**Focus:** tvOS companion app, device naming & memory, bug fixes from Apple review, personalization

### New Platform — Apple TV
- ✅ Full tvOS app (`Wi​Fi​Check ​TV` target) sharing all models, services, and utilities with iOS
- ✅ 5-tab TV layout: Dashboard, Bandwidth, Speed Test, Network Scan, Settings
- ✅ SSID resolution via ObjC runtime shim + wifi-info entitlement + CoreLocation
- ✅ Dynamic network interface detection — WiFi (en0), Ethernet (en1), USB-C LAN (en2+)
- ✅ Live device bandwidth monitoring (DeviceBandwidthService via BSD getifaddrs)
- ✅ Score breakdown legend with weights and color key
- ✅ Connection type display — hides SSID row on wired connections

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

# WiFi Check v1 — Product Requirements Document

**Version:** 1.0
**Date:** April 2, 2026
**Platforms:** iOS 17+ · tvOS 26.4+
**Bundle ID (iOS):** Personal.WiFiCheck
**Bundle ID (tvOS):** Personal.Wi-Fi-Check--TV
**Display Name:** WiFi Check

---

## 1. Executive Summary

WiFi Check is a privacy-first application available on iPhone and Apple TV that gives users real-time visibility into the quality, performance, and health of their network connection. It measures seven key network metrics, computes a composite quality score, provides multi-site speed testing, and discovers all devices connected to the local network — all without collecting, storing, or transmitting any personal user data.

---

## 2. Problem Statement

Most users experience WiFi problems — slow browsing, video call drops, buffering — but have no way to understand *why*. The WiFi signal icon on their phone shows full bars, yet performance is poor. The root cause could be latency, packet loss, jitter, DNS issues, or network congestion from too many devices. Without visibility into these metrics, users are left guessing.

Existing tools are either too technical for everyday users (terminal-based, raw metrics with no interpretation) or too simplistic (single speed test with no context). There is no mainstream iOS app that provides a clear, interpretable quality score backed by real network metrics, combined with device discovery — all in a privacy-respecting package.

---

## 3. Target Audience

### Primary: Home WiFi Users
- Non-technical users who experience WiFi issues and want to understand why
- Households with many connected devices (smart home, streaming, gaming)
- Users who want to verify they are getting the internet speed they pay for
- Remote workers who depend on reliable WiFi for video calls

### Secondary: Small Business / IT-Aware Users
- Small business owners managing their office network
- IT-literate users who want a quick diagnostic tool on their phone
- Users evaluating WiFi routers, mesh systems, or ISP performance

---

## 4. How WiFi Check Helps

| User Problem | How WiFi Check Solves It |
|---|---|
| "My WiFi feels slow but shows full bars" | Composite score (0-100) that factors in latency, throughput, packet loss, jitter, DNS speed, and router latency — not just signal strength |
| "Video calls keep dropping" | Identifies packet loss and jitter — the metrics that directly cause call quality issues |
| "I don't know what's on my network" | Network Scan discovers all connected devices with names, so users can identify unknown or unauthorized devices |
| "Is it my WiFi or the website?" | Multi-site speed test (Google, Facebook, Apple) isolates whether the issue is the network or a specific destination |
| "I'm not technical" | Plain-language quality labels (Excellent / Good / Fair / Poor) with actionable tips like "Move closer to your router" |
| "I don't trust apps with my data" | Zero data collection. No analytics. No user tracking. All measurements stay on-device. |

---

## 5. Privacy & Data Handling

**WiFi Check does not collect, store, or transmit any personal user data.**

### What stays on-device (never leaves the app):
- All WiFi metrics and scores
- Network scan results (device IPs and hostnames)
- User preferences (theme, refresh rate)
- All measurement history

### External network calls (the only outbound traffic):
| Call | Purpose | Data Sent | Data Received |
|---|---|---|---|
| `api.ipify.org` | Display user's public IP | HTTP GET (no payload) | JSON with IP address |
| `ipinfo.io/json` | ISP name and city (once per session) | HTTP GET (no payload) | JSON: IP, org, city, region |
| `speed.cloudflare.com/__down` | Measure download speed | HTTP GET (no payload) | 5 MB test payload |
| `speed.cloudflare.com/__up` | Measure upload speed | HTTP POST (3 MB zeros) | HTTP 200 acknowledgement |
| `google.com`, `facebook.com`, `apple.com` | Per-site speed test | HTTP GET (no payload) | Standard web response |
| App Store (StoreKit) | In-app purchase | Apple-managed | Purchase verification |

### What we explicitly do NOT do:
- No user accounts required (Sign in with Apple is optional, for future features)
- No analytics SDKs (no Firebase, no Mixpanel, no Amplitude)
- No ad tracking SDKs
- No location data stored or transmitted (location permission is required by Apple solely to read the WiFi SSID)
- No crash reporting transmitted
- No network data shared with any third party
- Measurement data is cleared when the app goes to background

---

## 6. Feature Overview

### 6.1 WiFi Quality Dashboard (Tab 1: WiFi Info)

The primary screen provides a real-time composite quality score with detailed metric breakdowns.

**Composite Score (0-100):**
- Calculated from 6 weighted metrics measured in real-time (upload speed is display-only)
- Displayed as a visual gauge with color coding
- Accompanied by a quality label and actionable recommendation
- Tapping the ⓘ icon opens a scoring explanation sheet with metric weights and score ranges

**Seven Metrics (4 always visible, 3 expandable):**

| Metric | Weight | What It Measures | Why It Matters |
|---|---|---|---|
| Download Speed | 30% | Download throughput in Mbps | Determines streaming quality and file download speed |
| Upload Speed | display only | Upload throughput in Mbps | Critical for video calls, backups, and file sharing |
| Packet Loss | 25% | % of data packets that fail to arrive | Causes video call drops, gaming lag, and page load failures |
| Jitter | 15% | Variation in packet arrival time (ms) | Causes audio/video stuttering in real-time communication |
| Internet Latency | 15% | Round-trip time to internet (ms) | Affects responsiveness of all web browsing and apps |
| Router Latency | 10% | Round-trip time to local router (ms) | Isolates local WiFi issues from ISP issues |
| DNS Speed | 5% | Time to resolve domain names (ms) | Affects how quickly websites begin loading |

**Network Information Panel:**
- Always visible: Network name (SSID), Local IP, Gateway IP, Router manufacturer (from BSSID OUI lookup)
- Expandable: Signal strength, security type (WPA2/WPA3), ISP name & city, DNS servers in use, Public IP, IPv6 address, BSSID

**Contextual Banners:**
- Public network warning (open/unsecured WiFi detected)
- Enterprise network notification
- VPN active indicator

**Auto-Refresh:**
- Configurable: every 5 seconds, 15 seconds, or manual-only
- Measurements pause when app is backgrounded or WiFi disconnects

### 6.2 Speed Test (Tab 2)

Tests connectivity to three major internet destinations, providing per-site diagnostics.

**Sites Tested:**
- Google (google.com)
- Facebook (facebook.com)
- Apple (apple.com)

**Per-Site Metrics:**
- DNS Resolution Time — how long to look up the domain
- Latency — TCP connection time to port 443 (HTTPS)
- Download Speed — throughput in Mbps

**Purpose:** Helps users determine if a performance issue is network-wide or specific to a destination. If Google is fast but Facebook is slow, the problem is likely Facebook's servers, not the user's WiFi.

### 6.3 Network Scan (Tab 3)

Discovers and identifies all devices on the local network.

**Discovery Methods (run in parallel):**
- ICMP ping sweep (2 rounds with broadcast)
- Multi-port TCP probe (7 common ports)
- UDP probe sweep (7 IoT-common ports)
- Bonjour/mDNS service discovery (18 service types)
- SSDP/UPnP multicast discovery

**Name Resolution (layered):**
- Bonjour service names
- SSDP device names
- Gateway DNS PTR records
- Multicast DNS (mDNS) PTR records
- System reverse DNS (getnameinfo)

**User Experience:**
- Progressive loading — devices with resolved names appear as they're found
- Unresolved devices appear at the end with IP-based labels
- Search bar to filter by device name or IP address
- Smart device icons based on hostname detection (iPhone, Mac, printer, smart TV, router, etc.)

### 6.4 Settings (Tab 4)

**Preferences:**
- Measurement refresh cycle (5s / 15s / Manual)
- Accent color customization
- Font size

**Account:**
- Remove Ads (in-app purchase)
- Restore Purchases

**About:**
- Support & Feedback
- Privacy Policy
- App version
- Rate on App Store

---

## 7. tvOS App — Apple TV

### 7.1 Overview
WiFi Check for Apple TV is a companion app sharing all model, service, and utility code with the iOS app. It is optimised for the 10-foot TV viewing experience with large typography, focus-based remote navigation, and a full-width dashboard layout.

### 7.2 Tab Structure (5 tabs)

| Tab | Contents |
|---|---|
| Dashboard | Quality gauge · Metrics grid · Score breakdown with legend · Network info card · Network path topology · Activity recommendations |
| Bandwidth | Live download/upload rates · Session totals · Packet counts · Sparkline history · Peak speed records |
| Speed Test | Concurrent per-site tests (Google, Facebook, Apple) · Large download speed display |
| Network Scan | Network device discovery with grouped grid · Device detail sheet |
| Settings | Refresh cycle · Accent color · Privacy Policy · Terms of Use |

### 7.3 Key tvOS Technical Details
- **Interface detection:** `detectActiveInterface()` probes `en0` (WiFi) → `en1` (Ethernet) → `en2+` (USB-C adapter); uses first active IPv4 interface
- **SSID:** ObjC runtime bypass via `WiFiSSIDHelper` shim; requires `wifi-info` entitlement + Location permission; falls back to `"Wi-Fi Network"` (never exposes gateway IP)
- **Wired connections:** SSID row hidden; connection type shows `"Ethernet"` or `"USB-C LAN"`
- **Bandwidth:** `DeviceBandwidthService` reads `if_data` via `getifaddrs`; measures at each update cycle
- **No IAP / ads on tvOS** — feature parity with free tier of iOS app

---

## 8. Permissions Required

### iOS

| Permission | Reason | User-Facing Explanation |
|---|---|---|
| Location (When In Use) | Apple requires location permission to access WiFi SSID via NEHotspotNetwork API | "Location access is required by Apple to display your connected WiFi network name. We do not store or track your location." |
| Local Network | Required for pinging the router and scanning local devices | "WiFi Check needs local network access to measure your WiFi quality by pinging your router." |
| App Tracking Transparency | Standard iOS prompt for ad-related tracking | Requested on launch per Apple guidelines |

**iOS Entitlements:**
- `com.apple.developer.networking.wifi-info` — Required by Apple to access NEHotspotNetwork for SSID, BSSID, and signal strength

### tvOS

| Permission | Reason |
|---|---|
| Location (When In Use) | Required for NEHotspotNetwork SSID fetch via ObjC runtime shim |
| Local Network | Required for router ping and network scan |

**tvOS Entitlements:**
- `com.apple.developer.networking.wifi-info` — Same requirement as iOS; resolved via ObjC runtime bypass since API is compile-time unavailable on tvOS

---

## 9. In-App Purchases

| Product ID | Type | Description |
|---|---|---|
| `com.wificheck.removeads` | Non-consumable | Permanently removes ad banner placeholder from all screens (iOS only) |

---

## 10. Technical Requirements

### iOS
- **Minimum Version:** 17.0
- **Device:** iPhone (optimized for all screen sizes)
- **Frameworks:** SwiftUI, Network, NetworkExtension, CoreLocation, StoreKit, SwiftData
- **Architecture:** Swift 6 with structured concurrency (async/await)
- **Storage:** UserDefaults (preferences) + SwiftData (device names)

### tvOS
- **Minimum Version:** 26.4
- **Device:** Apple TV (all models with tvOS 26.4+)
- **Frameworks:** SwiftUI, Network, NetworkExtension, CoreLocation, SwiftData
- **ObjC Bridge:** `WiFiSSIDHelper` shim for runtime SSID access
- **Storage:** UserDefaults (preferences) + SwiftData (saved device names)

### Shared
- **Network:** Active network connection required
- **No third-party dependencies** — all functionality uses Apple frameworks only

---

## 10. Future Roadmap (Not in v1)

- Historical measurement trends and graphs
- WiFi health notifications
- Network speed comparison against ISP plan
- Detailed per-device bandwidth usage
- Widget for home screen quick-glance score
- iPad and Mac Catalyst support

---

*This document describes WiFi Check v1 as submitted for Apple App Store review. The app is designed as a diagnostic utility that empowers users to understand and improve their WiFi experience while maintaining strict privacy standards.*

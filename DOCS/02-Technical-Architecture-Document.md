# WiFi Check v1 — Technical Architecture Document

**Version:** 1.0
**Date:** April 2, 2026
**Platform:** iOS 17+
**Language:** Swift 6 with Structured Concurrency
**UI Framework:** SwiftUI

---

## 1. Architecture Overview

WiFi Check follows a service-oriented architecture with a centralized ViewModel orchestrating six independent measurement services. All services run concurrently using Swift's structured concurrency (`async/await`, `async let`, `withTaskGroup`). The UI layer is built entirely in SwiftUI with reactive data binding via `@Published` properties.

### High-Level Data Flow

```
WiFiCheckApp (@main)
    └── TabRootView (4 tabs)
            └── NetworkViewModel (@MainActor, @StateObject)
                    ├── WiFiInfoService     → SSID, IPs, signal, security
                    ├── PingService         → router latency, internet latency, jitter
                    ├── PacketLossService   → packet loss %
                    ├── DNSService          → DNS resolution speed
                    ├── ThroughputService   → download speed (Mbps)
                    ├── NetworkMonitor      → WiFi connectivity state
                    └── VPNDetectionService → VPN active detection
```

All measurement data stays on-device. No analytics SDKs, no crash reporters, no user tracking. The only outbound network calls are measurement probes documented in Section 12.

---

## 2. App Entry Point & Lifecycle

### WiFiCheckApp.swift

```swift
@main
struct WiFiCheckApp: App {
    var body: some Scene {
        WindowGroup {
            TabRootView()
        }
    }
}
```

### TabRootView.swift — Root Container

`TabRootView` hosts the SwiftUI `TabView` with four tabs and owns all shared state:

| Tab | View | Icon | Always Accessible |
|-----|------|------|--------------------|
| WiFi Info | `WiFiInfoTab` | `wifi` | No — requires WiFi |
| Speed Test | `SpeedTestTab` | `bolt.fill` | Yes |
| Network Scan | `NetworkScanTab` | `magnifyingglass` | No — requires WiFi |
| Settings | `SettingsView` | `gearshape` | Yes |

**State ownership:** Three `@StateObject` ViewModels live in `TabRootView` — `NetworkViewModel`, `PurchaseViewModel`, and scene phase tracking — ensuring state persists across tab switches.

**Lifecycle management:**
- `@Environment(\.scenePhase)` monitors foreground/background transitions
- When backgrounded: measurements pause, data clears (privacy)
- When foregrounded: measurements resume, WiFi info refreshes
- App Tracking Transparency request fires on first appearance

---

## 3. WiFi Info Tab — Connection Status & Quality Score

### 3.1 How Connection Status Is Determined

**NetworkMonitor.swift** wraps `NWPathMonitor` from the Network framework:

```
NWPathMonitor → pathUpdateHandler callback
    ├── path.status == .satisfied         → isConnected = true
    └── path.usesInterfaceType(.wifi)     → isConnectedToWiFi = true
```

When `isConnectedToWiFi` is `false`, WiFi Info and Network Scan tabs display a `BlockedView` with a prompt to connect to WiFi.

### 3.2 WiFi Network Parameters

**WiFiInfoService.swift** fetches network metadata using four distinct system APIs:

| Parameter | API / Method | Framework |
|-----------|-------------|-----------|
| SSID (network name) | `NEHotspotNetwork.fetchCurrent()` | NetworkExtension |
| BSSID (router MAC) | `NEHotspotNetwork.bssid` | NetworkExtension |
| Signal Strength (0.0–1.0) | `NEHotspotNetwork.signalStrength` | NetworkExtension |
| Security Type | `NEHotspotNetwork.securityType` (iOS 15+) | NetworkExtension |
| Local IP (device) | `getifaddrs()` → filter `en0` → `getnameinfo()` | POSIX / Darwin |
| Gateway IP (router) | `sysctl()` with `NET_RT_FLAGS` → parse `rt_msghdr` | POSIX / Darwin |
| Public IP | HTTPS GET `api.ipify.org?format=json` | Foundation (URLSession) |

**SSID retrieval requires two permissions:**
1. Location permission (`CLLocationManager.requestWhenInUseAuthorization`) — Apple mandates this for WiFi SSID access
2. WiFi Info entitlement (`com.apple.developer.networking.wifi-info`)

**Gateway IP resolution detail:**
- Reads the BSD routing table via `sysctl` with MIB: `[CTL_NET, AF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY]`
- Parses `rt_msghdr` structures (92 bytes on arm64) to find the default gateway
- Extracts the gateway sockaddr after skipping the destination sockaddr
- Filters out loopback (127.x.x.x) and 0.0.0.0
- Fallback: derives from local IP by replacing last octet with `.1`

**Security type mapping:**
| NEHotspotNetworkSecurityType | Display |
|------------------------------|---------|
| `.open` | Open |
| `.wep` | WEP |
| `.wpa` | WPA |
| `.wpa2Personal`, `.wpa2Enterprise` | WPA2 |
| `.wpa3Personal`, `.wpa3Enterprise`, `.wpa3Transition` | WPA3 |
| `@unknown default` | Secured |

### 3.3 Network Information Display

**WiFiInfoCard.swift** — collapsible card with two sections:

**Always visible:**
- Network (SSID) — e.g., "MyHome5G"
- My IP — e.g., "192.168.1.42"
- Gateway — e.g., "192.168.1.1"

**Expanded (tap "More Details"):**
- BSSID — e.g., "AA:BB:CC:DD:EE:FF"
- WiFi Signal — signal strength bars + percentage + quality label (e.g., "75% · Good")
- Security — e.g., "WPA3"
- Public IP — e.g., "203.0.113.1"

Expansion state persists via `@AppStorage("networkExpanded")`.

**Signal strength display:**
- 4 rectangle bars with heights 4/7/10/14pt
- Bar count: 0–25% = 1 bar, 25–50% = 2, 50–75% = 3, 75–100% = 4
- Active bars: green (#30D158), inactive: textTertiary
- Labels: Weak / Fair / Good / Excellent

### 3.4 Contextual Banners

Three contextual banners appear above the metrics when relevant:

| Banner | Trigger | Purpose |
|--------|---------|---------|
| VPN Active | VPN interface detected (utun1+, tun, tap, ppp, ipsec) | Warns that metrics reflect VPN tunnel, not raw WiFi |
| Public Network | Security type is `.open` | Warns user about unsecured WiFi |
| Enterprise Network | Security type contains "Enterprise" | Informational — enterprise WiFi detected |

**VPN detection (VPNDetectionService.swift):**
- Uses `NWPathMonitor` to inspect available network interfaces
- Checks interface names for VPN prefixes: `tap*`, `tun*`, `ppp*`, `ipsec*`, `utun1+`
- `utun0` is excluded (system default); `utun1+` indicates user VPN

---

## 4. Quality Score — Composite Scoring System

### 4.1 Six Measured Metrics

| # | Metric | Unit | Source Service | Measurement Method |
|---|--------|------|----------------|-------------------|
| 1 | Throughput | Mbps | ThroughputService | Download 200KB from Cloudflare CDN |
| 2 | Packet Loss | % | PacketLossService | 10 TCP probes, count failures |
| 3 | Jitter | ms | PingService | Std deviation of 5 RTT samples |
| 4 | Internet Latency | ms | PingService | TCP connect to 8.8.8.8:53 |
| 5 | Router Latency | ms | PingService | UDP/TCP probe to gateway IP |
| 6 | DNS Speed | ms | DNSService | CFHost resolve apple.com |

All six metrics are measured **concurrently** using `async let`:

```
async let routerPing  = pingService.pingGateway(ip: gatewayIP)
async let packetLoss  = packetLossService.measurePacketLoss(host: gatewayIP)
async let internetPing = pingService.ping(host: "8.8.8.8")
async let dnsSpeed    = dnsService.measureDNSSpeed()
async let throughput  = throughputService.measureThroughput()
async let jitter      = pingService.measureJitter()
```

Total measurement cycle: ~2–5 seconds.

### 4.2 Sub-Score Calculation

Each metric is converted to a 0–100 sub-score using piecewise linear interpolation:

**Throughput:**
| Range | Sub-Score |
|-------|-----------|
| ≥50 Mbps | 100 |
| 25–50 Mbps | 70–99 |
| 10–25 Mbps | 40–69 |
| 5–10 Mbps | 20–39 |
| <5 Mbps | 0–19 |

**Packet Loss:**
| Range | Sub-Score |
|-------|-----------|
| 0% | 100 |
| 0–1% | 90–99 |
| 1–5% | 50–89 |
| 5–15% | 10–49 |
| >15% | 0–9 |

**Jitter:**
| Range | Sub-Score |
|-------|-----------|
| <5 ms | 100 |
| 5–15 ms | 70–99 |
| 15–30 ms | 40–69 |
| 30–50 ms | 20–39 |
| >50 ms | 0–19 |

**Internet Latency:**
| Range | Sub-Score |
|-------|-----------|
| <30 ms | 100 |
| 30–80 ms | 60–99 |
| 80–150 ms | 20–59 |
| >150 ms | 0–19 |

**Router Latency:**
| Range | Sub-Score |
|-------|-----------|
| <10 ms | 100 |
| 10–40 ms | 60–99 |
| 40–100 ms | 20–59 |
| >100 ms | 0–19 |

**DNS Speed:**
| Range | Sub-Score |
|-------|-----------|
| <12 ms | 100 |
| 12–40 ms | 60–99 |
| 40–100 ms | 20–59 |
| >100 ms | 0–19 |

### 4.3 Weighted Composite Score

Sub-scores are combined using a weighted average:

| Metric | Weight | Rationale |
|--------|--------|-----------|
| Throughput | 30% | Most directly impacts user experience |
| Packet Loss | 25% | Causes call drops, gaming lag, page failures |
| Jitter | 15% | Affects real-time communication quality |
| Internet Latency | 15% | Impacts responsiveness of all web activity |
| Router Latency | 10% | Isolates local WiFi issues |
| DNS Speed | 5% | Affects initial page load, less impactful ongoing |

If a metric measurement fails (returns `nil`), its weight is redistributed proportionally across the remaining metrics.

### 4.4 Bottleneck Multiplier

If throughput or packet loss is critically poor, the entire score is penalized — a fast connection with high packet loss is not "good":

| Worst Critical Sub-Score | Multiplier | Effect |
|--------------------------|-----------|--------|
| 80–100 | 1.0 | No penalty |
| 60–79 | 0.9 | Mild (−10%) |
| 40–59 | 0.75 | Moderate (−25%) |
| 20–39 | 0.55 | Significant (−45%) |
| 0–19 | 0.35 | Severe (−65%) |

### 4.5 Score Smoothing

Raw scores are smoothed using a rolling buffer of the last 5 measurements:

```
displayedScore = average(last 5 composite scores)
```

This prevents jarring score fluctuations between measurement cycles.

### 4.6 Quality Levels & User Guidance

| Level | Score | Color | User Recommendation |
|-------|-------|-------|---------------------|
| Excellent | 80–100 | #0A84FF (blue) | "4K streaming, video calls, gaming — all smooth" |
| Good | 60–79 | #30D158 (green) | "HD streaming and calls work fine" |
| Fair | 40–59 | #FF9F0A (orange) | "Browsing works, video calls may stutter" |
| Poor | 20–39 | #FF453A (red) | "Weak signal — try moving closer to your router" |
| Very Poor | 0–19 | #FF453A (red) | "Very weak — move closer to your router" |

### 4.7 GaugeCard — Visual Score Display

The composite score is displayed as an animated arc gauge:
- 240° arc from bottom-left to bottom-right
- Gradient from red → orange → green → blue
- Animated needle pointing to current score
- SSID displayed below the score
- Quality label and recommendation text below

The GaugeCard is positioned outside the ScrollView so it remains fixed at the top of the WiFi Info tab while metrics and network info scroll beneath it.

---

## 5. Metrics Measurement — Technical Detail

### 5.1 Throughput (ThroughputService.swift)

| Parameter | Value |
|-----------|-------|
| Download URL | `https://speed.cloudflare.com/__down?bytes=200000` |
| File Size | ~200 KB |
| Session | `URLSession` with ephemeral configuration (no cache) |
| Timeout | 10 seconds |
| Cache Policy | `.reloadIgnoringLocalAndRemoteCacheData` |

**Calculation:**
```
Mbps = (bytes_received × 8) / (elapsed_seconds × 1,000,000)
```

### 5.2 Packet Loss (PacketLossService.swift)

| Parameter | Value |
|-----------|-------|
| Protocol | TCP connect |
| Port | 53 (DNS) |
| Probe Count | 10 |
| Concurrency | Full parallel (`withTaskGroup`) |
| Timeout per probe | 1.5 seconds |

**Calculation:**
```
packetLoss% = (failed_probes / 10) × 100
```

### 5.3 Jitter (PingService.swift)

| Parameter | Value |
|-----------|-------|
| Target Host | 8.8.8.8 (Google DNS) |
| Protocol | TCP connect to port 53 |
| Sample Count | 5 |
| Interval | 100ms between samples |

**Calculation:** Standard deviation of RTT samples:
```
mean = sum(samples) / n
jitter = sqrt(sum((sample_i − mean)²) / n)
```

### 5.4 Internet Latency (PingService.swift)

| Parameter | Value |
|-----------|-------|
| Target Host | 8.8.8.8 (Google DNS) |
| Protocol | TCP connect to port 53 |
| Timeout | 2 seconds |

Measures time from `NWConnection.start()` to `.ready` state using `CFAbsoluteTimeGetCurrent()` (microsecond precision).

### 5.5 Router Latency (PingService.swift)

| Parameter | Value |
|-----------|-------|
| Target | Gateway IP from WiFiInfoService |
| Primary Protocol | UDP to port 53 with DNS query payload |
| Fallback Protocol | TCP connect to port 53 |
| Timeout | 2 seconds |

The UDP probe sends a minimal DNS A-record query for `apple.com` (24 bytes) and measures time to response. If UDP fails, falls back to TCP.

**DNS query packet structure:**
```
Transaction ID: 0x0001
Flags: 0x0100 (standard query)
Questions: 1
QNAME: [5]apple[3]com[0]
QTYPE: A (0x0001)
QCLASS: IN (0x0001)
Total: 24 bytes
```

### 5.6 DNS Speed (DNSService.swift)

| Parameter | Value |
|-----------|-------|
| Domain | apple.com |
| API | CFHost (`CFHostStartInfoResolution`) |
| Record Type | A (IPv4 address) |

Measures the full DNS resolution time including cache lookup, recursive resolution if needed, and response parsing.

---

## 6. Metrics Display — MetricsCard

**MetricsCard.swift** presents the six metrics in a collapsible card:

**Always visible (3 primary metrics):**
1. Download Speed — value in Mbps
2. Internet Latency — value in ms
3. Router Latency — value in ms

**Expanded (3 advanced metrics):**
4. Packet Loss — value as percentage
5. Jitter — value in ms
6. DNS Speed — value in ms

Each metric row includes:
- Color-coded icon (per-metric color)
- Metric name (semibold)
- Current value (light weight)
- Sub-score indicator

Tapping any metric row opens a `TooltipSheet` with an explanation of what the metric measures and why it matters.

Expansion state persists via `@AppStorage("metricsExpanded")`.

---

## 7. Auto-Refresh System

### Refresh Cycle Options

| Setting | Behavior |
|---------|----------|
| 5 seconds | Automatic measurement every 5 seconds |
| 15 seconds | Automatic measurement every 15 seconds |
| Manual | No automatic refresh; user taps "Refresh Now" |

### Measurement Loop (NetworkViewModel.swift)

```
startMeasurementLoop() → Task {
    while !Task.isCancelled {
        await performMeasurement()    // ~2-5 seconds
        startCountdown()              // UI countdown timer
        try await Task.sleep(...)     // wait for next cycle
    }
}
```

**Pause conditions:**
- App enters background (`scenePhase != .active`)
- WiFi disconnects (`isConnectedToWiFi == false`)
- VPN becomes active (`isVPNActive == true`)

**Resume conditions:**
- App returns to foreground AND WiFi is connected AND VPN is not active

### Permission Detection

If all measurement probes fail for 3 consecutive cycles, the app assumes local network permission was denied and shows a permission request view.

---

## 8. Speed Test Tab — Per-Site Diagnostics

### 8.1 Purpose

Helps users determine if a performance issue is network-wide or specific to a destination. If Google is fast but Facebook is slow, the problem is Facebook's servers, not the user's WiFi.

### 8.2 Sites Tested

| Site | Domain | Icon |
|------|--------|------|
| Google | google.com | Blue "G" |
| Facebook | facebook.com | Blue "f" |
| Apple | apple.com | Gray Apple logo (SF Symbol) |

Sites are hardcoded in v1 (not user-editable).

### 8.3 Per-Site Measurements (SiteSpeedService.swift)

Each site test performs three measurements sequentially:

**1. DNS Resolution Time**
- API: `CFHost` (`CFHostStartInfoResolution`)
- Measures time to resolve domain to IP address
- Unit: milliseconds

**2. TCP Latency**
- API: `NWConnection` to port 443 (HTTPS)
- Measures TCP handshake time (SYN → SYN-ACK → ACK)
- Timeout: 5 seconds
- Unit: milliseconds

**3. Download Speed**
- API: `URLSession` (ephemeral, no cache)
- Downloads site homepage (`https://domain`)
- Timeout: 10 seconds
- Calculation: `(bytes × 8) / (seconds × 1,000,000) = Mbps`

### 8.4 User Experience

- Each site has an individual "Test" button
- Spinner displays per-site while testing
- Results fill in as each measurement completes
- Failed measurements show "–" with subdued styling
- Timeouts show "Timeout"

---

## 9. Network Scan Tab — Device Discovery

### 9.1 Overview

The Network Scan discovers all devices on the local /24 subnet using five parallel discovery methods, then resolves human-readable hostnames through four name resolution strategies.

### 9.2 Discovery Methods

#### Phase 1: ICMP Ping Sweep (2 rounds)

| Parameter | Value |
|-----------|-------|
| Socket | `socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)` — non-privileged |
| Range | Subnet .1 through .254 |
| Broadcast | Also pings subnet .255 |
| Rounds | 2 (catches late responders) |
| Listen duration | 4 seconds per round |

Constructs ICMP ECHO REQUEST packets with proper checksum, sends to each IP, listens for ECHO REPLY responses. Uses `poll()` for non-blocking receive with timeout.

#### Phase 2: Multi-Port TCP Probe

| Parameter | Value |
|-----------|-------|
| Ports | 80, 443, 62078, 548, 445, 8080, 554 |
| Batch size | 50 concurrent connections |
| Timeout | 250ms per connection |

| Port | Protocol | Typical Devices |
|------|----------|-----------------|
| 80 | HTTP | Web servers, routers, IoT |
| 443 | HTTPS | Secure web, smart devices |
| 62078 | Apple lockdownd | iPhones, iPads, Macs |
| 548 | AFP | macOS file sharing |
| 445 | SMB | Windows PCs, NAS |
| 8080 | HTTP alt | IoT admin panels |
| 554 | RTSP | IP cameras, DVRs |

#### Phase 3: UDP Probe Sweep

| Parameter | Value |
|-----------|-------|
| Ports | 5353, 1900, 53, 67, 137, 9100, 10001 |
| Method | connect → send → detect ICMP port-unreachable |
| Timeout | 5ms per probe |

| Port | Protocol | Typical Devices |
|------|----------|-----------------|
| 5353 | mDNS | Apple devices, smart speakers |
| 1900 | SSDP/UPnP | Smart TVs, media players |
| 53 | DNS | Router, Pi-hole |
| 67 | DHCP | Router |
| 137 | NetBIOS | Windows PCs |
| 9100 | JetDirect | Network printers |
| 10001 | Various | IoT devices |

#### Phase 4: Bonjour/mDNS Service Discovery

Uses `NWBrowser` to browse 16+ mDNS service types simultaneously:

```
_http._tcp.             _airplay._tcp.          _googlecast._tcp.
_smb._tcp.              _printer._tcp.          _raop._tcp.
_companion-link._tcp.   _homekit._tcp.          _sleep-proxy._udp.
_ipp._tcp.              _scanner._tcp.          _daap._tcp.
_airport._tcp.          _device-info._tcp.      _ssh._tcp.
_rfb._tcp.              _apple-mobdev2._tcp.    _hap._tcp.
```

Timeout: 4 seconds. Returns map of IP → friendly service name.

#### Phase 5: SSDP/UPnP Discovery

| Parameter | Value |
|-----------|-------|
| Multicast address | 239.255.255.250:1900 |
| Protocol | UDP |
| Message | M-SEARCH with `ST: ssdp:all` |
| Sends | 2 (for reliability) |
| Timeout | 3 seconds |

Parses response `SERVER:` header for device model information.

### 9.3 Name Resolution (Multi-Strategy)

After discovering IP addresses, hostnames are resolved in order of reliability:

| Priority | Method | Best For |
|----------|--------|----------|
| 1 | Bonjour service names | Apple devices, Chromecasts, HomeKit |
| 2 | SSDP device names | Smart TVs, media devices, UPnP devices |
| 3 | Gateway DNS PTR | Most LAN devices (router caches DHCP names) |
| 4 | mDNS PTR (224.0.0.251:5353) | `.local` domain devices |
| 5 | `getnameinfo()` | System reverse DNS fallback |

**Gateway DNS PTR resolution detail:**
- Constructs DNS PTR query packets in wire format
- Sends all queries through a single UDP socket to the gateway IP on port 53
- Each query converts IP to reverse format: `192.168.1.5` → `5.1.168.192.in-addr.arpa`
- Batch approach prevents thread pool exhaustion (vs. per-IP blocking calls)
- Parses responses with DNS compression pointer support
- Timeout: 3 seconds for all queries

**Name cleaning (`cleanDNSName`):**
- Strips `.local` suffix
- Strips `.attlocal.net` and similar ISP suffixes
- Removes trailing dots
- Strips RAOP MAC prefixes (e.g., `AA:BB:CC:DD:EE:FF@DeviceName` → `DeviceName`)
- Strips sleep-proxy prefixes

### 9.4 Device Icon Assignment

Hostname patterns are matched case-insensitively to SF Symbols:

| Pattern | Icon | Device Type |
|---------|------|-------------|
| "this device" | `iphone` | User's iPhone |
| "iphone", "ipad", "ipod" | `iphone` | iOS devices |
| "macbook", "mac-", "imac" | `macbook` | Mac computers |
| "airpod" | `airpodspro` | AirPods |
| "appletv", "roku", "fire" | `appletv` | Streaming devices |
| "printer", "canon", "hp" | `printer.fill` | Printers |
| "sonos", "homepod", "echo" | `hifispeaker` | Smart speakers |
| "hue", "light", "bulb" | `lightbulb` | Smart lighting |
| "camera", "doorbell", "ring" | `video` | Security cameras |
| "tv", "samsung", "lg-" | `tv` | TVs |
| "router", "gateway", "deco" | `wifi.router` | Routers/mesh |
| "xbox", "playstation", "switch" | `gamecontroller` | Game consoles |
| Default | `desktopcomputer` | Unknown devices |

### 9.5 Progressive Loading

Devices appear in the UI as their names are resolved:
1. During scan, status shows: "N IPs found, M resolved"
2. Current scan phase displayed (e.g., "ICMP sweep", "Resolving names")
3. Named devices appear immediately when hostname resolves
4. Unresolved devices appear at the end with IP-based labels (e.g., "Device (73)")

`NetworkDevice` uses IP address as stable `id` (not UUID) to prevent list flicker when names update.

### 9.6 Search

TextField filters the device list by hostname or IP address (case-insensitive). Shows filtered count vs. total.

---

## 10. Settings Tab

### 10.1 Preferences Section

| Setting | Options | Storage |
|---------|---------|---------|
| Refresh Cycle | 5s / 15s / Manual | `@AppStorage("wqm-update-frequency")` |
| Accent Color | 8 color swatches | `@AppStorage("wqm-accent-color")` |
| Font | SF Pro (Default) — extensible | `@AppStorage("selectedFont")` |

**Refresh Cycle** — three pill buttons plus a "Refresh Now" button for manual mode. Changes take effect immediately on the measurement loop.

**Accent Color** — applies to tab bar tint, buttons, and interactive elements via `Color(hex: accentColorHex)`.

**Font** — v1 ships with system font (SF Pro) only. Font infrastructure (`FontManager.swift`) is ready for custom fonts — adding a new font requires only dropping the OTF file and adding one entry to the font list.

### 10.2 Account Section

| Feature | Implementation |
|---------|---------------|
| Sign In with Apple | `AuthenticationServices` framework, stores Apple User ID in UserDefaults |
| Remove Ads ($1.99) | Non-consumable IAP via StoreKit 2, product ID: `com.wificheck.removeads` |
| Restore Purchases | `StoreKit.Transaction.currentEntitlements` |

### 10.3 About Section

| Item | Action |
|------|--------|
| Share with Love | `UIActivityViewController` share sheet |
| Privacy Policy | In-app modal with privacy summary |
| Terms of Use | Placeholder for future |
| Support & Feedback | `SupportSheet` with email link |
| Rate on App Store | Opens App Store review URL |
| Version | Reads `CFBundleShortVersionString` — displays "1.0.0" |

---

## 11. Persistent Storage

### UserDefaultsManager.swift

WiFi Check stores only user preferences in `UserDefaults`. No measurement data, network information, or usage analytics are persisted.

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `wqm-update-frequency` | Int | 5 | Measurement refresh interval (seconds) |
| `wqm-accent-color` | String | "30D158" | UI accent color (hex) |
| `wqm-ads-removed` | Bool | false | Ad removal purchase state |
| `wqm-apple-user-id` | String? | nil | Apple Sign-In user ID |
| `metricsExpanded` | Bool | false | Metrics card expansion state |
| `networkExpanded` | Bool | false | Network info card expansion state |

---

## 12. External Network Calls

WiFi Check makes the following outbound network calls. These are the **only** data that leaves the device:

| Destination | Protocol | Purpose | Data Sent | Data Received | Frequency |
|-------------|----------|---------|-----------|---------------|-----------|
| `api.ipify.org` | HTTPS GET | Fetch public IP | No payload | `{"ip":"x.x.x.x"}` | On WiFi info refresh |
| `speed.cloudflare.com` | HTTPS GET | Measure download speed | No payload | ~200KB test file | Every measurement cycle |
| `8.8.8.8:53` | TCP connect | Measure internet latency | TCP SYN only | TCP SYN-ACK | Every measurement cycle |
| Gateway IP:53 | UDP | Measure router latency | 24-byte DNS query | DNS response | Every measurement cycle |
| `apple.com` | DNS (CFHost) | Measure DNS speed | DNS A query | DNS A response | Every measurement cycle |
| `google.com` | HTTPS | Speed test (on demand) | HTTP GET | Homepage HTML | User-triggered |
| `facebook.com` | HTTPS | Speed test (on demand) | HTTP GET | Homepage HTML | User-triggered |
| `apple.com` | HTTPS | Speed test (on demand) | HTTP GET | Homepage HTML | User-triggered |
| `224.0.0.251:5353` | UDP multicast | mDNS device discovery | PTR queries | PTR responses | During network scan |
| `239.255.255.250:1900` | UDP multicast | SSDP device discovery | M-SEARCH | SSDP responses | During network scan |
| Local subnet IPs | ICMP/TCP/UDP | Device discovery | Probe packets | Responses | During network scan |
| App Store (StoreKit) | Apple-managed | In-app purchase | Apple-managed | Purchase verification | On purchase |

**No data is sent to any WiFi Check server.** There is no WiFi Check backend. All processing happens on-device.

---

## 13. iOS Permissions & Entitlements

### Entitlements (WiFiCheck.entitlements)

| Entitlement | Value | Purpose |
|-------------|-------|---------|
| `com.apple.developer.networking.wifi-info` | `true` | Access `NEHotspotNetwork` for SSID, BSSID, signal strength, security type |

### Info.plist Permissions

| Key | User-Facing Description | Required For |
|-----|------------------------|-------------|
| `NSLocationWhenInUseUsageDescription` | "Location access is required by Apple to display your connected WiFi network name. We do not store or track your location." | `NEHotspotNetwork.fetchCurrent()` — Apple requires location for WiFi SSID |
| `NSLocalNetworkUsageDescription` | "WiFi Check needs local network access to measure your WiFi quality by pinging your router." | Pinging gateway, network scan, Bonjour discovery |
| `NSBonjourServices` | (array of 16 service types) | `NWBrowser` mDNS service discovery |

### Info.plist — Network Configuration

| Key | Value | Purpose |
|-----|-------|---------|
| `NSAppTransportSecurity.NSAllowsArbitraryLoads` | `true` | Allows HTTP connections for measurement probes |

### Runtime Permission Flow

1. **First launch:** App requests Location permission (required by Apple for WiFi SSID)
2. **First measurement:** iOS prompts for Local Network access (triggered by first gateway ping)
3. **First launch:** App Tracking Transparency prompt displayed per Apple guidelines
4. **On demand:** StoreKit purchase flow (Apple-managed authentication)

---

## 14. Frameworks & Dependencies

### Apple Frameworks Used

| Framework | Purpose |
|-----------|---------|
| SwiftUI | Entire UI layer |
| Network | `NWPathMonitor`, `NWConnection`, `NWBrowser` — connectivity monitoring, TCP/UDP probes, Bonjour |
| NetworkExtension | `NEHotspotNetwork` — WiFi SSID, BSSID, signal, security |
| CoreLocation | `CLLocationManager` — location permission (required for NEHotspotNetwork) |
| Foundation | `URLSession` — HTTP downloads, `CFHost` — DNS resolution |
| StoreKit | In-app purchases (Remove Ads) |
| AuthenticationServices | Sign In with Apple |

### Third-Party Dependencies

**None.** WiFi Check uses zero third-party libraries, SDKs, or frameworks. No CocoaPods, no SPM packages, no analytics SDKs, no ad SDKs, no crash reporters.

---

## 15. Data Models

### WiFiInfo

```
ssid: String              — Network name (e.g., "MyHome5G")
localIP: String           — Device IP on LAN (e.g., "192.168.1.42")
gatewayIP: String         — Router IP (e.g., "192.168.1.1")
publicIP: String          — Internet-facing IP (e.g., "203.0.113.1")
bssid: String             — Router MAC address
signalStrength: Double    — 0.0–1.0 from NEHotspotNetwork
securityType: String      — WPA2, WPA3, Open, etc.
isPublicNetwork: Bool     — true if security is Open
isEnterprise: Bool        — true if enterprise security
```

### NetworkMetrics

```
routerLatency: Double?     — ms (gateway ping)
packetLoss: Double?        — percentage 0–100
internetLatency: Double?   — ms (8.8.8.8 ping)
dnsSpeed: Double?          — ms (apple.com resolve)
throughput: Double?        — Mbps (Cloudflare download)
jitter: Double?            — ms (std dev of 5 RTTs)
```

All fields optional (`Double?`) to handle measurement failures gracefully.

### QualityScore

```
composite: Int              — 0–100 final score
throughputSubScore: Int     — 0–100
packetLossSubScore: Int     — 0–100
jitterSubScore: Int         — 0–100
internetSubScore: Int       — 0–100
routerSubScore: Int         — 0–100
dnsSubScore: Int            — 0–100
level: QualityLevel         — .excellent/.good/.fair/.poor/.veryPoor
```

### NetworkDevice (Network Scan)

```
id: String                  — IP address (stable identifier)
ip: String                  — Device IP on LAN
hostname: String            — Resolved device name
deviceIcon: String          — SF Symbol name
```

---

## 16. Concurrency Architecture

### Main Actor Isolation

`NetworkViewModel` is `@MainActor` — all published property updates occur on the main thread. Measurement services use `nonisolated` methods to perform work off the main thread:

```
@MainActor NetworkViewModel
    └── Task { performMeasurement() }
            └── async let (6 concurrent probes)
                    └── nonisolated service methods (off main thread)
                            └── NWConnection / socket / URLSession
```

### Network Scan Concurrency

```
@MainActor NetworkScanService.startScan()
    └── Task {
            Phase 1: await icmpPingSweep()              — nonisolated
            Phase 2: async let tcpSweep()               — nonisolated  ┐
                     async let udpProbeSweep()           — nonisolated  ├── parallel
                     async let discoverBonjourNames()    — nonisolated  │
                     async let ssdpDiscover()            — nonisolated  ┘
            Phase 3: await batchDNSPTRLookup(gateway)    — nonisolated
                     await batchDNSPTRLookup(mDNS)       — nonisolated
                     getnameinfo fallback (batches of 8) — nonisolated
            Update UI: MainActor.run { devices = [...] }
        }
```

### Thread Safety Patterns

- `withCheckedContinuation` bridges callback-based APIs (NWConnection, sockets) to async/await
- `resolveOnce` closure pattern prevents double-resume of continuations in timeout + callback races
- `nonisolated` keyword on methods that perform blocking I/O prevents main actor deadlocks

---

## 17. UI Architecture

### Theme System (ColorExtension.swift)

All colors are adaptive to system dark/light mode:

| Semantic Color | Dark Mode | Light Mode |
|---------------|-----------|------------|
| `appBackground` | #080B14 | #FFFFFF |
| `glassBackground` | white @ 5.5% | #F2F2F7 @ 60% |
| `glassBorder` | white @ 10% | black @ 8% |
| `textPrimary` | white | #1C1C1E |
| `textSecondary` | white @ 45% | rgba(60,60,67,0.6) |
| `textTertiary` | white @ 22% | black @ 15% |
| `dividerColor` | white @ 6% | black @ 6% |
| `gaugeTrack` | white @ 7% | black @ 7% |

**Quality colors are identical in both modes:**

| Quality | Color |
|---------|-------|
| Excellent | #0A84FF (blue) |
| Good | #30D158 (green) |
| Fair | #FF9F0A (orange) |
| Poor | #FF453A (red) |

### Glass Card Design (GlassCard.swift)

All content sections use a frosted glass card style:
- Rounded rectangle with 18pt corner radius
- Background: `glassBackground` with blur
- Border: `glassBorder` with 0.5pt stroke
- Subtle shadow in dark mode

### Typography Convention

| Element | Weight | Color |
|---------|--------|-------|
| Section headers | Bold, size 17 | textPrimary |
| Labels | Semibold, size 13 | textPrimary |
| Values | Light, size 13 | textPrimary |
| Hints/subtitles | Regular, size 11–12 | textSecondary |

### Ad Banner (AdBannerPlaceholder.swift)

- Dashed-border placeholder (44pt height) on all four tabs
- Hidden when `purchaseVM.adsRemoved == true`
- Designed for future AdMob SDK integration

---

## 18. Build Configuration

| Setting | Value |
|---------|-------|
| Bundle ID | `Personal.WiFiCheck` |
| Display Name | WiFi Check |
| Minimum iOS | 17.0 |
| Swift Version | 6 |
| Concurrency | Strict (`SWIFT_STRICT_CONCURRENCY = complete`) |
| Actor Isolation | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| Target Device | iPhone |
| Orientation | Portrait |

---

## 19. File Inventory

### Services (7 files)
| File | Purpose | Lines |
|------|---------|-------|
| `NetworkScanService.swift` | Multi-method device discovery + name resolution | ~780 |
| `WiFiInfoService.swift` | SSID, IPs, signal, security via NEHotspotNetwork + POSIX | ~200 |
| `PingService.swift` | TCP/UDP latency, jitter measurement | ~180 |
| `ThroughputService.swift` | Download speed via Cloudflare CDN | ~40 |
| `PacketLossService.swift` | TCP probe failure rate | ~50 |
| `DNSService.swift` | DNS resolution timing via CFHost | ~30 |
| `SiteSpeedService.swift` | Per-site DNS + latency + download | ~120 |
| `NetworkMonitor.swift` | NWPathMonitor WiFi state wrapper | ~25 |
| `VPNDetectionService.swift` | VPN interface detection | ~30 |

### Views (12 files)
| File | Purpose |
|------|---------|
| `TabRootView.swift` | Root TabView container |
| `WiFiInfoTab.swift` | Quality dashboard layout |
| `GaugeCard.swift` | Animated arc gauge for composite score |
| `MetricsCard.swift` | Collapsible 6-metric display |
| `WiFiInfoCard.swift` | Collapsible network info display |
| `SpeedTestTab.swift` | Per-site speed test UI |
| `NetworkScanTab.swift` | Device discovery UI with search |
| `SettingsView.swift` | Preferences, account, about |
| `BlockedView.swift` | No WiFi / permission denied state |
| `PublicBanner.swift` | Public network warning |
| `EnterpriseBanner.swift` | Enterprise network info |
| `AdBannerPlaceholder.swift` | Ad placeholder |

### Models (3 files)
| File | Purpose |
|------|---------|
| `WiFiInfo.swift` | Network parameter data structure |
| `NetworkMetrics.swift` | Raw measurement values |
| `QualityScore.swift` | Composite score + quality level |

### ViewModels (2 files)
| File | Purpose |
|------|---------|
| `NetworkViewModel.swift` | Central orchestrator — measurement loop, services, state |
| `PurchaseViewModel.swift` | StoreKit IAP state management |

### Utilities (3 files)
| File | Purpose |
|------|---------|
| `ColorExtension.swift` | Adaptive color system |
| `FontManager.swift` | Font selection infrastructure |
| `UserDefaultsManager.swift` | Preferences persistence |

---

*This document describes the complete technical architecture of WiFi Check v1. All network measurements are performed on-device using Apple's Network framework and POSIX APIs. No third-party SDKs are used. No user data is collected, stored externally, or transmitted to any server.*

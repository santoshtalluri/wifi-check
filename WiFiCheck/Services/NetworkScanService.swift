import Foundation
import Combine
import Network
import UIKit

struct NetworkDevice: Identifiable, Equatable, Hashable {
    let id: String // use IP as stable ID so updates don't flicker
    var ip: String
    var hostname: String
    var isOnline: Bool
    var mDNSServices: [String] = []
    var isThisDevice: Bool = false  // the device running this app
    var isGateway: Bool = false     // the network's primary gateway / router
    /// When this device was first discovered in any scan (persisted across app launches)
    var firstSeen: Date = Date()
    /// When this device was last seen in a scan (set to the time of the most recent scan)
    var lastSeen: Date = Date()

    /// MAC address in colon-separated uppercase hex, e.g. "A4:C3:F0:12:34:56".
    /// Empty string when the device hasn't responded to an ARP request yet.
    var mac: String = ""

    /// True when the locally-administered bit (bit 1 of byte 0) is set.
    /// iOS, Android, and Windows randomize their MAC for privacy — this flag identifies them.
    var isRandomizedMAC: Bool {
        guard !mac.isEmpty,
              let firstByte = UInt8(mac.prefix(2), radix: 16) else { return false }
        return firstByte & 0x02 != 0
    }

    /// OUI manufacturer from the first 3 MAC bytes. Returns nil if MAC is empty or randomized.
    var ouiPrefix: String? {
        guard !mac.isEmpty, !isRandomizedMAC else { return nil }
        return String(mac.prefix(8)) // "AA:BB:CC"
    }

    // ML-enriched classification (set after scan by DeviceFingerprintService.enrich)
    var cachedDeviceType: DeviceType? = nil
    var cachedManufacturer: String? = nil

    /// Returns the best available fingerprint: ML-enriched result if present, else sync keyword result.
    var fingerprint: FingerprintResult {
        if let type = cachedDeviceType {
            return FingerprintResult(deviceType: type, manufacturer: cachedManufacturer, confidence: 0.90)
        }
        return DeviceFingerprintService.shared.fingerprint(hostname: hostname, mDNSServices: mDNSServices)
    }

    static func == (lhs: NetworkDevice, rhs: NetworkDevice) -> Bool {
        lhs.id == rhs.id && lhs.hostname == rhs.hostname
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var deviceIcon: String {
        let h = hostname.lowercased()
        if isThisDevice { return "iphone" }
        if h.contains("iphone") || h.contains("ipad") || h.contains("ipod") { return "iphone" }
        if h.contains("macbook") || h.contains("mac-") || h.contains("imac") || h.contains("mac pro") { return "macbook" }
        if h.contains("apple") || h.contains("airpod") { return "airpodspro" }
        if h.contains("appletv") || h.contains("apple-tv") || h.contains("roku") || h.contains("fire") { return "appletv" }
        if h.contains("printer") || h.contains("canon") || h.contains("epson") || h.contains("brother") || h.contains("hp ") || h.contains("envy") { return "printer.fill" }
        if h.contains("sonos") || h.contains("homepod") || h.contains("speaker") || h.contains("echo") { return "hifispeaker" }
        if h.contains("google") && (h.contains("home") || h.contains("mini") || h.contains("nest")) { return "hifispeaker" }
        if h.contains("hue") || h.contains("light") || h.contains("bulb") || h.contains("lifx") { return "lightbulb" }
        if h.contains("camera") || h.contains("doorbell") || h.contains("ring") || h.contains("nest") { return "video" }
        if h.contains("tv") || h.contains("samsung") || h.contains("lg-") || h.contains("sony") || h.contains("vizio") || h.contains("s90c") { return "tv" }
        if h.contains("router") || h.contains("gateway") || h.contains("deco") || h.contains("eero") || h.contains("mesh") { return "wifi.router" }
        if h.contains("xbox") || h.contains("playstation") || h.contains("switch") { return "gamecontroller" }
        if h.contains("android") || h.contains("galaxy") || h.contains("pixel") { return "smartphone" }
        if h.contains("pc") || h.contains("desktop") || h.contains("windows") { return "desktopcomputer" }
        if h.contains("laptop") || h.contains("surface") || h.contains("thinkpad") { return "laptopcomputer" }
        if h.contains("nas") || h.contains("wd") || h.contains("synology") || h.contains("mycloud") { return "externaldrive" }
        return "desktopcomputer"
    }
}

/// Thread-safe Sendable storage for concurrent name discovery
nonisolated final class ConcurrentStringMap: Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) let storage = NSMutableDictionary()

    nonisolated init() {}

    nonisolated func set(key: String, value: String) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }

    nonisolated func get(key: String) -> String? {
        lock.lock()
        let v = storage[key] as? String
        lock.unlock()
        return v
    }

    nonisolated func getAll() -> [String: String] {
        lock.lock()
        let result = (storage as? [String: String]) ?? (storage as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        lock.unlock()
        return result
    }
}

/// Thread-safe Sendable set for concurrent IP collection
nonisolated final class ConcurrentStringSet: Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var storage = Set<String>()

    nonisolated init() {}

    nonisolated func insert(_ value: String) {
        lock.lock()
        storage.insert(value)
        lock.unlock()
    }

    nonisolated func getAll() -> Set<String> {
        lock.lock()
        let result = storage
        lock.unlock()
        return result
    }

    nonisolated var count: Int {
        lock.lock()
        let c = storage.count
        lock.unlock()
        return c
    }
}

@MainActor
final class NetworkScanService: ObservableObject {
    @Published var devices: [NetworkDevice] = []
    @Published var isScanning = false
    @Published var scanPhase: String = ""
    @Published var discoveredCount = 0 // total IPs found, shown during scan

    private var scanTask: Task<Void, Never>?
    private var knownIPs: Set<String> = []

    // Shared queues — reusing queues across NWConnection objects prevents the
    // NECP path-monitor race that spams "nw_path_necp_check_for_updates Failed
    // to copy updated result (22)" when many connections are created rapidly.
    private nonisolated static let tcpQueue = DispatchQueue(label: "com.wificheck.tcp", qos: .userInitiated)
    private nonisolated static let resolveQueue = DispatchQueue(label: "com.wificheck.resolve", qos: .userInitiated)

    // MARK: - Persistent first-seen history
    // Keyed by "host:<hostname>" for named devices, "ip:<ip>" for unknown ones.
    // Stores TimeInterval (seconds since reference date) so UserDefaults can hold it natively.
    private var firstSeenStore: [String: TimeInterval] = [:]
    private let firstSeenStoreKey = "com.wificheck.deviceFirstSeen.v1"

    init() { loadFirstSeenStore() }

    private func loadFirstSeenStore() {
        firstSeenStore = UserDefaults.standard.dictionary(forKey: firstSeenStoreKey)
            as? [String: TimeInterval] ?? [:]
    }

    private func saveFirstSeenStore() {
        UserDefaults.standard.set(firstSeenStore, forKey: firstSeenStoreKey)
    }

    /// Returns the stable lookup key for a device — hostname wins over IP for cross-scan stability.
    private func historyKey(ip: String, hostname: String) -> String {
        if !hostname.isEmpty && !hostname.hasPrefix("Device (") {
            return "host:\(hostname)"
        }
        return "ip:\(ip)"
    }

    /// Returns firstSeen from persistent store (or now if first encounter),
    /// and updates the store entry so new devices are recorded immediately.
    private func firstSeenDate(ip: String, hostname: String) -> Date {
        let key = historyKey(ip: ip, hostname: hostname)
        if let stored = firstSeenStore[key] {
            return Date(timeIntervalSinceReferenceDate: stored)
        }
        let now = Date()
        firstSeenStore[key] = now.timeIntervalSinceReferenceDate
        saveFirstSeenStore()
        return now
    }

    nonisolated private func getSubnetBase(localIP: String, gatewayIP: String) -> String? {
        let parts = gatewayIP.split(separator: ".").map(String.init)
        if parts.count == 4 {
            return "\(parts[0]).\(parts[1]).\(parts[2])"
        }
        let localParts = localIP.split(separator: ".").map(String.init)
        guard localParts.count == 4 else { return nil }
        return "\(localParts[0]).\(localParts[1]).\(localParts[2])"
    }

    // MARK: - Device list management

    private var localIP: String = ""
    private var gatewayIP: String = ""

    /// Add a device with a resolved name to the visible list
    private func addResolvedDevice(ip: String, hostname: String, isThisDevice: Bool = false, isGateway: Bool = false) {
        let now = Date()
        if let idx = devices.firstIndex(where: { $0.ip == ip }) {
            // Update name if a better hostname was just resolved
            if devices[idx].hostname.hasPrefix("Device (") && !hostname.hasPrefix("Device (") {
                devices[idx].hostname = hostname
                // Re-look up history with the now-resolved hostname key
                devices[idx].firstSeen = firstSeenDate(ip: ip, hostname: hostname)
            }
            devices[idx].lastSeen = now
        } else {
            var device = NetworkDevice(id: ip, ip: ip, hostname: hostname, isOnline: true,
                                       isThisDevice: isThisDevice, isGateway: isGateway)
            device.firstSeen = firstSeenDate(ip: ip, hostname: hostname)
            device.lastSeen = now
            devices.append(device)
            sortDevices()
        }
    }

    /// Add remaining unresolved devices at the end of scan
    private func addUnresolvedDevices() {
        let now = Date()
        for ip in knownIPs {
            if !devices.contains(where: { $0.ip == ip }) {
                let lastOctet = ip.split(separator: ".").last ?? ""
                let hostname = "Device (\(lastOctet))"
                var device = NetworkDevice(id: ip, ip: ip, hostname: hostname, isOnline: true)
                device.firstSeen = firstSeenDate(ip: ip, hostname: hostname)
                device.lastSeen = now
                devices.append(device)
            }
        }
        sortDevices()
    }

    private func sortDevices() {
        devices.sort { a, b in
            if a.ip == localIP { return true }
            if b.ip == localIP { return false }
            if a.ip == gatewayIP { return true }
            if b.ip == gatewayIP { return false }
            return a.ip.compare(b.ip, options: .numeric) == .orderedAscending
        }
    }

    func startScan(localIP: String, gatewayIP: String) {
        guard !isScanning else { return }

        scanTask?.cancel()
        devices = []
        knownIPs = []
        discoveredCount = 0
        isScanning = true
        scanPhase = "Discovering devices..."
        self.localIP = localIP
        self.gatewayIP = gatewayIP

        // Derive device name: ProcessInfo.hostName is more reliable than UIDevice.name in iOS 16+
        // UIDevice.name returns a generic "iPhone" since iOS 16 for privacy. ProcessInfo returns
        // the actual hostname set by the user e.g. "Santosh-iPhoneMaxx.local" → "Santosh iPhoneMaxx"
        var rawHost = ProcessInfo.processInfo.hostName
        if rawHost.hasSuffix(".local") { rawHost = String(rawHost.dropLast(6)) }
        var deviceName = rawHost.replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespaces)
        if deviceName.isEmpty || deviceName.lowercased() == "localhost" {
            deviceName = UIDevice.current.name.isEmpty ? "This Device" : UIDevice.current.name
        }

        // Show self and gateway immediately (they always have names)
        addResolvedDevice(ip: localIP, hostname: deviceName, isThisDevice: true)
        addResolvedDevice(ip: gatewayIP, hostname: "Router", isGateway: true)
        knownIPs.insert(localIP)
        knownIPs.insert(gatewayIP)

        scanTask = Task {
            guard let subnet = getSubnetBase(localIP: localIP, gatewayIP: gatewayIP) else {
                isScanning = false
                return
            }

            print("[Scan] ===== Starting comprehensive scan on \(subnet).0/24 =====")

            // ── Phase 1: ICMP Ping (finds most devices) ──────

            scanPhase = "Pinging network..."
            let icmpAlive = await icmpPingSweep(subnet: subnet)
            print("[Scan] ICMP round 1: \(icmpAlive.count) devices")
            for ip in icmpAlive { knownIPs.insert(ip) }
            discoveredCount = knownIPs.count

            // ── Phase 1b: Second ICMP round ──

            let icmpAlive2 = await icmpPingSweep(subnet: subnet)
            for ip in icmpAlive2 { knownIPs.insert(ip) }
            discoveredCount = knownIPs.count
            print("[Scan] ICMP round 2: total \(knownIPs.count) IPs")

            // ── Phase 2: TCP + Bonjour + SSDP in parallel ──────

            scanPhase = "Scanning services..."
            let (tcpResult, bonjourResult, ssdpResult) = await performServiceDiscovery(
                subnet: subnet, localIP: localIP, gatewayIP: gatewayIP
            )
            print("[Scan] TCP: \(tcpResult.count), Bonjour: \(bonjourResult.count), SSDP: \(ssdpResult.count)")

            for ip in tcpResult { knownIPs.insert(ip) }
            discoveredCount = knownIPs.count

            // Show Bonjour devices immediately (they have names!)
            for (ip, name) in bonjourResult {
                knownIPs.insert(ip)
                addResolvedDevice(ip: ip, hostname: name)
            }
            // Show SSDP devices with real names
            for (ip, name) in ssdpResult {
                knownIPs.insert(ip)
                if name != "UPnP Device" {
                    addResolvedDevice(ip: ip, hostname: name)
                }
            }
            discoveredCount = knownIPs.count

            // ── Phase 3: Resolve names — show each device as its name resolves ──────

            scanPhase = "Resolving names..."

            // 3a. Batch DNS PTR to gateway (fastest bulk resolution)
            let gatewayDNS = await batchDNSPTRLookup(
                ips: Array(knownIPs), dnsServer: gatewayIP, port: 53, timeout: 3.0
            )
            print("[Scan] Gateway DNS resolved \(gatewayDNS.count) names")
            for (ip, name) in gatewayDNS {
                let cleaned = cleanDNSName(name)
                if !cleaned.isEmpty {
                    addResolvedDevice(ip: ip, hostname: cleaned)
                }
            }

            // 3b. Batch mDNS PTR
            let mdns = await batchDNSPTRLookup(
                ips: Array(knownIPs), dnsServer: "224.0.0.251", port: 5353, timeout: 2.0,
                unicastResponse: true
            )
            print("[Scan] mDNS resolved \(mdns.count) names")
            for (ip, name) in mdns {
                let cleaned = cleanDNSName(name)
                if !cleaned.isEmpty {
                    addResolvedDevice(ip: ip, hostname: cleaned)
                }
            }

            // 3c. getnameinfo for IPs not yet shown
            let unresolvedIPs = knownIPs.filter { ip in
                ip != localIP && ip != gatewayIP && !devices.contains(where: { $0.ip == ip })
            }
            if !unresolvedIPs.isEmpty {
                let gniBatchSize = 8
                let unresolvedArray = Array(unresolvedIPs)
                for batchStart in stride(from: 0, to: unresolvedArray.count, by: gniBatchSize) {
                    let batchEnd = min(batchStart + gniBatchSize, unresolvedArray.count)
                    let batch = Array(unresolvedArray[batchStart..<batchEnd])
                    let results: [(String, String?)] = await withTaskGroup(of: (String, String?).self) { group in
                        for ip in batch {
                            group.addTask {
                                let name = await self.resolveHostnameAsync(ip: ip)
                                return (ip, name)
                            }
                        }
                        var r: [(String, String?)] = []
                        for await result in group { r.append(result) }
                        return r
                    }
                    for (ip, name) in results {
                        if let name = name {
                            let cleaned = cleanDNSName(name)
                            if !cleaned.isEmpty {
                                addResolvedDevice(ip: ip, hostname: cleaned)
                            }
                        }
                    }
                }
            }

            // ── Final: add remaining unresolved devices ──────

            addUnresolvedDevices()

            // ── ARP enrichment: add MAC addresses from the system ARP cache ──────
            let arpCache = readARPCache(subnet: subnet)
            for i in devices.indices {
                if let macBytes = arpCache[devices[i].ip], macBytes.count == 6 {
                    devices[i].mac = macBytes.map { String(format: "%02X", $0) }.joined(separator: ":")
                }
            }

            let named = devices.filter { !$0.hostname.hasPrefix("Device (") }.count
            print("[Scan] ===== Done: \(devices.count) devices, \(named) with names =====")
            for d in devices {
                print("[Scan]   \(d.ip)  \"\(d.hostname)\"")
            }

            // ── ML enrichment: classify devices using on-device LLM when available ──
            scanPhase = "Classifying devices..."
            let enriched = await DeviceFingerprintService.shared.enrich(devices)
            for i in devices.indices {
                if let result = enriched[devices[i].ip] {
                    devices[i].cachedDeviceType = result.deviceType
                    devices[i].cachedManufacturer = result.manufacturer
                }
            }

            scanPhase = ""
            isScanning = false
        }
    }

    /// Run TCP + UDP + Bonjour + SSDP off the main actor
    nonisolated private func performServiceDiscovery(
        subnet: String, localIP: String, gatewayIP: String
    ) async -> (Set<String>, [String: String], [String: String]) {
        async let tcp = tcpSweep(subnet: subnet)
        async let udp = udpProbeSweep(subnet: subnet)
        async let bonjour = discoverBonjourNames(timeout: 4.0)
        async let ssdp = ssdpDiscover(timeout: 3.0)

        let (tcpResult, udpResult, bonjourResult, ssdpResult) = await (tcp, udp, bonjour, ssdp)
        return (tcpResult.union(udpResult), bonjourResult, ssdpResult)
    }

    /// UDP probe sweep — sends packets to ports that IoT devices listen on.
    /// Even without a response, some devices generate ICMP port-unreachable which
    /// proves they exist. We detect them via the connect+send pattern.
    nonisolated private func udpProbeSweep(subnet: String) async -> Set<String> {
        await withCheckedContinuation { continuation in
            DispatchQueue(label: "com.wificheck.udpprobe", qos: .userInitiated).async {
                var alive = Set<String>()
                let ports: [UInt16] = [5353, 1900, 53, 67, 137, 9100, 10001, 9876, 7]

                for i in 1...254 {
                    let ip = "\(subnet).\(i)"
                    for port in ports {
                        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                        guard fd >= 0 else { continue }

                        var addr = sockaddr_in()
                        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                        addr.sin_family = sa_family_t(AF_INET)
                        addr.sin_port = port.bigEndian
                        inet_pton(AF_INET, ip, &addr.sin_addr)

                        // connect() for UDP just sets the default destination
                        let connectResult = withUnsafePointer(to: &addr) { ptr in
                            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                                Darwin.connect(fd, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }

                        if connectResult == 0 {
                            // Send a small probe
                            let msg: [UInt8] = [0]
                            _ = send(fd, msg, msg.count, 0)

                            // Wait for a real UDP response or a conclusive ICMP error.
                            // POLLERR alone is insufficient: EHOSTUNREACH (ICMP host-unreachable)
                            // means the router says the IP does NOT exist — not that it's alive.
                            // Only ECONNREFUSED (ICMP port-unreachable) proves the host is up.
                            var pfd = pollfd(fd: Int32(fd), events: Int16(POLLIN | POLLERR), revents: 0)
                            let ready = poll(&pfd, 1, 5) // 5ms quick check
                            if ready > 0 {
                                if (pfd.revents & Int16(POLLIN)) != 0 {
                                    // Got an actual UDP response — host is definitely alive
                                    alive.insert(ip)
                                    close(fd)
                                    break
                                } else if (pfd.revents & Int16(POLLERR)) != 0 {
                                    // Inspect the socket error: only ECONNREFUSED means the host is
                                    // alive (it sent ICMP port-unreachable). EHOSTUNREACH /
                                    // ENETUNREACH mean the router says the host doesn't exist.
                                    var sockErr: Int32 = 0
                                    var errLen = socklen_t(MemoryLayout<Int32>.size)
                                    getsockopt(fd, SOL_SOCKET, SO_ERROR, &sockErr, &errLen)
                                    if sockErr == ECONNREFUSED {
                                        alive.insert(ip)
                                        close(fd)
                                        break
                                    }
                                }
                            }
                        }
                        close(fd)
                    }
                }

                continuation.resume(returning: alive)
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
        scanPhase = ""
    }

    // MARK: - ICMP Ping Sweep ─────────────────────────────────────────────

    nonisolated private func icmpPingSweep(subnet: String) async -> Set<String> {
        await withCheckedContinuation { continuation in
            DispatchQueue(label: "com.wificheck.icmp", qos: .userInitiated).async {
                var alive = Set<String>()

                let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
                guard sock >= 0 else {
                    print("[ICMP] Failed to create socket: \(errno)")
                    continuation.resume(returning: [])
                    return
                }
                defer { close(sock) }

                let flags = fcntl(sock, F_GETFL)
                _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

                let identifier = UInt16(ProcessInfo.processInfo.processIdentifier & 0xFFFF)

                // Send ICMP echo request to each IP
                for i in 1...254 {
                    let ip = "\(subnet).\(i)"
                    var packet = self.buildICMPEchoRequest(identifier: identifier, sequence: UInt16(i))

                    var addr = sockaddr_in()
                    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                    addr.sin_family = sa_family_t(AF_INET)
                    inet_pton(AF_INET, ip, &addr.sin_addr)

                    withUnsafePointer(to: &addr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                            _ = sendto(sock, &packet, packet.count, 0, saPtr,
                                       socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }

                // Also send broadcast ping — some devices only respond to broadcast
                var broadcastAddr = sockaddr_in()
                broadcastAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                broadcastAddr.sin_family = sa_family_t(AF_INET)
                let broadcastIP = "\(subnet).255"
                inet_pton(AF_INET, broadcastIP, &broadcastAddr.sin_addr)
                var bcastPacket = self.buildICMPEchoRequest(identifier: identifier, sequence: 0)
                withUnsafePointer(to: &broadcastAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                        _ = sendto(sock, &bcastPacket, bcastPacket.count, 0, saPtr,
                                   socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }

                // Collect responses for 4 seconds
                let startTime = Date()
                var buf = [UInt8](repeating: 0, count: 1024)

                while Date().timeIntervalSince(startTime) < 4.0 {
                    var pfd = pollfd(fd: Int32(sock), events: Int16(POLLIN), revents: 0)
                    let ready = poll(&pfd, 1, 100)
                    if ready > 0 && (pfd.revents & Int16(POLLIN)) != 0 {
                        var from = sockaddr_in()
                        var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                        let n = withUnsafeMutablePointer(to: &from) { ptr in
                            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                                recvfrom(sock, &buf, buf.count, 0, saPtr, &fromLen)
                            }
                        }
                        if n > 0 {
                            var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            _ = withUnsafeMutablePointer(to: &from.sin_addr) { addrPtr in
                                inet_ntop(AF_INET, addrPtr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                            }
                            alive.insert(String(cString: ipBuf))
                        }
                    }
                }

                continuation.resume(returning: alive)
            }
        }
    }

    nonisolated private func buildICMPEchoRequest(identifier: UInt16, sequence: UInt16) -> [UInt8] {
        var packet: [UInt8] = [
            8, 0, 0, 0,
            UInt8(identifier >> 8), UInt8(identifier & 0xFF),
            UInt8(sequence >> 8), UInt8(sequence & 0xFF),
        ]
        var sum: UInt32 = 0
        for i in stride(from: 0, to: packet.count, by: 2) {
            if i + 1 < packet.count {
                sum += UInt32(packet[i]) << 8 | UInt32(packet[i + 1])
            } else {
                sum += UInt32(packet[i]) << 8
            }
        }
        while sum >> 16 != 0 { sum = (sum & 0xFFFF) + (sum >> 16) }
        let checksum = ~UInt16(sum & 0xFFFF)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)
        return packet
    }

    // MARK: - TCP Sweep ───────────────────────────────────────────────────

    nonisolated private func tcpSweep(subnet: String) async -> Set<String> {
        let ports: [UInt16] = [80, 443, 62078, 548, 445, 8080, 554]
        let tcpAlive = ConcurrentStringSet()

        let batchSize = 50
        for batchStart in stride(from: 1, through: 254, by: batchSize) {
            let batchEnd = min(batchStart + batchSize - 1, 254)
            await withTaskGroup(of: Void.self) { group in
                for i in batchStart...batchEnd {
                    let ip = "\(subnet).\(i)"
                    group.addTask {
                        for port in ports {
                            if await self.tcpProbe(ip: ip, port: port, timeout: 0.25) {
                                tcpAlive.insert(ip)
                                break
                            }
                        }
                    }
                }
            }
        }
        return tcpAlive.getAll()
    }

    nonisolated private func tcpProbe(ip: String, port: UInt16, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(ip),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            var resolved = false
            let resolveOnce: (Bool) -> Void = { value in
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: value)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: resolveOnce(true)
                case .failed, .cancelled: resolveOnce(false)
                default: break
                }
            }
            connection.start(queue: Self.tcpQueue)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { resolveOnce(false) }
        }
    }

    // MARK: - Bonjour/mDNS Discovery ──────────────────────────────────────

    nonisolated private func discoverBonjourNames(timeout: TimeInterval) async -> [String: String] {
        let serviceTypes = [
            "_http._tcp.", "_airplay._tcp.", "_googlecast._tcp.",
            "_smb._tcp.", "_printer._tcp.", "_raop._tcp.",
            "_companion-link._tcp.", "_homekit._tcp.", "_sleep-proxy._udp.",
            "_ipp._tcp.", "_scanner._tcp.", "_daap._tcp.",
            "_airport._tcp.", "_device-info._tcp.", "_ssh._tcp.",
            "_rfb._tcp.", "_apple-mobdev2._tcp.", "_hap._tcp.",
        ]

        nonisolated(unsafe) var collectedEndpoints: [(endpoint: NWEndpoint, name: String, type: String)] = []
        let collectLock = NSLock()
        var browsers: [NWBrowser] = []

        for serviceType in serviceTypes {
            let params: NWParameters = serviceType.contains("_udp.") ? .udp : .tcp
            let b = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: "local."), using: params)
            b.browseResultsChangedHandler = { results, _ in
                for result in results {
                    if case .service(let name, let type, _, _) = result.endpoint {
                        let cleanName = name.replacingOccurrences(of: "\\032", with: " ")
                        collectLock.lock()
                        if !collectedEndpoints.contains(where: { $0.name == cleanName && $0.type == type }) {
                            collectedEndpoints.append((endpoint: result.endpoint, name: cleanName, type: type))
                        }
                        collectLock.unlock()
                    }
                }
            }
            b.stateUpdateHandler = { _ in }
            b.start(queue: DispatchQueue(label: "com.wificheck.bonjour.\(serviceType)"))
            browsers.append(b)
        }

        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        for b in browsers { b.cancel() }

        let endpoints: [(endpoint: NWEndpoint, name: String, type: String)] = {
            collectLock.lock(); defer { collectLock.unlock() }
            return collectedEndpoints
        }()

        let resultStorage = ConcurrentStringMap()
        await withTaskGroup(of: Void.self) { group in
            for item in endpoints {
                let name = item.name
                let endpoint = item.endpoint
                group.addTask {
                    if let ip = await self.resolveEndpointToIP(endpoint: endpoint, timeout: 3.0) {
                        // Clean RAOP/sleep-proxy prefixes: "MAC@DeviceName" → "DeviceName"
                        var cleanName = name
                        if let atIndex = cleanName.firstIndex(of: "@") {
                            cleanName = String(cleanName[cleanName.index(after: atIndex)...])
                        }
                        // Remove sleep-proxy prefix like "70-35-60-63.1 "
                        if cleanName.contains("sleep-proxy") || cleanName.range(of: #"^\d[\d-]+\.\d+ "#, options: .regularExpression) != nil {
                            if let spaceIndex = cleanName.firstIndex(of: " ") {
                                cleanName = String(cleanName[cleanName.index(after: spaceIndex)...])
                            }
                        }
                        resultStorage.set(key: ip, value: cleanName)
                    }
                }
            }
        }

        return resultStorage.getAll()
    }

    nonisolated private func resolveEndpointToIP(endpoint: NWEndpoint, timeout: TimeInterval) async -> String? {
        if let ip = await resolveViaConnection(endpoint: endpoint, params: .udp, timeout: 2.0) {
            return ip
        }
        if let ip = await resolveViaConnection(endpoint: endpoint, params: .tcp, timeout: 1.5) {
            return ip
        }
        if case .service(let name, _, _, _) = endpoint {
            let variants = [
                name.replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: " ", with: "-")
                    .replacingOccurrences(of: ".", with: "") + ".local",
                name.replacingOccurrences(of: " ", with: "-") + ".local",
            ]
            for hostname in variants {
                if let ip = await resolveLocalHostname(hostname) {
                    return ip
                }
            }
        }
        return nil
    }

    nonisolated private func resolveViaConnection(endpoint: NWEndpoint, params: NWParameters, timeout: TimeInterval) async -> String? {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(to: endpoint, using: params)
            var resolved = false
            let resolveOnce: (String?) -> Void = { value in
                guard !resolved else { return }
                resolved = true
                connection.cancel()
                continuation.resume(returning: value)
            }

            let extractIP: () -> Void = {
                if let path = connection.currentPath,
                   let remote = path.remoteEndpoint,
                   case .hostPort(let host, _) = remote,
                   let cleanIP = self.cleanIPString("\(host)") {
                    resolveOnce(cleanIP)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: extractIP()
                case .waiting, .preparing:
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { extractIP() }
                case .failed, .cancelled: resolveOnce(nil)
                default: break
                }
            }
            connection.pathUpdateHandler = { _ in extractIP() }
            connection.start(queue: Self.resolveQueue)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { resolveOnce(nil) }
        }
    }

    // MARK: - SSDP/UPnP Discovery ────────────────────────────────────────

    nonisolated private func ssdpDiscover(timeout: TimeInterval) async -> [String: String] {
        await withCheckedContinuation { continuation in
            DispatchQueue(label: "com.wificheck.ssdp", qos: .userInitiated).async {
                var results: [String: String] = [:]

                let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                guard sock >= 0 else {
                    continuation.resume(returning: [:])
                    return
                }
                defer { close(sock) }

                var reuse: Int32 = 1
                setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
                let flags = fcntl(sock, F_GETFL)
                _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

                let msearch = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: ssdp:all\r\n\r\n"
                let msgData = Array(msearch.utf8)

                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = UInt16(1900).bigEndian
                inet_pton(AF_INET, "239.255.255.250", &addr.sin_addr)

                // Send twice for reliability
                for _ in 0..<2 {
                    withUnsafePointer(to: &addr) { ptr in
                        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                            _ = sendto(sock, msgData, msgData.count, 0, saPtr,
                                       socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }

                let startTime = Date()
                var buf = [UInt8](repeating: 0, count: 4096)

                while Date().timeIntervalSince(startTime) < timeout {
                    var pfd = pollfd(fd: Int32(sock), events: Int16(POLLIN), revents: 0)
                    let ready = poll(&pfd, 1, 200)
                    if ready > 0 && (pfd.revents & Int16(POLLIN)) != 0 {
                        var from = sockaddr_in()
                        var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                        let n = withUnsafeMutablePointer(to: &from) { ptr in
                            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                                recvfrom(sock, &buf, buf.count, 0, saPtr, &fromLen)
                            }
                        }
                        if n > 0 {
                            var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            _ = withUnsafeMutablePointer(to: &from.sin_addr) { addrPtr in
                                inet_ntop(AF_INET, addrPtr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                            }
                            let ip = String(cString: ipBuf)
                            let response = String(bytes: buf[0..<n], encoding: .utf8) ?? ""
                            if let name = self.parseSSDPResponse(response), !name.isEmpty {
                                results[ip] = name
                            } else if results[ip] == nil {
                                results[ip] = "UPnP Device"
                            }
                        }
                    }
                }

                continuation.resume(returning: results)
            }
        }
    }

    nonisolated private func parseSSDPResponse(_ response: String) -> String? {
        let lines = response.components(separatedBy: "\r\n")
        var server: String?
        for line in lines {
            if line.lowercased().hasPrefix("server:") {
                server = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
        }
        if let s = server {
            let parts = s.components(separatedBy: " ")
            for part in parts.reversed() {
                let p = part.lowercased()
                if p.contains("upnp") || p.contains("linux") || p.contains("http") || p.contains("dlnadoc") { continue }
                if !part.isEmpty {
                    return part.components(separatedBy: "/").first ?? part
                }
            }
        }
        return server
    }

    // MARK: - Batch DNS PTR Query ────────────────────────────────────────

    nonisolated private func batchDNSPTRLookup(
        ips: [String], dnsServer: String, port: UInt16, timeout: TimeInterval,
        unicastResponse: Bool = false
    ) async -> [String: String] {
        await withCheckedContinuation { continuation in
            DispatchQueue(label: "com.wificheck.batchdns", qos: .userInitiated).async {
                var results: [String: String] = [:]

                let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
                guard sock >= 0 else {
                    continuation.resume(returning: [:])
                    return
                }
                defer { close(sock) }

                let flags = fcntl(sock, F_GETFL)
                _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

                var queryMap: [UInt16: String] = [:]
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = port.bigEndian
                inet_pton(AF_INET, dnsServer, &addr.sin_addr)

                for ip in ips {
                    let (queryPacket, queryID) = self.buildDNSPTRQuery(ip: ip, unicastResponse: unicastResponse)
                    queryMap[queryID] = ip

                    queryPacket.withUnsafeBytes { ptr in
                        withUnsafePointer(to: &addr) { addrPtr in
                            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                                _ = sendto(sock, ptr.baseAddress, ptr.count, 0, saPtr,
                                           socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                    }
                }

                let startTime = Date()
                var buf = [UInt8](repeating: 0, count: 1024)

                while Date().timeIntervalSince(startTime) < timeout {
                    var pfd = pollfd(fd: Int32(sock), events: Int16(POLLIN), revents: 0)
                    let ready = poll(&pfd, 1, 200)
                    if ready > 0 && (pfd.revents & Int16(POLLIN)) != 0 {
                        let n = recv(sock, &buf, buf.count, 0)
                        if n > 0 {
                            let data = Data(buf[0..<n])
                            if data.count >= 2 {
                                let respID = UInt16(data[0]) << 8 | UInt16(data[1])
                                if let ip = queryMap[respID],
                                   let name = self.parseDNSPTRResponse(data: data, expectedID: respID) {
                                    results[ip] = name
                                }
                            }
                        }
                    }
                    if results.count == ips.count { break }
                }

                continuation.resume(returning: results)
            }
        }
    }

    nonisolated private func buildDNSPTRQuery(ip: String, unicastResponse: Bool) -> (Data, UInt16) {
        let queryID = UInt16.random(in: 1...65535)
        var packet = Data()

        packet.append(UInt8(queryID >> 8))
        packet.append(UInt8(queryID & 0xFF))
        packet.append(contentsOf: [0x01, 0x00] as [UInt8])
        packet.append(contentsOf: [0x00, 0x01] as [UInt8])
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00] as [UInt8])

        let parts = ip.split(separator: ".").reversed()
        for part in parts {
            packet.append(UInt8(part.count))
            packet.append(contentsOf: Array(part.utf8))
        }
        packet.append(7)
        packet.append(contentsOf: Array("in-addr".utf8))
        packet.append(4)
        packet.append(contentsOf: Array("arpa".utf8))
        packet.append(0)

        packet.append(contentsOf: [0x00, 0x0C] as [UInt8])
        if unicastResponse {
            packet.append(contentsOf: [0x80, 0x01] as [UInt8])
        } else {
            packet.append(contentsOf: [0x00, 0x01] as [UInt8])
        }

        return (packet, queryID)
    }

    nonisolated private func parseDNSPTRResponse(data: Data, expectedID: UInt16) -> String? {
        guard data.count >= 12 else { return nil }

        let id = UInt16(data[0]) << 8 | UInt16(data[1])
        guard id == expectedID else { return nil }
        guard data[2] & 0x80 != 0 else { return nil }
        guard data[3] & 0x0F == 0 else { return nil }

        let ancount = Int(UInt16(data[6]) << 8 | UInt16(data[7]))
        guard ancount > 0 else { return nil }

        var offset = 12
        offset = skipDNSName(data: data, offset: offset)
        guard offset > 0 else { return nil }
        offset += 4

        guard offset < data.count else { return nil }
        offset = skipDNSName(data: data, offset: offset)
        guard offset > 0, offset + 10 <= data.count else { return nil }

        let rtype = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
        offset += 8

        let rdlen = Int(UInt16(data[offset]) << 8 | UInt16(data[offset + 1]))
        offset += 2

        guard rtype == 12, offset + rdlen <= data.count else { return nil }
        return readDNSName(data: data, offset: offset)
    }

    nonisolated private func skipDNSName(data: Data, offset: Int) -> Int {
        var pos = offset
        while pos < data.count {
            let len = Int(data[pos])
            if len == 0 { return pos + 1 }
            if len >= 192 { return pos + 2 }
            pos += 1 + len
        }
        return -1
    }

    nonisolated private func readDNSName(data: Data, offset: Int) -> String? {
        var labels: [String] = []
        var pos = offset
        var jumps = 0

        while pos < data.count && jumps < 10 {
            let len = Int(data[pos])
            if len == 0 { break }
            if len >= 192 {
                guard pos + 1 < data.count else { break }
                pos = Int(UInt16(data[pos] & 0x3F) << 8 | UInt16(data[pos + 1]))
                jumps += 1
                continue
            }
            pos += 1
            guard pos + len <= data.count else { break }
            labels.append(String(bytes: data[pos..<pos + len], encoding: .utf8) ?? "")
            pos += len
        }

        return labels.isEmpty ? nil : labels.joined(separator: ".")
    }

    nonisolated private func cleanDNSName(_ name: String) -> String {
        var clean = name
        if clean.hasSuffix(".") { clean = String(clean.dropLast()) }
        if clean.hasSuffix(".local") { clean = String(clean.dropLast(6)) }
        if clean.contains("in-addr.arpa") { return "" }
        if let dotIndex = clean.firstIndex(of: ".") {
            let suffix = String(clean[clean.index(after: dotIndex)...]).lowercased()
            if suffix.contains("attlocal") || suffix.contains("home") || suffix.contains("lan")
                || suffix.contains("router") || suffix.contains("gateway") || suffix.contains("internal") {
                clean = String(clean[..<dotIndex])
            }
        }
        return clean.isEmpty ? "" : clean
    }

    // MARK: - Reverse DNS via getnameinfo ─────────────────────────────────

    nonisolated private func resolveHostnameAsync(ip: String) async -> String? {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var resolved = false
            let lock = NSLock()

            DispatchQueue(label: "com.wificheck.getnameinfo.\(ip)").async {
                var sa = sockaddr_in()
                sa.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                sa.sin_family = sa_family_t(AF_INET)
                inet_pton(AF_INET, ip, &sa.sin_addr)

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = withUnsafePointer(to: &sa) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                        getnameinfo(saPtr, socklen_t(MemoryLayout<sockaddr_in>.size),
                                    &hostname, socklen_t(hostname.count), nil, 0, 0)
                    }
                }

                lock.lock()
                guard !resolved else { lock.unlock(); return }
                resolved = true
                lock.unlock()

                if result == 0 {
                    let name = String(cString: hostname)
                    if name != ip && !name.isEmpty {
                        continuation.resume(returning: name)
                        return
                    }
                }
                continuation.resume(returning: nil)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                lock.lock()
                guard !resolved else { lock.unlock(); return }
                resolved = true
                lock.unlock()
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Helpers ─────────────────────────────────────────────────────

    nonisolated private func resolveLocalHostname(_ hostname: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var hints = addrinfo()
                hints.ai_family = AF_INET
                hints.ai_socktype = SOCK_STREAM
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(hostname, nil, &hints, &result)
                defer { if result != nil { freeaddrinfo(result) } }

                guard status == 0, let info = result,
                      let addr = info.pointee.ai_addr,
                      info.pointee.ai_family == AF_INET else {
                    continuation.resume(returning: nil)
                    return
                }
                var sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                inet_ntop(AF_INET, &sin.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                continuation.resume(returning: String(cString: buf))
            }
        }
    }

    /// Reads the system ARP cache via sysctl.
    /// Returns a map of IP → MAC bytes (6 bytes for Ethernet, empty if unavailable).
    ///
    /// sizeof(rt_msghdr) = 92 on iOS/macOS arm64.
    /// Layout per entry: rt_msghdr(92) | sockaddr_in(16)[dst IP] | sockaddr_dl(variable)[MAC]
    nonisolated private func readARPCache(subnet: String) -> [String: [UInt8]] {
        let RTF_LLINFO_VALUE: Int32 = 0x400
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_LLINFO_VALUE]
        var needed = 0
        guard sysctl(&mib, 6, nil, &needed, nil, 0) == 0, needed > 0 else { return [:] }

        // Over-allocate by 25% + 512 bytes to handle entries added between the two sysctl calls.
        let bufSize = needed + needed / 4 + 512
        var buf = [UInt8](repeating: 0, count: bufSize)
        var actualNeeded = bufSize
        guard sysctl(&mib, 6, &buf, &actualNeeded, nil, 0) == 0 else { return [:] }

        var result: [String: [UInt8]] = [:]
        var offset = 0
        // sizeof(rt_msghdr) on iOS/macOS arm64:
        //   2+1+1+2+[2 pad]+4+4+4+4+4+4 = 32 bytes of fixed header fields
        //   + struct rt_metrics (56 bytes) = 92 bytes total
        let rtmHdrSize = 92

        while offset < actualNeeded {
            guard offset + 4 <= actualNeeded else { break }
            let msgLen = Int(UInt16(buf[offset]) | (UInt16(buf[offset + 1]) << 8))
            // Each valid ARP entry needs room for header + sockaddr_in (16) + sockaddr_dl (min 8)
            guard msgLen >= rtmHdrSize + 24, offset + msgLen <= actualNeeded else { break }

            // ── RTA_DST: sockaddr_in immediately after rt_msghdr ──
            let sinPos = offset + rtmHdrSize
            guard buf[sinPos] == 16 && buf[sinPos + 1] == 2 else { // sa_len=16, AF_INET=2
                offset += msgLen
                continue
            }
            let a0 = buf[sinPos + 4], a1 = buf[sinPos + 5]
            let a2 = buf[sinPos + 6], a3 = buf[sinPos + 7]
            let ip = "\(a0).\(a1).\(a2).\(a3)"
            guard ip.hasPrefix("\(subnet).") && a3 > 0 && a3 < 255 else {
                offset += msgLen
                continue
            }

            // ── RTA_GATEWAY: sockaddr_dl immediately after sockaddr_in ──
            // sockaddr_dl layout: [sdl_len][sdl_family=18][sdl_index×2][sdl_type][sdl_nlen][sdl_alen][sdl_slen][name+MAC...]
            var mac: [UInt8] = []
            let sdlPos = sinPos + 16 // sockaddr_in is exactly 16 bytes
            if sdlPos + 8 <= offset + msgLen {
                let sdlFamily = buf[sdlPos + 1]
                let sdlNLen   = Int(buf[sdlPos + 5]) // interface name length (e.g. 3 for "en0")
                let sdlALen   = Int(buf[sdlPos + 6]) // address length (6 for Ethernet)
                let macStart  = sdlPos + 8 + sdlNLen
                if sdlFamily == 18 && sdlALen == 6 && macStart + 6 <= offset + msgLen {
                    mac = Array(buf[macStart..<macStart + 6])
                }
            }

            result[ip] = mac
            offset += msgLen
        }

        return result
    }

    nonisolated private func cleanIPString(_ raw: String) -> String? {
        var ip = raw
        if ip.hasPrefix("::ffff:") { ip = String(ip.dropFirst(7)) }
        if let pct = ip.firstIndex(of: "%") { ip = String(ip[ip.startIndex..<pct]) }
        let parts = ip.split(separator: ".")
        guard parts.count == 4, parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return ip
    }

}

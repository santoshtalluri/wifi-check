//
//  NetworkViewModel.swift
//  WiFi Check (tvOS)
//

import Foundation
import SwiftUI
import Combine
import Network

/// Main view model driving the entire app state
/// Coordinates all services and publishes UI-ready data
@MainActor
final class NetworkViewModel: ObservableObject {

    // MARK: - Published State

    @Published var score: QualityScore = .zero
    @Published var metrics: NetworkMetrics = .empty
    @Published var wifiInfo: WiFiInfo = WiFiInfo()
    @Published var isVPNActive: Bool = false
    @Published var isConnectedToWiFi: Bool = true
    @Published var hasLocalNetworkPermission: Bool = true
    @Published var isPublicNetwork: Bool = false
    @Published var isEnterprise: Bool = false
    @Published var isMeasuring: Bool = false
    @Published var countdown: Int = 5
    @Published var updateFrequency: Int = 5   // 5, 15, or 0 (manual)
    @Published var accentColorHex: String = "30D158"
    @Published var publicBannerDismissed: Bool = false

    // TV Dashboard properties
    @Published var scoreTrend: [Int] = []
    @Published var sampleCount: Int = 0
    @Published var sessionStartTime: Date = Date()

    // Bandwidth monitoring
    @Published var bandwidth: DeviceBandwidthService.BandwidthReading = .zero
    @Published var bandwidthHistory: [DeviceBandwidthService.BandwidthReading] = []
    @Published var peakDownload: Double = 0
    @Published var peakUpload: Double = 0

    var accentColor: Color { Color(hex: accentColorHex) }

    // MARK: - Computed Properties (TV Dashboard)

    var bottleneckMetric: String? {
        let scores = [
            ("Download Speed", score.throughputSubScore),
            ("Packet Loss", score.packetLossSubScore),
            ("Jitter", score.jitterSubScore),
            ("Internet Latency", score.internetSubScore),
            ("Router Latency", score.routerSubScore),
            ("DNS Lookup", score.dnsSubScore)
        ]
        guard let worst = scores.min(by: { $0.1 < $1.1 }), worst.1 < 70 else { return nil }
        return worst.0
    }

    var trendPercentage: Int {
        guard scoreTrend.count >= 2 else { return 0 }
        let first = scoreTrend.first!
        let last = scoreTrend.last!
        guard first > 0 else { return 0 }
        return Int(((Double(last) - Double(first)) / Double(first)) * 100)
    }

    var sessionUptime: String {
        let elapsed = Int(Date().timeIntervalSince(sessionStartTime))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    struct ActivityRecommendation: Identifiable {
        let id = UUID()
        let name: String
        let status: ActivityStatus
    }

    enum ActivityStatus {
        case good, borderline, poor
    }

    var activityRecommendations: [ActivityRecommendation] {
        let tp = metrics.throughput ?? 0
        let lat = metrics.internetLatency ?? 999
        let jit = metrics.jitter ?? 999
        let loss = metrics.packetLoss ?? 100
        var recs: [ActivityRecommendation] = []
        recs.append(.init(name: "Web Browsing", status: tp >= 1 ? .good : .poor))
        recs.append(.init(name: "Music Streaming", status: tp >= 2 ? .good : .poor))
        recs.append(.init(name: "HD Streaming", status: tp >= 5 ? .good : (tp >= 3 ? .borderline : .poor)))
        recs.append(.init(name: "Video Calls", status: tp >= 5 && loss < 2 ? .good : (tp >= 3 ? .borderline : .poor)))
        recs.append(.init(name: "Online Gaming", status: lat < 50 && jit < 15 ? .good : (lat < 80 ? .borderline : .poor)))
        recs.append(.init(name: "4K Streaming", status: tp >= 25 ? .good : (tp >= 15 ? .borderline : .poor)))
        recs.append(.init(name: "Large Downloads", status: tp >= 50 ? .good : (tp >= 20 ? .borderline : .poor)))
        recs.append(.init(name: "Cloud Backup", status: tp >= 50 ? .good : (tp >= 20 ? .borderline : .poor)))
        return recs
    }

    // MARK: - Services

    private let networkMonitor = NetworkMonitor()
    private let vpnService = VPNDetectionService()
    private let wifiInfoService = WiFiInfoService()
    private let pingService = PingService()
    private let packetLossService = PacketLossService()
    private let dnsService = DNSService()
    private let throughputService = ThroughputService()
    private let bandwidthService = DeviceBandwidthService()

    private var cancellables = Set<AnyCancellable>()
    private var measurementTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var bandwidthTask: Task<Void, Never>?
    private var consecutiveFailures: Int = 0

    // Rolling average buffer for score smoothing (last 5 readings)
    private var compositeBuffer: [Int] = []
    private let bufferSize = 5

    // Throughput throttle — 5MB download is expensive; only re-run every 5 minutes
    private var lastThroughputDate: Date?
    private var lastCachedThroughput: Double?
    private let throughputInterval: TimeInterval = 300

    // MARK: - Init

    init() {
        // Load persisted preferences
        updateFrequency = UserDefaultsManager.updateFrequency
        accentColorHex = UserDefaultsManager.accentColorHex

        // Bind services
        networkMonitor.$isConnectedToWiFi
            .receive(on: RunLoop.main)
            .assign(to: &$isConnectedToWiFi)

        vpnService.$isVPNActive
            .receive(on: RunLoop.main)
            .assign(to: &$isVPNActive)

        wifiInfoService.$wifiInfo
            .receive(on: RunLoop.main)
            .assign(to: &$wifiInfo)

        // React to WiFi and VPN changes
        $isConnectedToWiFi
            .combineLatest($isVPNActive)
            .sink { [weak self] (wifi, vpn) in
                if wifi && !vpn {
                    self?.startMeasurementLoop()
                } else {
                    self?.stopMeasurementLoop()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Bandwidth Monitoring

    func startBandwidthMonitoring() {
        bandwidthService.recordSessionStart()
        stopBandwidthMonitoring()
        bandwidthTask = Task {
            while !Task.isCancelled {
                let reading = bandwidthService.measure()
                bandwidth = reading
                bandwidthHistory.append(reading)
                if bandwidthHistory.count > 120 { bandwidthHistory.removeFirst() }
                if reading.downloadBytesPerSec > peakDownload {
                    peakDownload = reading.downloadBytesPerSec
                }
                if reading.uploadBytesPerSec > peakUpload {
                    peakUpload = reading.uploadBytesPerSec
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s interval
            }
        }
    }

    func stopBandwidthMonitoring() {
        bandwidthTask?.cancel()
        bandwidthTask = nil
    }

    // MARK: - Frequency Control

    func setUpdateFrequency(_ freq: Int) {
        updateFrequency = freq
        UserDefaultsManager.updateFrequency = freq
        if freq > 0 {
            startMeasurementLoop()
        }
    }

    func setAccentColor(_ hex: String) {
        accentColorHex = hex
        UserDefaultsManager.accentColorHex = hex
    }

    // MARK: - Manual Refresh

    func manualRefresh() {
        lastThroughputDate = nil  // Force fresh throughput on manual refresh
        Task { await performMeasurement() }
    }

    // MARK: - Measurement Loop

    private func startMeasurementLoop() {
        stopMeasurementLoop()
        guard updateFrequency > 0 else { return }

        measurementTask = Task {
            while !Task.isCancelled {
                await performMeasurement()
                startCountdown()
                try? await Task.sleep(nanoseconds: UInt64(updateFrequency) * 1_000_000_000)
            }
        }
    }

    private func stopMeasurementLoop() {
        measurementTask?.cancel()
        measurementTask = nil
        countdownTask?.cancel()
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = updateFrequency
        countdownTask = Task {
            while countdown > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }

    // MARK: - Core Measurement

    private func performMeasurement() async {
        guard isConnectedToWiFi && !isVPNActive else { return }
        isMeasuring = true

        // Ensure WiFi info is fresh before measuring (gateway IP needed for router ping)
        if wifiInfo.gatewayIP == "--" {
            wifiInfoService.refreshInfo()
            // Give async publish a moment to propagate
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let gatewayIP = wifiInfo.gatewayIP != "--" ? wifiInfo.gatewayIP : "192.168.1.1"

        // Skip throughput (5MB download) if measured recently — run at most every 5 minutes.
        // Also re-run immediately if cached value is nil (previous test failed → blank display).
        let shouldRunThroughput: Bool = {
            guard let last = lastThroughputDate else { return true }
            if Date().timeIntervalSince(last) >= throughputInterval { return true }
            return lastCachedThroughput == nil  // retry if last download test failed
        }()

        // Run all measurements concurrently
        async let routerPing = pingService.pingGateway(ip: gatewayIP)
        async let packetLoss = packetLossService.measurePacketLoss(host: gatewayIP)
        async let internetPing = pingService.ping(host: "8.8.8.8")
        async let dnsSpeed = dnsService.measureDNSSpeed()
        async let maybeThroughput: Double? = shouldRunThroughput ? throughputService.measureThroughput() : nil
        async let jitter = pingService.measureJitter()

        let router = await routerPing
        let loss = await packetLoss
        let internet = await internetPing
        let dns = await dnsSpeed
        let freshTp = await maybeThroughput
        let jit = await jitter

        // Only stamp lastThroughputDate when the test succeeded — a nil result means
        // the test failed, so the next cycle will retry instead of showing blank for 5 min.
        let tp: Double?
        if shouldRunThroughput {
            if freshTp != nil { lastThroughputDate = Date() }
            lastCachedThroughput = freshTp
            tp = freshTp
        } else {
            tp = lastCachedThroughput
        }

        metrics = NetworkMetrics(
            routerLatency: router,
            packetLoss: loss,
            internetLatency: internet,
            dnsSpeed: dns,
            throughput: tp,
            jitter: jit
        )

        let rawScore = ScoreCalculator.calculate(from: metrics)

        // Smooth composite with rolling average
        // Pre-fill buffer on first reading so gauge color is correct immediately
        if compositeBuffer.isEmpty {
            compositeBuffer = Array(repeating: rawScore.composite, count: bufferSize)
        } else {
            compositeBuffer.append(rawScore.composite)
            if compositeBuffer.count > bufferSize {
                compositeBuffer.removeFirst()
            }
        }
        let smoothed = compositeBuffer.reduce(0, +) / compositeBuffer.count

        score = QualityScore(
            composite: smoothed,
            throughputSubScore: rawScore.throughputSubScore,
            packetLossSubScore: rawScore.packetLossSubScore,
            jitterSubScore: rawScore.jitterSubScore,
            internetSubScore: rawScore.internetSubScore,
            routerSubScore: rawScore.routerSubScore,
            dnsSubScore: rawScore.dnsSubScore,
            level: ScoreCalculator.qualityLevel(for: smoothed)
        )

        // Track trend (last 12 readings)
        scoreTrend.append(smoothed)
        if scoreTrend.count > 12 { scoreTrend.removeFirst() }
        sampleCount += 1

        // Only mark permission denied if ALL measurements failed
        if router == nil && internet == nil && dns == nil && tp == nil {
            consecutiveFailures += 1
            if consecutiveFailures >= 3 {
                hasLocalNetworkPermission = false
            }
        } else {
            consecutiveFailures = 0
            hasLocalNetworkPermission = true
        }

        // Refresh WiFi info
        wifiInfoService.refreshInfo()

        isMeasuring = false
    }

    // MARK: - Lifecycle (pause on lock, resume on unlock)

    func pauseMeasurements() {
        stopMeasurementLoop()
        stopBandwidthMonitoring()
    }

    func resumeMeasurements() {
        if isConnectedToWiFi && !isVPNActive {
            startMeasurementLoop()
        }
        startBandwidthMonitoring()
    }

    // MARK: - Cleanup (privacy: wipe all data)

    func clearAllData() {
        stopMeasurementLoop()
        stopBandwidthMonitoring()
        compositeBuffer.removeAll()
        score = .zero
        metrics = .empty
        wifiInfo = WiFiInfo()
        scoreTrend.removeAll()
        sampleCount = 0
        sessionStartTime = Date()
        bandwidth = .zero
        bandwidthHistory.removeAll()
        peakDownload = 0
        peakUpload = 0
    }
}

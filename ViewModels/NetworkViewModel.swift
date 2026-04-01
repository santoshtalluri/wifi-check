//
//  NetworkViewModel.swift
//  WiFiQualityMonitor
//

import Foundation
import SwiftUI
import Combine
import Network
import os.log

private let logger = Logger(subsystem: "com.wqm", category: "NetworkVM")

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
    @Published var countdown: Int = 2
    @Published var updateFrequency: Int = 2   // 2, 5, or 0 (manual)
    @Published var accentColorHex: String = "30D158"
    @Published var publicBannerDismissed: Bool = false
    @Published var adBannerDismissed: Bool = false

    var accentColor: Color { Color(hex: accentColorHex) }

    // MARK: - Services

    private let networkMonitor = NetworkMonitor()
    private let vpnService = VPNDetectionService()
    private let wifiInfoService = WiFiInfoService()
    private let pingService = PingService()
    private let packetLossService = PacketLossService()
    private let dnsService = DNSService()
    private let throughputService = ThroughputService()

    private var cancellables = Set<AnyCancellable>()
    private var measurementTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    // MARK: - Smoothing

    private var recentMetrics: [NetworkMetrics] = []
    private let smoothingWindowSize = 5

    // MARK: - Init

    init() {
        // Load persisted preferences
        updateFrequency = UserDefaultsManager.updateFrequency
        accentColorHex = UserDefaultsManager.accentColorHex

        // Bind services
        networkMonitor.$isConnectedToWiFi
            .receive(on: RunLoop.main)
            .sink { [weak self] wifi in
                logger.info("🔵 isConnectedToWiFi changed to: \(wifi)")
                self?.isConnectedToWiFi = wifi
            }
            .store(in: &cancellables)

        vpnService.$isVPNActive
            .receive(on: RunLoop.main)
            .sink { [weak self] vpn in
                logger.info("🔵 isVPNActive changed to: \(vpn)")
                self?.isVPNActive = vpn
            }
            .store(in: &cancellables)

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

    // MARK: - Permissions

    func requestPermissions() {
        wifiInfoService.requestLocationPermission()
        // Local Network permission is triggered automatically on first ping
        // ATT is requested later (see MainView)
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
        guard isConnectedToWiFi && !isVPNActive else {
            logger.warning("⚠️ Skipping measurement: wifi=\(self.isConnectedToWiFi) vpn=\(self.isVPNActive)")
            return
        }
        isMeasuring = true

        // Use nil if gateway is unknown — don't probe a random IP
        let gatewayIP: String? = wifiInfo.gatewayIP != "--" ? wifiInfo.gatewayIP : nil
        logger.info("📡 Starting measurement, gateway=\(gatewayIP ?? "unknown")")

        // Run measurements concurrently
        async let routerPing: Double? = {
            guard let gw = gatewayIP else { return nil }
            return await pingService.pingGateway(ip: gw)
        }()
        async let packetLoss: Double = {
            guard let gw = gatewayIP else { return 0.0 }
            return await packetLossService.measurePacketLoss(host: gw)
        }()
        async let internetPing = pingService.ping(host: "8.8.8.8")
        async let dnsSpeed = dnsService.measureDNSSpeed()
        async let throughputMbps = throughputService.measureThroughput()
        async let jitterMs = pingService.measureJitter()

        let router = await routerPing
        let loss = await packetLoss
        let internet = await internetPing
        let dns = await dnsSpeed
        let throughput = await throughputMbps
        let jitter = await jitterMs

        logger.info("📊 Results: router=\(String(describing: router)) loss=\(loss) internet=\(String(describing: internet)) dns=\(String(describing: dns)) throughput=\(String(describing: throughput)) jitter=\(String(describing: jitter))")

        let currentMetrics = NetworkMetrics(
            routerLatency: router,
            packetLoss: loss,
            internetLatency: internet,
            dnsSpeed: dns,
            throughput: throughput,
            jitter: jitter
        )

        // Add to rolling window and compute smoothed values
        recentMetrics.append(currentMetrics)
        if recentMetrics.count > smoothingWindowSize {
            recentMetrics.removeFirst()
        }

        let smoothed = smoothedMetrics()
        metrics = smoothed
        score = ScoreCalculator.calculate(from: smoothed)

        logger.info("📊 Score: \(self.score.composite) (window: \(self.recentMetrics.count)) isWiFi=\(self.isConnectedToWiFi)")

        // If any measurement succeeded, we have network access
        if router != nil || internet != nil || dns != nil {
            hasLocalNetworkPermission = true
        }

        // Refresh WiFi info
        wifiInfoService.refreshInfo()

        isMeasuring = false
    }

    // MARK: - Smoothing

    /// Compute smoothed metrics using median of recent values.
    /// Median is robust against outliers — a single spike doesn't affect the result.
    private func smoothedMetrics() -> NetworkMetrics {
        let routerValues = recentMetrics.compactMap { $0.routerLatency }
        let lossValues = recentMetrics.compactMap { $0.packetLoss }
        let internetValues = recentMetrics.compactMap { $0.internetLatency }
        let dnsValues = recentMetrics.compactMap { $0.dnsSpeed }
        let throughputValues = recentMetrics.compactMap { $0.throughput }
        let jitterValues = recentMetrics.compactMap { $0.jitter }

        return NetworkMetrics(
            routerLatency: median(routerValues),
            packetLoss: median(lossValues),
            internetLatency: median(internetValues),
            dnsSpeed: median(dnsValues),
            throughput: median(throughputValues),
            jitter: median(jitterValues)
        )
    }

    /// Compute median of an array. Returns nil if empty.
    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }

    // MARK: - Cleanup (privacy: wipe all data)

    func clearAllData() {
        stopMeasurementLoop()
        recentMetrics.removeAll()
        score = .zero
        metrics = .empty
        wifiInfo = WiFiInfo()
    }
}

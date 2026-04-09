//
//  NetworkViewModel.swift
//  WiFi Check
//

import Foundation
import SwiftUI
import Combine
import Network
import UIKit

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
    @Published var adBannerDismissed: Bool = false
    @Published var throughputRunCount: Int = 0   // # of download/upload tests run this session

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
    private var consecutiveFailures: Int = 0

    // Throughput: run once on first launch, then only on manual "Run Test" tap.
    // manualRefresh() resets lastThroughputDate to nil to trigger a re-run.
    private var lastThroughputDate: Date?
    private var lastThroughputMbps: Double?
    private var lastUploadMbps: Double?
    private let throughputInterval: TimeInterval = .greatestFiniteMagnitude

    // Rolling average buffer for score smoothing (last 5 readings)
    private var compositeBuffer: [Int] = []
    private let bufferSize = 5

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

        // Pause measurements when app backgrounds to conserve battery
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pauseMeasurements() }
        }
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.resumeMeasurements() }
        }
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
        // Force throughput re-run on manual refresh
        lastThroughputDate = nil
        Task { await performMeasurement() }
    }

    /// Async version for SwiftUI pull-to-refresh (.refreshable)
    func refresh() async {
        // Force throughput re-run on manual refresh
        lastThroughputDate = nil
        await performMeasurement()
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

        // Throughput is expensive (8 MB per run). Only run every 5 minutes;
        // reuse last known values in between to save battery and data.
        // Also re-run immediately if cached values are nil (previous test failed → blank display).
        let shouldRunThroughput: Bool = {
            guard let last = lastThroughputDate else { return true }
            if Date().timeIntervalSince(last) >= throughputInterval { return true }
            return lastThroughputMbps == nil  // retry if last download test failed
        }()

        // Run latency/loss measurements concurrently with conditional throughput
        async let routerPing = pingService.pingGateway(ip: gatewayIP)
        async let packetLoss = packetLossService.measurePacketLoss(host: gatewayIP)
        async let internetPing = pingService.ping(host: "8.8.8.8")
        async let dnsSpeed = dnsService.measureDNSSpeed()
        async let jitter = pingService.measureJitter()
        async let maybeDownload: Double? = shouldRunThroughput ? throughputService.measureThroughput() : nil
        async let maybeUpload: Double? = shouldRunThroughput ? throughputService.measureUploadThroughput() : nil

        let router = await routerPing
        let loss = await packetLoss
        let internet = await internetPing
        let dns = await dnsSpeed
        let jit = await jitter
        let freshDownload = await maybeDownload
        let freshUpload = await maybeUpload

        // Commit fresh throughput values or reuse cached.
        // Only stamp lastThroughputDate when the test succeeded — a nil result means
        // the test failed, so the next cycle will retry instead of showing blank for 5 min.
        let tp: Double?
        let up: Double?
        if shouldRunThroughput {
            if freshDownload != nil || freshUpload != nil {
                lastThroughputDate = Date()
                throughputRunCount += 1
            }
            lastThroughputMbps = freshDownload
            lastUploadMbps = freshUpload
            tp = freshDownload
            up = freshUpload
        } else {
            tp = lastThroughputMbps
            up = lastUploadMbps
        }

        metrics = NetworkMetrics(
            routerLatency: router,
            packetLoss: loss,
            internetLatency: internet,
            dnsSpeed: dns,
            throughput: tp,
            jitter: jit,
            uploadThroughput: up
        )

        let rawScore = ScoreCalculator.calculate(from: metrics)

        // Smooth composite with rolling average
        compositeBuffer.append(rawScore.composite)
        if compositeBuffer.count > bufferSize {
            compositeBuffer.removeFirst()
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
    }

    func resumeMeasurements() {
        if isConnectedToWiFi && !isVPNActive {
            startMeasurementLoop()
        }
    }

    // MARK: - Cleanup (privacy: wipe all data)

    func clearAllData() {
        stopMeasurementLoop()
        compositeBuffer.removeAll()
        score = .zero
        metrics = .empty
        wifiInfo = WiFiInfo()
    }
}

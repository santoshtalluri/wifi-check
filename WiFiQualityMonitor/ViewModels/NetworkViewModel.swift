//
//  NetworkViewModel.swift
//  WiFiQualityMonitor
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

    private var cancellables = Set<AnyCancellable>()
    private var measurementTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var consecutiveFailures: Int = 0

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
        guard isConnectedToWiFi && !isVPNActive else { return }
        isMeasuring = true

        let gatewayIP = wifiInfo.gatewayIP != "--" ? wifiInfo.gatewayIP : "192.168.1.1"

        // Run measurements concurrently
        async let routerPing = pingService.pingGateway(ip: gatewayIP)
        async let packetLoss = packetLossService.measurePacketLoss(host: gatewayIP)
        async let internetPing = pingService.ping(host: "8.8.8.8")
        async let dnsSpeed = dnsService.measureDNSSpeed()

        let router = await routerPing
        let loss = await packetLoss
        let internet = await internetPing
        let dns = await dnsSpeed

        metrics = NetworkMetrics(
            routerLatency: router,
            packetLoss: loss,
            internetLatency: internet,
            dnsSpeed: dns
        )

        score = ScoreCalculator.calculate(from: metrics)

        // Only mark permission denied if ALL measurements failed
        // (router ping can fail for many reasons — port 80 not open, etc.)
        if router == nil && internet == nil && dns == nil {
            // Everything failed — likely no network permission or no connectivity
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

    // MARK: - Cleanup (privacy: wipe all data)

    func clearAllData() {
        stopMeasurementLoop()
        score = .zero
        metrics = .empty
        wifiInfo = WiFiInfo()
    }
}

//
//  SpeedTestViewModel.swift
//  WiFiQualityMonitor
//

import Foundation
import Combine

/// Speed test state and results
/// Phase 1: Simulated results based on current quality score
/// Phase 2: Real Ookla SDK or NDT7 integration
@MainActor
final class SpeedTestViewModel: ObservableObject {

    enum TestState: Equatable {
        case idle
        case connecting
        case testingDownload
        case testingUpload
        case finishing
        case completed
    }

    @Published var state: TestState = .idle
    @Published var downloadMbps: Double = 0
    @Published var uploadMbps: Double = 0
    @Published var pingMs: Int = 0
    @Published var lastTestedText: String = "Tap to run speed test"
    @Published var isExpanded: Bool = false

    /// Run a simulated speed test based on current score
    func runTest(currentScore: Int) async {
        state = .connecting
        try? await Task.sleep(nanoseconds: 800_000_000)

        state = .testingDownload
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        state = .testingUpload
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        state = .finishing
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Simulate results scaled to quality score
        let factor = Double(currentScore) / 100.0
        downloadMbps = Double.random(in: (50 * factor)...(200 * factor)).rounded()
        uploadMbps = Double.random(in: (10 * factor)...(50 * factor)).rounded()
        pingMs = Int(Double.random(in: (5 / max(factor, 0.1))...(30 / max(factor, 0.1))))

        state = .completed
        lastTestedText = "Last tested just now. Tap again to retest."
    }

    var statusText: String {
        switch state {
        case .idle: return ""
        case .connecting: return "Connecting to server..."
        case .testingDownload: return "Testing download..."
        case .testingUpload: return "Testing upload..."
        case .finishing: return "Finishing up..."
        case .completed: return ""
        }
    }
}

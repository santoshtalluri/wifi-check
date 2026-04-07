//
//  WiFiCheckTVUITests.swift
//  WiFiCheckTVUITests
//
//  22-test suite for the tvOS target (Wi​Fi​Check ​TV).
//  Must be added to a dedicated tvOS UI test target in Xcode:
//    File → New → Target → tvOS UI Testing Bundle → name "WiFiCheckTVUITests"
//
//  Tab identifiers come from the SwiftUI TabView item labels:
//    "Dashboard", "Bandwidth", "Speed Test", "Network Scan", "Settings"
//
//  Target run time: < 4 minutes on real Apple TV.
//

import XCTest

final class WiFiCheckTVUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func goTo(_ tab: String) {
        app.tabBars.buttons[tab].tap()
    }

    /// Dismiss a system permission alert if one appears (location, local network).
    private func dismissSystemAlertIfPresent() {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            let allow = alert.buttons["Allow While Using App"]
            let ok    = alert.buttons["OK"]
            let allow2 = alert.buttons["Allow"]
            if allow.exists  { allow.tap()  }
            else if ok.exists    { ok.tap()    }
            else if allow2.exists { allow2.tap() }
        }
    }

    // =========================================================================
    // MARK: - 01. App launches without crash
    // =========================================================================

    func test_01_appLaunchesWithoutCrash() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8),
                      "tvOS tab bar must appear on launch")
    }

    // =========================================================================
    // MARK: - 02. All 5 tabs are present
    // =========================================================================

    func test_02_allFiveTabsPresent() {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 8))

        for tab in ["Dashboard", "Bandwidth", "Speed Test", "Network Scan", "Settings"] {
            XCTAssertTrue(bar.buttons[tab].waitForExistence(timeout: 5),
                          "Tab '\(tab)' must exist in the tab bar")
        }
    }

    // =========================================================================
    // MARK: - 03. Dashboard tab loads
    // =========================================================================

    func test_03_dashboardTabLoads() {
        goTo("Dashboard")
        // TVGaugeCard shows "Connected" label beneath the SSID
        let connected = app.staticTexts["Connected"].waitForExistence(timeout: 8)
        let score = app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+'")).firstMatch
            .waitForExistence(timeout: 8)
        XCTAssertTrue(connected || score,
                      "Dashboard must show gauge card with 'Connected' or a numeric score")
    }

    // =========================================================================
    // MARK: - 04. Dashboard shows score breakdown section
    // =========================================================================

    func test_04_dashboardShowsScoreBreakdown() {
        goTo("Dashboard")
        XCTAssertTrue(app.staticTexts["Score Breakdown"].waitForExistence(timeout: 8),
                      "Dashboard must contain the Score Breakdown card")
    }

    // =========================================================================
    // MARK: - 05. Dashboard shows Network Info card
    // =========================================================================

    func test_05_dashboardShowsNetworkInfoCard() {
        goTo("Dashboard")
        XCTAssertTrue(app.staticTexts["Network Info"].waitForExistence(timeout: 8),
                      "Dashboard must contain the Network Info card")
    }

    // =========================================================================
    // MARK: - 06. Network Info card shows Device IP row
    // =========================================================================

    func test_06_networkInfoCardShowsDeviceIPRow() {
        goTo("Dashboard")
        XCTAssertTrue(app.staticTexts["Device IP"].waitForExistence(timeout: 8),
                      "Network Info card must show 'Device IP' row")
    }

    // =========================================================================
    // MARK: - 07. Network Info card shows connection Type row
    // =========================================================================

    func test_07_networkInfoCardShowsConnectionType() {
        goTo("Dashboard")
        // "Type" label is always present regardless of WiFi or Ethernet
        XCTAssertTrue(app.staticTexts["Type"].waitForExistence(timeout: 8),
                      "Network Info card must show 'Type' row (Wi-Fi / Ethernet / USB-C LAN)")
    }

    // =========================================================================
    // MARK: - 08. Score breakdown legend is visible
    // =========================================================================

    func test_08_scoreBreakdownLegendVisible() {
        goTo("Dashboard")
        // The weight footnote text is always rendered at the bottom of TVScoreBreakdown
        let legend = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Throughput' AND label CONTAINS 'Latency'")
        ).firstMatch
        XCTAssertTrue(legend.waitForExistence(timeout: 8),
                      "Score Breakdown must show the weight footnote legend")
    }

    // =========================================================================
    // MARK: - 09. Bandwidth tab loads
    // =========================================================================

    func test_09_bandwidthTabLoads() {
        goTo("Bandwidth")
        XCTAssertTrue(app.staticTexts["Device Bandwidth"].waitForExistence(timeout: 8),
                      "Bandwidth tab must show 'Device Bandwidth' heading")
    }

    // =========================================================================
    // MARK: - 10. Bandwidth shows download and upload cards
    // =========================================================================

    func test_10_bandwidthShowsDownloadAndUpload() {
        goTo("Bandwidth")
        XCTAssertTrue(app.staticTexts["DOWNLOAD"].waitForExistence(timeout: 8),
                      "Bandwidth tab must show DOWNLOAD label")
        XCTAssertTrue(app.staticTexts["UPLOAD"].waitForExistence(timeout: 8),
                      "Bandwidth tab must show UPLOAD label")
    }

    // =========================================================================
    // MARK: - 11. Bandwidth shows session totals
    // =========================================================================

    func test_11_bandwidthShowsSessionTotals() {
        goTo("Bandwidth")
        XCTAssertTrue(app.staticTexts["Session Totals"].waitForExistence(timeout: 8),
                      "Bandwidth tab must show Session Totals panel")
    }

    // =========================================================================
    // MARK: - 12. Speed Test tab loads
    // =========================================================================

    func test_12_speedTestTabLoads() {
        goTo("Speed Test")
        XCTAssertTrue(app.staticTexts["DOWNLOAD SPEED"].waitForExistence(timeout: 8),
                      "Speed Test tab must show 'DOWNLOAD SPEED' heading")
    }

    // =========================================================================
    // MARK: - 13. Speed Test "Test All Sites" button exists
    // =========================================================================

    func test_13_testAllSitesButtonExists() {
        goTo("Speed Test")
        let btn = app.buttons["tvTestAllButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 8),
                      "Speed Test tab must have the 'Test All Sites' button")
        XCTAssertTrue(btn.isHittable, "'Test All Sites' button must be hittable")
    }

    // =========================================================================
    // MARK: - 14. Speed Test shows three site cards
    // =========================================================================

    func test_14_speedTestShowsThreeSiteCards() {
        goTo("Speed Test")
        for site in ["Google", "Facebook", "Apple"] {
            XCTAssertTrue(app.staticTexts[site].waitForExistence(timeout: 8),
                          "Speed Test tab must show '\(site)' site card")
        }
    }

    // =========================================================================
    // MARK: - 15. Network Scan tab loads
    // =========================================================================

    func test_15_networkScanTabLoads() {
        goTo("Network Scan")
        XCTAssertTrue(app.staticTexts["Network Scan"].waitForExistence(timeout: 8),
                      "Network Scan tab must show 'Network Scan' heading")
    }

    // =========================================================================
    // MARK: - 16. Network Scan has scan button
    // =========================================================================

    func test_16_networkScanHasScanButton() {
        goTo("Network Scan")
        let btn = app.buttons["tvScanNetworkButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 8),
                      "Network Scan tab must have the 'Scan Network' button")
    }

    // =========================================================================
    // MARK: - 17. Network Scan shows placeholder before scanning
    // =========================================================================

    func test_17_networkScanPlaceholderBeforeScan() {
        goTo("Network Scan")
        // Placeholder text shown before any scan is initiated
        let placeholder = app.staticTexts["Press Scan Network to discover devices"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 5),
                      "Network Scan must show placeholder text before scanning begins")
    }

    // =========================================================================
    // MARK: - 18. Settings tab loads
    // =========================================================================

    func test_18_settingsTabLoads() {
        goTo("Settings")
        XCTAssertTrue(app.staticTexts["Preferences"].waitForExistence(timeout: 8),
                      "Settings tab must show 'Preferences' section")
        XCTAssertTrue(app.staticTexts["About"].waitForExistence(timeout: 5),
                      "Settings tab must show 'About' section")
    }

    // =========================================================================
    // MARK: - 19. Settings refresh cycle buttons exist
    // =========================================================================

    func test_19_settingsRefreshCycleButtonsExist() {
        goTo("Settings")
        for pill in ["tvRefreshPill_5s", "tvRefreshPill_15s", "tvRefreshPill_manual"] {
            XCTAssertTrue(app.buttons[pill].waitForExistence(timeout: 8),
                          "Refresh cycle button '\(pill)' must exist in Settings")
        }
    }

    // =========================================================================
    // MARK: - 20. Settings Privacy Policy button opens sheet
    // =========================================================================

    func test_20_settingsPrivacyPolicyButtonOpensSheet() {
        goTo("Settings")
        let btn = app.buttons["tvPrivacyPolicyButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 8))
        btn.tap()
        XCTAssertTrue(app.staticTexts["Privacy Policy"].waitForExistence(timeout: 5),
                      "Privacy Policy sheet must appear after tapping the button")
        // Dismiss
        if app.buttons["Done"].waitForExistence(timeout: 3) { app.buttons["Done"].tap() }
    }

    // =========================================================================
    // MARK: - 21. Settings Terms of Use button opens sheet
    // =========================================================================

    func test_21_settingsTermsButtonOpensSheet() {
        goTo("Settings")
        let btn = app.buttons["tvTermsButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 8))
        btn.tap()
        XCTAssertTrue(app.staticTexts["Terms of Use"].waitForExistence(timeout: 5),
                      "Terms of Use sheet must appear after tapping the button")
        if app.buttons["Done"].waitForExistence(timeout: 3) { app.buttons["Done"].tap() }
    }

    // =========================================================================
    // MARK: - 22. Rapid tab switching does not crash
    // =========================================================================

    func test_22_rapidTabSwitchingDoesNotCrash() {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 8))

        for _ in 1...3 {
            goTo("Bandwidth")
            goTo("Speed Test")
            goTo("Network Scan")
            goTo("Settings")
            goTo("Dashboard")
        }

        XCTAssertTrue(bar.buttons["Dashboard"].isSelected,
                      "App must not crash during rapid tab switching")
    }
}

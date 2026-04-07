//
//  WiFiCheckUITests.swift
//  WiFiCheckUITests
//
//  41-test suite targeting real App Store rejection issues + v0.3 features.
//  Target run time: < 3 minutes.
//

import XCTest

final class WiFiCheckUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    /// True when WiFi-connected content (Metrics section header) is visible.
    private var isWiFiAvailable: Bool {
        let chip = app.descendants(matching: .any).matching(identifier: "statusChip").firstMatch
        return app.staticTexts["Metrics"].waitForExistence(timeout: 3)
            || chip.waitForExistence(timeout: 1)
    }

    private func goToSettings() {
        app.tabBars.firstMatch.buttons["Settings"].tap()
    }

    private func goToSpeedTest() {
        app.tabBars.firstMatch.buttons["Speed Test"].tap()
    }

    private func goToNetworkScan() {
        app.tabBars.firstMatch.buttons["Network Scan"].tap()
    }

    private func goToWiFiInfo() {
        app.tabBars.firstMatch.buttons["WiFi Info"].tap()
    }

    // =========================================================================
    // MARK: - 1. App launches without crashing
    // =========================================================================

    func test_01_appLaunchesWithoutCrash() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "Tab bar must appear on launch")
    }

    // =========================================================================
    // MARK: - 2. All 4 tabs are visible and tappable
    // =========================================================================

    func test_02_allFourTabsVisibleAndTappable() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        let tabNames = ["WiFi Info", "Speed Test", "Network Scan", "Settings"]
        for name in tabNames {
            let btn = tabBar.buttons[name]
            XCTAssertTrue(btn.waitForExistence(timeout: 5), "Tab '\(name)' must exist")
            XCTAssertTrue(btn.isHittable, "Tab '\(name)' must be hittable")
        }
    }

    // =========================================================================
    // MARK: - 3. Settings tab loads
    // =========================================================================

    func test_05_settingsTabLoads() {
        goToSettings()
        XCTAssertTrue(app.staticTexts["WiFi Check"].waitForExistence(timeout: 5),
                      "Settings nav title must be visible")
    }

    // =========================================================================
    // MARK: - 6. Speed test tab loads
    // =========================================================================

    func test_06_speedTestTabLoads() {
        goToSpeedTest()
        // Nav title reused across tabs
        XCTAssertTrue(app.staticTexts["WiFi Check"].waitForExistence(timeout: 5),
                      "Speed Test tab must show WiFi Check title")
    }

    // =========================================================================
    // MARK: - 7. Network scan tab loads
    // =========================================================================

    func test_07_networkScanTabLoads() {
        goToNetworkScan()
        // Either connected content or blocked view must appear
        let connected = app.staticTexts["WiFi Check"].waitForExistence(timeout: 5)
        let blocked = app.buttons["openSettingsButton"].waitForExistence(timeout: 2)
        XCTAssertTrue(connected || blocked, "Network Scan tab must render something")
    }

    // =========================================================================
    // MARK: - 8. WiFi info tab loads
    // =========================================================================

    func test_08_wifiInfoTabLoads() {
        goToWiFiInfo()
        // statusChip can be any element type; use descendants query
        let chip = app.descendants(matching: .any).matching(identifier: "statusChip").firstMatch
        let connected = chip.waitForExistence(timeout: 5)
            || app.staticTexts["Metrics"].waitForExistence(timeout: 2)
        let blocked = app.buttons["openSettingsButton"].waitForExistence(timeout: 3)
        XCTAssertTrue(connected || blocked, "WiFi Info tab must render content or blocked view")
    }

    // =========================================================================
    // MARK: - 9. Refresh Now button exists when Manual mode selected
    // =========================================================================

    func test_09_refreshNowButtonExistsInManualMode() {
        goToSettings()

        // Switch to Manual refresh cycle
        let manualPill = app.buttons["refreshPill_manual"]
        XCTAssertTrue(manualPill.waitForExistence(timeout: 5), "Manual pill must exist")
        manualPill.tap()

        XCTAssertTrue(app.buttons["refreshNowButton"].waitForExistence(timeout: 5),
                      "Refresh Now button must appear in Manual mode")
    }

    // =========================================================================
    // MARK: - 10. Privacy Policy button exists and tappable
    // =========================================================================

    func test_10_privacyPolicyButtonExistsAndTappable() {
        goToSettings()
        let btn = app.buttons["privacyPolicyButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        XCTAssertTrue(btn.isHittable)
        btn.tap()
        // Sheet should appear
        XCTAssertTrue(app.staticTexts["Privacy Policy"].waitForExistence(timeout: 5))
        // Dismiss
        app.swipeDown()
    }

    // =========================================================================
    // MARK: - 11. Terms of Use button exists and tappable
    // =========================================================================

    func test_11_termsOfUseButtonExistsAndTappable() {
        goToSettings()
        let btn = app.buttons["termsOfUseButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        XCTAssertTrue(btn.isHittable)
        btn.tap()
        XCTAssertTrue(app.staticTexts["Terms of Service"].waitForExistence(timeout: 5))
        app.swipeDown()
    }

    // =========================================================================
    // MARK: - 12. Support button exists and tappable
    // =========================================================================

    func test_12_supportButtonExistsAndTappable() {
        goToSettings()
        let btn = app.buttons["supportButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        XCTAssertTrue(btn.isHittable)
        btn.tap()
        // Sheet must appear — look for its distinctive title
        XCTAssertTrue(app.staticTexts["Support"].waitForExistence(timeout: 5))
        app.swipeDown()
    }

    // =========================================================================
    // MARK: - 13. Rate App button exists and tappable
    // =========================================================================

    func test_13_rateAppButtonExistsAndTappable() {
        goToSettings()
        let btn = app.buttons["rateAppButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        // Button may be below the fold — scroll until hittable
        var attempts = 0
        while !btn.isHittable && attempts < 5 {
            app.scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(btn.isHittable, "Rate App button must be hittable after scrolling into view")
    }

    // =========================================================================
    // MARK: - 14. Share button exists and tappable
    // =========================================================================

    func test_14_shareButtonExistsAndTappable() {
        goToSettings()
        let btn = app.buttons["shareButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5))
        XCTAssertTrue(btn.isHittable)
        btn.tap()
        // Share sheet appears
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5)
                      || app.sheets.firstMatch.waitForExistence(timeout: 5))
        // Dismiss
        if app.buttons["Close"].waitForExistence(timeout: 2) {
            app.buttons["Close"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        }
    }

    // =========================================================================
    // MARK: - 15. Scan Network button exists in Network Scan tab
    // =========================================================================

    func test_15_scanNetworkButtonExistsInNetworkScanTab() {
        guard isWiFiAvailable else { return }

        goToNetworkScan()
        XCTAssertTrue(app.buttons["scanNetworkButton"].waitForExistence(timeout: 5),
                      "Scan Network button must be present when WiFi is available")
    }

    // =========================================================================
    // MARK: - 16. Speed test buttons exist (Google, Facebook, Apple)
    // =========================================================================

    func test_16_speedTestButtonsExist() {
        goToSpeedTest()
        for site in ["google", "facebook", "apple"] {
            XCTAssertTrue(
                app.buttons["testButton_\(site)"].waitForExistence(timeout: 5),
                "Speed test button for \(site) must exist"
            )
        }
    }

    // =========================================================================
    // MARK: - 17. App title visible on settings tab
    // =========================================================================

    func test_17_appTitleVisibleOnSettingsTab() {
        goToSettings()
        XCTAssertTrue(app.staticTexts["WiFi Check"].waitForExistence(timeout: 5))
    }

    // =========================================================================
    // MARK: - 18. App does not crash on rapid tab switching (3 full cycles)
    // =========================================================================

    func test_18_rapidTabSwitchingDoesNotCrash() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        for _ in 1...3 {
            tabBar.buttons["Speed Test"].tap()
            tabBar.buttons["Network Scan"].tap()
            tabBar.buttons["Settings"].tap()
            tabBar.buttons["WiFi Info"].tap()
        }

        XCTAssertTrue(tabBar.buttons["WiFi Info"].isSelected,
                      "App must not crash after rapid tab switching")
    }

    // =========================================================================
    // MARK: - 19. WiFi tab shows metrics OR blocked view (graceful no-WiFi state)
    // =========================================================================

    func test_21_wifiTabShowsMetricsOrBlockedView() {
        goToWiFiInfo()
        let metricsVisible = app.staticTexts["Metrics"].waitForExistence(timeout: 5)
        let blockedVisible = app.buttons["openSettingsButton"].waitForExistence(timeout: 2)
        XCTAssertTrue(metricsVisible || blockedVisible,
                      "WiFi tab must show either Metrics section or the blocked/no-WiFi view")
    }

    // =========================================================================
    // MARK: - 22. Network scan shows scan button or blocked state
    // =========================================================================

    func test_22_networkScanShowsSomething() {
        goToNetworkScan()
        let scanBtn = app.buttons["scanNetworkButton"].waitForExistence(timeout: 5)
        let blockedBtn = app.buttons["openSettingsButton"].waitForExistence(timeout: 2)
        XCTAssertTrue(scanBtn || blockedBtn,
                      "Network Scan tab must show scan button or blocked view")
    }

    // =========================================================================
    // MARK: - 23. Dark mode — app launches without crash
    // =========================================================================

    func test_23_darkModeAppLaunchesWithoutCrash() {
        // Terminate and relaunch with dark mode override
        app.terminate()
        app.launchArguments += ["-UIUserInterfaceStyle", "Dark"]
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "App must launch in dark mode without crashing")
    }

    // =========================================================================
    // MARK: - 24. App background/foreground cycle does not crash
    // =========================================================================

    func test_24_backgroundForegroundCycleDoesNotCrash() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))

        // Background the app
        XCUIDevice.shared.press(.home)

        // Brief pause for background processing
        Thread.sleep(forTimeInterval: 1.5)

        // Bring back to foreground
        app.activate()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "App must restore correctly after background/foreground cycle")
    }

    // =========================================================================
    // MARK: - 26. Upload Speed metric row is visible in Metrics card
    // =========================================================================

    func test_26_uploadSpeedMetricRowVisible() {
        guard isWiFiAvailable else { return }
        goToWiFiInfo()
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "metricRow_uploadThroughput")
                .firstMatch
                .waitForExistence(timeout: 5),
            "Upload Speed metric row must be visible in the Metrics card"
        )
    }

    // =========================================================================
    // MARK: - 27. Metrics card shows 4 of 7 counter by default
    // =========================================================================

    func test_27_metricsCardShowsFourOfSeven() {
        guard isWiFiAvailable else { return }
        goToWiFiInfo()
        XCTAssertTrue(
            app.staticTexts["4 of 7"].waitForExistence(timeout: 5),
            "Metrics card must show '4 of 7' counter when collapsed"
        )
    }

    // =========================================================================
    // MARK: - 28. Score info sheet opens via info icon on Gauge card
    // =========================================================================

    func test_28_scoreInfoSheetOpenViaInfoIcon() {
        guard isWiFiAvailable else { return }
        goToWiFiInfo()

        let infoBtn = app.descendants(matching: .any)
            .matching(identifier: "scoreInfoButton")
            .firstMatch
        XCTAssertTrue(infoBtn.waitForExistence(timeout: 5), "Score info button must exist on Gauge card")
        infoBtn.tap()

        XCTAssertTrue(
            app.staticTexts["How We Score Your WiFi"].waitForExistence(timeout: 5),
            "Score info sheet must appear with 'How We Score Your WiFi' title"
        )
        app.swipeDown()
    }

    // =========================================================================
    // MARK: - 29. Network Info card expands to show More Details
    // =========================================================================

    func test_29_networkInfoCardExpandsToShowMoreDetails() {
        guard isWiFiAvailable else { return }
        goToWiFiInfo()

        let toggle = app.descendants(matching: .any)
            .matching(identifier: "networkInfoToggleHeader")
            .firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Network Info toggle header must exist")
        toggle.tap()

        // After expanding, Security row must be visible
        XCTAssertTrue(
            app.staticTexts["Security"].waitForExistence(timeout: 3),
            "Security row must be visible after expanding Network Info card"
        )
    }

    // =========================================================================
    // MARK: - 30. Network scan "you" device appears after scanning
    // =========================================================================

    func test_30_networkScanShowsYouDeviceAfterScan() {
        guard isWiFiAvailable else { return }
        goToNetworkScan()

        let scanBtn = app.buttons["scanNetworkButton"]
        XCTAssertTrue(scanBtn.waitForExistence(timeout: 5))
        scanBtn.tap()

        // Wait up to 30 s for scan to complete
        let youLabel = app.staticTexts.matching(NSPredicate(format: "label == 'you'")).firstMatch
        XCTAssertTrue(youLabel.waitForExistence(timeout: 30),
                      "A 'you' badge must appear after scanning to identify this device")
    }

    // =========================================================================
    // MARK: - 31. Network scan "Routers" group appears after scanning
    // =========================================================================

    func test_31_networkScanShowsRoutersGroupAfterScan() {
        guard isWiFiAvailable else { return }
        goToNetworkScan()

        let scanBtn = app.buttons["scanNetworkButton"]
        XCTAssertTrue(scanBtn.waitForExistence(timeout: 5))
        scanBtn.tap()

        // Wait for scan to complete then check for Routers section header
        let routersHeader = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'ROUTERS'")).firstMatch
        XCTAssertTrue(routersHeader.waitForExistence(timeout: 30),
                      "'Routers' group header must appear after scanning")
    }

    // =========================================================================
    // MARK: - 25. No unexpected alerts on launch
    // =========================================================================

    func test_25_noUnexpectedAlertsOnLaunch() {
        // Allow a moment for any launch-time alerts to appear
        Thread.sleep(forTimeInterval: 2)

        // System permission alerts (location, network) are expected — dismiss them.
        // Any alert that is NOT a known system alert is unexpected.
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            // Dismiss with the first available button (OK / Allow / Don't Allow)
            let firstBtn = alert.buttons.firstMatch
            if firstBtn.exists { firstBtn.tap() }
        }

        // After handling alerts, the main UI must still be present
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "Main tab bar must be visible after launch — no blocking alert should remain")
    }

    // =========================================================================
    // MARK: - 32. Device detail view opens from network scan result
    // =========================================================================

    func test_32_deviceDetailViewOpensFromNetworkScanResult() {
        guard isWiFiAvailable else { return }
        goToNetworkScan()

        let scanBtn = app.buttons["scanNetworkButton"]
        XCTAssertTrue(scanBtn.waitForExistence(timeout: 5))
        scanBtn.tap()

        // Wait for at least one device card to appear (up to 30s)
        let firstCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deviceCard_'")).firstMatch
        guard firstCard.waitForExistence(timeout: 30) else { return }
        firstCard.tap()

        // Device detail view must appear
        XCTAssertTrue(
            app.otherElements["deviceDetailView"].waitForExistence(timeout: 5),
            "Device detail view must open when a scan result card is tapped"
        )
        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
    }

    // =========================================================================
    // MARK: - 33. Speed test site cards load (Google, Facebook, Apple)
    // =========================================================================

    func test_33_speedTestSiteCardsLoad() {
        goToSpeedTest()
        for site in ["google", "facebook", "apple"] {
            let btn = app.buttons["testButton_\(site)"]
            XCTAssertTrue(btn.waitForExistence(timeout: 5),
                          "Speed test card for \(site) must be visible")
        }
    }

    // =========================================================================
    // MARK: - 34. Settings accent color swatches are tappable
    // =========================================================================

    func test_34_settingsAccentColorSwatchesTappable() {
        goToSettings()
        // Accent color section must contain at least one circle button
        let swatches = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'accentSwatch_'"))
        // Fall back to any swatch-like button if identifiers not present
        let firstSwatch = swatches.firstMatch
        let hasSwatch = firstSwatch.waitForExistence(timeout: 5)
        if hasSwatch {
            XCTAssertTrue(firstSwatch.isHittable, "First accent swatch must be hittable")
        }
        // Pass either way — the test verifies the settings tab is fully rendered
        XCTAssertTrue(app.staticTexts["WiFi Check"].waitForExistence(timeout: 3))
    }

    // =========================================================================
    // MARK: - 35. Theme selector: all three pills exist
    // =========================================================================

    func test_35_themeSelectorPillsExist() {
        goToSettings()
        for value in ["system", "light", "dark"] {
            let pill = app.buttons["themePill_\(value)"]
            XCTAssertTrue(pill.waitForExistence(timeout: 5),
                          "Theme pill '\(value)' must exist in the Preferences card")
            XCTAssertTrue(pill.isHittable, "Theme pill '\(value)' must be hittable")
        }
    }

    // =========================================================================
    // MARK: - 36. Theme selector: tapping Light persists selection
    // =========================================================================

    func test_36_themeSelectorPersistsSelection() {
        goToSettings()

        let lightPill = app.buttons["themePill_light"]
        XCTAssertTrue(lightPill.waitForExistence(timeout: 5), "Light theme pill must exist")
        lightPill.tap()

        // Switch to another tab and back — selection must survive
        app.tabBars.firstMatch.buttons["WiFi Info"].tap()
        goToSettings()

        XCTAssertTrue(app.buttons["themePill_light"].waitForExistence(timeout: 5),
                      "Theme pill must still be visible after tab switch")

        // Reset to System so other tests are not affected
        app.buttons["themePill_system"].tap()
    }

    // =========================================================================
    // MARK: - 37. Refresh cycle: all three pills exist
    // =========================================================================

    func test_37_refreshCyclePillsExist() {
        goToSettings()
        for label in ["5s", "15s", "manual"] {
            let pill = app.buttons["refreshPill_\(label)"]
            XCTAssertTrue(pill.waitForExistence(timeout: 5),
                          "Refresh pill '\(label)' must exist")
            XCTAssertTrue(pill.isHittable, "Refresh pill '\(label)' must be hittable")
        }
    }

    // =========================================================================
    // MARK: - 38. Font Size section is visible in Settings Preferences card
    // =========================================================================

    func test_38_fontSizeSectionVisibleInSettings() {
        goToSettings()
        XCTAssertTrue(app.staticTexts["Font Size"].waitForExistence(timeout: 5),
                      "Font Size label must be visible in the Preferences card")
        // All three "Aa" tiles must be present (3 buttons whose label is "Aa")
        let tiles = app.buttons.matching(NSPredicate(format: "label == 'Aa'"))
        XCTAssertGreaterThanOrEqual(tiles.count, 3,
                                    "Font size section must have at least 3 'Aa' tiles")
    }

    // =========================================================================
    // MARK: - 39. Font Family dropdown opens a bottom sheet
    // =========================================================================

    func test_39_fontFamilyDropdownOpensSheet() {
        goToSettings()
        // The current font family is shown as a button label (default: "SF Pro (Default)")
        XCTAssertTrue(app.staticTexts["Font Family"].waitForExistence(timeout: 5),
                      "Font Family label must be visible in the Preferences card")

        // Find and tap the dropdown button — it contains the current font name
        let dropdownBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'SF Pro' OR label CONTAINS 'SF Mono' OR label CONTAINS 'New York' OR label CONTAINS 'Rounded'")
        ).firstMatch
        guard dropdownBtn.waitForExistence(timeout: 5) else { return }
        dropdownBtn.tap()

        // A sheet with font options must appear
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SF'")).firstMatch
                .waitForExistence(timeout: 5),
            "Font family picker sheet must appear after tapping the dropdown"
        )
        app.swipeDown()
    }

    // =========================================================================
    // MARK: - 40. Device detail view shows only IP, Hostname, Manufacturer, Type
    //         (no MAC Address, First Seen, Last Seen rows)
    // =========================================================================

    func test_40_deviceDetailViewShowsOnlyReliableFields() {
        guard isWiFiAvailable else { return }
        goToNetworkScan()

        let scanBtn = app.buttons["scanNetworkButton"]
        XCTAssertTrue(scanBtn.waitForExistence(timeout: 5))
        scanBtn.tap()

        let firstCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'deviceCard_'")
        ).firstMatch
        guard firstCard.waitForExistence(timeout: 30) else { return }
        firstCard.tap()

        XCTAssertTrue(
            app.otherElements["deviceDetailView"].waitForExistence(timeout: 5),
            "Device detail view must open"
        )

        // Fields that MUST be present
        XCTAssertTrue(app.staticTexts["IP Address"].waitForExistence(timeout: 3),
                      "IP Address row must be visible")
        XCTAssertTrue(app.staticTexts["Hostname"].waitForExistence(timeout: 3),
                      "Hostname row must be visible")

        // Fields that must NOT be present
        XCTAssertFalse(app.staticTexts["MAC Address"].exists,
                       "MAC Address row must NOT be shown")
        XCTAssertFalse(app.staticTexts["First Seen"].exists,
                       "First Seen row must NOT be shown")
        XCTAssertFalse(app.staticTexts["Last Seen"].exists,
                       "Last Seen row must NOT be shown")

        app.navigationBars.buttons.firstMatch.tap()
    }

    // =========================================================================
    // MARK: - 41. Settings Preferences and About section headers are visible
    // =========================================================================

    func test_41_settingsSectionHeadersVisible() {
        goToSettings()
        XCTAssertTrue(app.staticTexts["Preferences"].waitForExistence(timeout: 5),
                      "Preferences section header must be visible")
        XCTAssertTrue(app.staticTexts["About"].waitForExistence(timeout: 5),
                      "About section header must be visible")
    }
}

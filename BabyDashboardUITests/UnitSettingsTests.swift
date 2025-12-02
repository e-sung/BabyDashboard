import XCTest

final class UnitSettingsTests: XCTestCase {

    var app: XCUIApplication!
    private let baseTime: TimeInterval = 1704099600 // 2024-01-01 00:00:00 UTC

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["TZ"] = "UTC"
        app.launchEnvironment["LANG"] = "en_US_POSIX"
        app.launchEnvironment["LC_ALL"] = "en_US_POSIX"
    }
    
    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
    }

    func testUnitSwitchingAndHistory() throws {
        // 1. Launch app with clean state
        launchApp(seed: "babyAddedWithoutLog")
        
        // 2. Open Settings, select "ml"
        openSettings()
        selectUnit("mL")
        closeSettings()
        
        // 3. Record a feed (120 ml)
        recordFeed(amount: "120")
        
        // 4. Open Settings, select "fl oz"
        openSettings()
        selectUnit("fl oz")
        closeSettings()
        
        // 5. Record a feed (4 oz)
        recordFeed(amount: "4")
        
        // 6. Open History
        app.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
        
        // 7. Verify first feed (120 ml) -> approx 4.1 fl oz
        // The most recent is 4 oz, the previous is 120 ml.
        // History is sorted by date descending.
        // Feed 2 (4 oz) should be first.
        // Feed 1 (120 ml) should be second.
        
        let cells = app.cells
        XCTAssertTrue(cells.count >= 2)

        XCTAssertTrue(app.cells.staticTexts["4 fl oz over 0 min"].exists)

        // 120 ml = 4.05768 fl oz -> 4.1 fl oz
        XCTAssertTrue(app.cells.staticTexts["4.1 fl oz over 0 min"].exists)

        // Daily summary = 4.0 + 4.1 = 8.1
        XCTAssert(app.cells.staticTexts["8.1 fl oz"].exists)
    }
    
    // MARK: - Helpers
    
    private func launchApp(seed: String? = nil) {
        var arguments = [
            "-UITest",
            "-FastAnimations",
            "-FixedTime:\(baseTime)",
            "-BaseTime:\(baseTime)",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US_POSIX"
        ]

        if let seed {
            arguments.append("-Seed:\(seed)")
        }

        app.launchArguments = arguments
        app.launch()
    }
    
    private func openSettings() {
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
    }
    
    private func closeSettings() {
        app.buttons["Done"].tap()
    }
    
    private func selectUnit(_ unit: String) {
        XCTAssert(app.buttons[unit].waitForExistence(timeout: 2))
        app.buttons[unit].tap()
    }
    
    private func recordFeed(amount: String) {
        let feedCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Feed")).firstMatch
        feedCard.tap() // Start
        sleep(1)
        feedCard.tap() // Finish
        
        let amountField = app.textFields["Amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        // Clear existing text in the amount field by sending delete keys for each character
        if let currentValue = amountField.value as? String, !currentValue.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            amountField.typeText(deleteString)
        }
        amountField.typeText(amount)
        app.buttons["Done"].tap()
    }
}


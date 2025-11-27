//
//  BabyDashboardDocumentationTests.swift
//  BabyDashboardUITests
//
//  Created by Antigravity on 11/26/25.
//

import XCTest

final class BabyDashboardDocumentationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
    }

    func testOnboardingAndAddBaby() throws {
        app.launchArguments = ["-UITest", "-Seed:initialState"]
        app.launch()
        
        // 1. Verify "Add Baby" placeholder exists
        // There might be multiple placeholders, we just need one to exist.
        let addBabyButton = app.buttons.matching(identifier: "Add Baby").firstMatch
        XCTAssertTrue(addBabyButton.exists, "Add Baby placeholder should be visible")
        
        // 2. Tap "Add Baby"
        addBabyButton.tap()
        
        // 3. Enter name
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Name field should appear")
        nameField.tap()
        nameField.typeText("Baby A")
        
        // 4. Save
        app.buttons["Save"].tap()
        
        // 5. Verify tile appears
        let babyTile = app.staticTexts["Baby A"]
        XCTAssertTrue(babyTile.waitForExistence(timeout: 2), "Baby A tile should appear on dashboard")
    }
    
    func testFeedingFlow() throws {
        app.launchArguments = ["-UITest", "-Seed:babyAddedWithoutLog"]
        app.launch()
        
        // 1. Start Feeding
        let feedButton = app.buttons["Log a feed"]
        XCTAssertTrue(feedButton.exists, "Feed button should exist")
        feedButton.tap()
        
        // Verify "Feeding..." text appears
        let feedingText = app.staticTexts["Feeding..."]
        XCTAssertTrue(feedingText.waitForExistence(timeout: 2), "Should show Feeding status")
        
        // 2. Stop Feeding
        feedButton.tap()
        
        // 3. Enter Amount
        let amountField = app.textFields["Amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2), "Amount field should appear")
        amountField.tap()
        amountField.typeText("120")
        
        app.buttons["Done"].tap()
        
        // 4. Verify Feeding status is gone (or updated)
        XCTAssertFalse(feedingText.exists, "Feeding status should be gone")
    }
    
    func testDiaperLogging() throws {
        app.launchArguments = ["-UITest", "-Seed:babyAddedWithoutLog"]
        app.launch()
        
        // 1. Tap Diaper
        let diaperButton = app.buttons["Log a diaper change"]
        XCTAssertTrue(diaperButton.exists)
        diaperButton.tap()
        
        // 2. Select Type
        let peeButton = app.buttons["Pee"]
        XCTAssertTrue(peeButton.waitForExistence(timeout: 2))
        peeButton.tap()
        
        // 3. Verify update
        XCTAssertFalse(peeButton.exists)
    }
    
    func testNavigation() throws {
        app.launchArguments = ["-UITest", "-Seed:babiesWithSomeLogs"]
        app.launch()
        
        // History
        let historyButton = app.buttons["History"]
        XCTAssertTrue(historyButton.exists)
        historyButton.tap()
        
        // Dismiss
        app.windows.firstMatch.swipeDown(velocity: .fast)
        
        // Analysis
        let analysisButton = app.buttons["Analysis"]
        XCTAssertTrue(analysisButton.waitForExistence(timeout: 2))
        analysisButton.tap()
        
        // Dismiss
        app.windows.firstMatch.swipeDown(velocity: .fast)
    }
    
    func testEditFeedSessionAndVerifyWarning() throws {
        let app = XCUIApplication()
        // Fixed time: 2025-11-26 09:00:00 KST (approx) -> 1764158400
        let fixedTimestamp = 1764158400.0
        app.launchArguments = [
            "-UITest",
            "-Seed:babiesWithSomeLogs",
            "-FixedTime:\(fixedTimestamp)",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-FastAnimations"
        ]
        app.launchEnvironment["TZ"] = "Asia/Seoul"
        app.launch()
        
        // 0. Verify NO Warning Badge initially
        XCTAssertFalse(app.buttons.staticTexts["Warning"].waitForExistence(timeout: 2), "Warning badge should NOT appear initially")

        // 1. Tap Last Feed Details to edit
        let lastFeedDetails = app.buttons["120 mL in 10m"].firstMatch
        XCTAssert(lastFeedDetails.waitForExistence(timeout: 3), "Last feed details should be visible")
        lastFeedDetails.tap()
        
        // 2. Edit Time
        let datePickers = app.datePickers
        let startPicker = datePickers["Start Time"]
        if startPicker.waitForExistence(timeout: 3) {
             // If it's a compact picker, tapping it opens the wheel
            startPicker.tap()
        }
        
        // Swipe down on the wheel to move time back
        let hourWheel = app.pickerWheels.firstMatch
        if hourWheel.waitForExistence(timeout: 2) {
            hourWheel.swipeDown(velocity: .slow)
        }
        
        // Dismiss popover if present (User recorded "PopoverDismissRegion")
        let dismissRegion = app.buttons["PopoverDismissRegion"]
        dismissRegion.tap()

        // 3. Save
        app.buttons["Done"].tap()
        
        // 4. Verify Warning Badge APPEARS
        XCTAssert(app/*@START_MENU_TOKEN@*/.buttons.staticTexts["Warning"]/*[[".buttons.staticTexts[\"Warning\"]",".staticTexts[\"Warning\"]"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/.waitForExistence(timeout: 2), "Warning badge should appear after editing time")
    }
}


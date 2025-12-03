//
//  BabyDashboardDocumentationTests.swift
//  BabyDashboardUITests
//
//  Created by Antigravity on 11/26/25.
//

import XCTest

final class BabyDashboardDocumentationTests: XCTestCase {

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

    func testOnboardingAndAddBaby() throws {
        launchApp()
        
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
        let babyTile = babyNameElement("Baby A")
        XCTAssertTrue(babyTile.waitForExistence(timeout: 10), "Baby A tile should appear on dashboard")
    }

    func testNavigation() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
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

    func testStartAndFinishFeed() throws {
        launchApp(seed: "babyAddedWithoutLog", feedTermSeconds: 30)

        let feedCard = feedStatusCard()
        XCTContext.runActivity(named: "Initial State") { _ in
            XCTAssert(
                findStaticText(containing: "No data", from: feedCard).exists,
                "Amount element should not be present before finishing feed"
            )
            XCTAssert(progressValue(of: feedCard) == 0, "Progress should be zero in initial state")
            sleep(1)
            XCTAssert(progressValue(of: feedCard) == 0, "Progress should be zero when there's no log yet")
        }

        XCTContext.runActivity(named: "Start Feeding") { _ in
            feedCard.tap() // start feeding
            waitForLabel(feedCard, toMatchAnyOf: ["Feeding"])
            XCTAssertTrue(findStaticText(containing: "Feeding", from: feedCard).exists, "Footer should show Feeding while in progress")
            sleep(2) // allow elapsed time to advance
            let label = feedCard.label
            XCTAssertFalse(label.contains("Feeding..."), "Main text should show elapsed time instead of placeholder")
            XCTAssertTrue(label.contains("s") || label.contains("m"), "Main text should show elapsed time including seconds under a minute")
        }

        XCTContext.runActivity(named: "Finish Feeding") { _ in
            feedCard.tap() // finish feeding
            XCTAssertTrue(app.staticTexts["How much did Baby A eat?"].waitForExistence(timeout: 2))
            let amountField = app.textFields["Amount"]
            XCTAssertTrue(amountField.waitForExistence(timeout: 2))
            amountField.tap()
            amountField.typeText("90")
            app.buttons["Done"].tap()
            XCTAssert(app.staticTexts["How much did Baby A eat?"].waitForNonExistence(timeout: 2))
            XCTAssert(findStaticText(containing: "Just now", from: feedCard).exists)
            XCTAssertFalse(findStaticText(containing: "Feeding", from: feedCard).exists)
            XCTAssertTrue(findStaticText(containing: "90").waitForExistence(timeout: 2), "Feed footer should include entered amount")
        }

        XCTContext.runActivity(named: "Edit History") { _ in
            // Edit start time to 1 hour ago via footer -> HistoryEditView
            let footerElement = findStaticText(containing: "Last Feed", from: feedCard)
            XCTAssertTrue(footerElement.exists, "Feed footer should be tappable")
            footerElement.tap()
            XCTAssert(app.staticTexts["Edit Event"].waitForExistence(timeout: 1))

            let picker = app.datePickers["Start Time"]
            XCTAssertTrue(picker.waitForExistence(timeout: 2), "Date picker Start Time should appear")
            picker.tap()
            XCTAssert(app.pickerWheels.firstMatch.waitForExistence(timeout: 2))
            app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "8")
            app.buttons["PopoverDismissRegion"].tap()
            app.navigationBars.buttons["Done"].tap()

            XCTAssert(app.staticTexts["Edit Event"].waitForNonExistence(timeout: 3))
            waitForLabel(feedCard, toMatchAnyOf: ["ago", "hour", "min"])
        }

        XCTContext.runActivity(named: "ReStart Feeding") { _ in
            feedCard.tap() // start feeding
            waitForLabel(feedCard, toMatchAnyOf: ["Feeding"])
            XCTAssertTrue(findStaticText(containing: "Feeding", from: feedCard).exists, "Footer should show Feeding while in progress")
            sleep(2) // allow elapsed time to advance
        }

        XCTContext.runActivity(named: "ReFinish Feeding") { _ in
            feedCard.tap() // finish feeding
            XCTAssertTrue(app.staticTexts["How much did Baby A eat?"].waitForExistence(timeout: 2))
            let amountField = app.textFields["Amount"]
            XCTAssert(amountField.value as? String == "90.0", "Previous amount should be pre-filled in the amount field")
            app/*@START_MENU_TOKEN@*/.buttons["Increment"]/*[[".steppers",".buttons[\"Adjust by 10, 증가\"]",".buttons[\"Increment\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
            XCTAssert(amountField.value as? String == "100.0", "Amount should be incremented")
            app.buttons["Done"].tap()
            XCTAssert(app.staticTexts["How much did Baby A eat?"].waitForNonExistence(timeout: 2))
            XCTAssert(findStaticText(containing: "Just now", from: feedCard).exists)
            XCTAssertFalse(findStaticText(containing: "Feeding", from: feedCard).exists)
            XCTAssertTrue(findStaticText(containing: "100").waitForExistence(timeout: 2), "Feed footer should include entered amount")
        }
    }

    func testLogDiaperChange() throws {
        launchApp(seed: "babiesWithSomeLogs")

        let diaperCard = diaperStatusCard()
        XCTAssertTrue(diaperCard.waitForExistence(timeout: 2), "Diaper card should be visible for Baby A")
        let initialProgress = progressValue(of: diaperCard)
        let initialFooter = timeFooter(in: diaperCard)

        diaperCard.tap()
        let peeButton = app.buttons["Pee"]
        XCTAssertTrue(peeButton.waitForExistence(timeout: 2))
        peeButton.tap()

        waitForLabel(diaperCard, toMatchAnyOf: ["Just now", "ago"])
        let finishedProgress = progressValue(of: diaperCard)
        let updatedFooter = timeFooter(in: diaperCard)

        if let initial = initialProgress, let finished = finishedProgress {
            XCTAssertLessThan(finished, initial, "Diaper progress should reset after logging")
        }
        XCTAssertNotNil(finishedProgress, "Diaper progress value should be present after logging")
        if let initialFooter, let updatedFooter {
            XCTAssertNotEqual(initialFooter, updatedFooter, "Diaper footer timestamp should update after logging")
        }
    }

    // MARK: - Helpers

    private func launchApp(seed: String? = nil, feedTermSeconds: TimeInterval? = nil) {
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
        if let feedTermSeconds {
            arguments.append("-FeedTerm:\(feedTermSeconds)")
        }

        app.launchArguments = arguments
        app.launch()
    }

    private func feedStatusCard() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Feed")).firstMatch
    }

    private func diaperStatusCard() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Diaper")).firstMatch
    }

    private func babyNameElement(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    private func findStaticText(containing substring: String, from uiElement: XCUIElement? = nil) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        if let uiElement {
            return uiElement.staticTexts.matching(predicate).firstMatch
        }
        return app.staticTexts.matching(predicate).firstMatch
    }

    private func progressValue(of card: XCUIElement) -> Double? {
        guard let valueString = card.value as? String else { return nil }
        let cleaned = valueString.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private func timeFooter(in card: XCUIElement) -> String? {
        let label = card.descendants(matching: .staticText).matching(NSPredicate(format: "label CONTAINS %@", ":")).firstMatch
        return label.exists ? label.label : nil
    }

    private func waitForLabel(_ element: XCUIElement, toMatchAnyOf substrings: [String], timeout: TimeInterval = 5) {
        let predicate = NSPredicate { object, _ in
            guard let el = object as? XCUIElement else { return false }
            return substrings.contains { el.label.contains($0) }
        }
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

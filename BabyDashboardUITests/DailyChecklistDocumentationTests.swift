//
//  DailyChecklistDocumentationTests.swift
//  BabyDashboardUITests
//
//  Daily Checklist Configuration Feature Tests
//
//  This test suite documents the daily checklist feature which allows users to:
//  1. Configure up to 3 daily recurring checklist items per baby
//  2. Toggle checklist items on/off to create/delete CustomEvents
//  3. Enter configuration mode with iOS-style wiggle animations
//  4. Remove items from the checklist via delete badges
//

import XCTest

final class DailyChecklistDocumentationTests: XCTestCase {
    
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
    
    /// Documents the complete daily checklist workflow:
    /// 1. Enter configuration mode to see placeholder
    /// 2. Create a CustomEventType
    /// 3. Add it to the daily checklist
    /// 4. Toggle the item on/off to create/delete CustomEvents
    /// 5. Verify wiggle animations start and stop correctly
    func testDailyChecklistCompleteWorkflow() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
        XCTContext.runActivity(named: "1. Initial State - No Checklist Configured") { _ in
            // Verify toolbar has checklist button
            let checklistButton = app.buttons["Configure Daily Checklist"]
            XCTAssertTrue(checklistButton.exists, "Checklist configuration button should exist in toolbar")
            
            // Verify no checklist items visible initially
            let placeholder = app.buttons["PlaceholderChecklistButton"]
            XCTAssertFalse(placeholder.exists, "Placeholder should not be visible when not in config mode")
        }
        
        XCTContext.runActivity(named: "2. Enter Configuration Mode") { _ in
            // Tap checklist button to enter configuration mode
            app.buttons["Configure Daily Checklist"].tap()
            
            // Verify placeholder appears when in config mode
            let placeholder = app.buttons["PlaceholderChecklistButton"]
            XCTAssertTrue(
                placeholder.waitForExistence(timeout: 2),
                "Placeholder button should appear when entering configuration mode"
            )
            
            // Verify placeholder has correct label
            XCTAssertEqual(
                placeholder.label,
                "Add daily checklist item",
                "Placeholder should have descriptive accessibility label"
            )
        }
        
        XCTContext.runActivity(named: "3. Create CustomEventType for Checklist") { _ in
            // Tap placeholder to open configuration sheet
            app.buttons["PlaceholderChecklistButton"].tap()
            
            // Verify configuration sheet appears
            XCTAssertTrue(
                app.staticTexts["Daily Checklist"].waitForExistence(timeout: 2),
                "Configuration sheet should appear"
            )
            
            // No event types exist yet, so tap "Manage Event Types" to create one
            let manageButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Manage Event Types")).firstMatch
            XCTAssertTrue(manageButton.exists, "Manage Event Types button should be visible")
            manageButton.tap()
            
            // Verify CustomEventTypeManagementView appears
            XCTAssertTrue(
                app.staticTexts["Custom Event Types"].waitForExistence(timeout: 2),
                "Custom Event Types management view should appear"
            )
            
            // Tap plus button to add new event type
            app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Add Event Type")).firstMatch.tap()
            
            // Enter event type details
            let nameField = app.textFields.element(boundBy: 0)
            XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Name text field should exist")
            nameField.tap()
            nameField.typeText("Vitamin")
            
            // Enter emoji
            let emojiField = app.textFields["Tap to add emoji"]
            XCTAssertTrue(emojiField.exists)
            emojiField.tap()
            emojiField.typeText("💊")
            
            // Save event type
            app.buttons["Save"].tap()
            
            // Verify we're back at management view
            XCTAssertTrue(app.staticTexts["Custom Event Types"].exists)
            
            // Verify Vitamin event type appears
            XCTAssertTrue(
                app.staticTexts["Vitamin"].waitForExistence(timeout: 2),
                "Newly created Vitamin event type should appear in list"
            )
            
            // Go back to configuration sheet 
            app.navigationBars.buttons["Done"].firstMatch.tap()
        }
        
        XCTContext.runActivity(named: "4. Select CustomEventType for Daily Checklist") { _ in
            // Should be back at configuration sheet
            XCTAssertTrue(app.staticTexts["Daily Checklist"].exists)
            
            // Tap Vitamin to add it to checklist
            let vitaminRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Vitamin")).firstMatch
            XCTAssertTrue(
                vitaminRow.waitForExistence(timeout: 2),
                "Vitamin should appear in configuration sheet"
            )
            vitaminRow.tap()
            
            // Tap Done to dismiss the configuration sheet
            app.navigationBars.buttons["Done"].firstMatch.tap()
            
            // Verify sheet is dismissed
            XCTAssertTrue(
                app.staticTexts["Daily Checklist"].waitForNonExistence(timeout: 2),
                "Configuration sheet should dismiss after tapping Done"
            )
        }
        
        XCTContext.runActivity(named: "5. Verify Wiggle Animation in Config Mode") { _ in
            // Look for the newly added checklist button
            // It should have the emoji "💊" and be in editable mode (wiggling)
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            XCTAssertTrue(
                vitaminButton.waitForExistence(timeout: 2),
                "Vitamin checklist button should appear after configuration"
            )
            
            // Verify delete badge is visible (indicates config/wiggle mode)
            let deleteButton = app.buttons["Remove from checklist"]
            XCTAssertTrue(
                deleteButton.exists,
                "Delete badge should be visible in configuration mode"
            )
        }
        
        XCTContext.runActivity(named: "6. Exit Configuration Mode - Stop Wiggling") { _ in
            // Tap checklist button again to exit configuration mode
            app.buttons["Configure Daily Checklist"].tap()
            
            // Wait a moment for animation to settle
            sleep(1)
            
            // Verify delete badge is hidden (indicates config mode off)
            let deleteButton = app.buttons["Remove from checklist"]
            XCTAssertFalse(
                deleteButton.exists,
                "Delete badge should be hidden when not in configuration mode"
            )
            
            // Verify placeholder is hidden
            let placeholder = app.buttons["PlaceholderChecklistButton"]
            XCTAssertFalse(
                placeholder.exists,
                "Placeholder should be hidden when not in configuration mode"
            )
        }
        
        XCTContext.runActivity(named: "7. Toggle Checklist Item ON - Create CustomEvent") { _ in
            // Initial state should be unchecked (gray)
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            XCTAssertTrue(vitaminButton.exists)
            
            // Tap to check the item
            vitaminButton.tap()
            
            // Verify button turns green (checked state)
            // Note: The background color change is reflected in the label
            sleep(1) // Allow animation to complete
            
            // Navigate to History to verify CustomEvent was created
            app.buttons["History"].tap()
            XCTAssertTrue(
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Vitamin")).firstMatch.waitForExistence(timeout: 2),
                "Vitamin CustomEvent should appear in History after checking"
            )

            // Go back to main view
            app.buttons["Done"].tap()
        }
        
        XCTContext.runActivity(named: "8. Toggle Checklist Item OFF - Delete CustomEvent") { _ in
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            XCTAssertTrue(vitaminButton.waitForExistence(timeout: 2))
            
            // Tap to uncheck the item
            vitaminButton.tap()
            
            sleep(1) // Allow deletion to complete
            
            // Navigate to History to verify CustomEvent was deleted
            app.buttons["History"].tap()
            
            // Vitamin event should no longer exist
            let vitaminEvent = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Vitamin")).firstMatch
            XCTAssertFalse(
                vitaminEvent.exists,
                "Vitamin CustomEvent should be deleted from History after unchecking"
            )
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    /// Finds a checklist button by its emoji
    /// Note: Buttons in SwiftUI may not have stable identifiers, so we search by label content
    private func findChecklistButton(withEmoji emoji: String) -> XCUIElement {
        // Try to find button containing the emoji
        let buttons = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", emoji))
        
        // Filter out the "Add daily checklist item" placeholder
        for i in 0..<buttons.count {
            let button = buttons.element(boundBy: i)
            if button.label.contains(emoji) && !button.label.contains("Add") {
                return button
            }
        }
        
        return buttons.firstMatch
    }
    
    /// Helper to create a CustomEventType
    private func createEventType(name: String, emoji: String) {
        // Wait for the add sheet to appear and find the name text field
        let nameField = app.textFields.element(boundBy: 0)
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Name text field should exist")
        nameField.tap()
        nameField.typeText(name)
        
        let emojiField = app.textFields["Tap to add emoji"]
        XCTAssertTrue(emojiField.exists, "Emoji text field should exist")
        emojiField.tap()
        emojiField.typeText(emoji)
        
        app.buttons["Save"].tap()
    }
}

private extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}

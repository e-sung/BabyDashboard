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
            let nameField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS %@", "Vomit")).firstMatch
            XCTAssertTrue(nameField.waitForExistence(timeout: 2))
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
            app.buttons["Done"].tap()
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
            
            // Sheet should dismiss and checklist button should appear
            XCTAssertTrue(
                app.staticTexts["Daily Checklist"].waitForNonExistence(timeout: 2),
                "Configuration sheet should dismiss after selection"
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
            
            // Verify button is in editable mode (has "editable" hint indicating wiggle state)
            XCTAssertEqual(
                vitaminButton.value(forKey: "hint") as? String,
                "editable",
                "Checklist button should have 'editable' hint when in configuration mode (wiggling)"
            )
            
            // Verify delete badge is visible
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
            
            // Verify button is no longer in editable mode (wiggling stopped)
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            XCTAssertTrue(vitaminButton.exists)
            
            let hint = vitaminButton.value(forKey: "hint") as? String
            XCTAssertTrue(
                hint == nil || hint == "",
                "Checklist button should NOT have 'editable' hint when config mode is off (not wiggling)"
            )
            
            // Verify delete badge is hidden
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
            
            // Verify event has today's timestamp
            let todayEvents = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "00:00"))
            XCTAssertTrue(
                todayEvents.count > 0,
                "CustomEvent should be logged with current timestamp"
            )
            
            // Go back to main view
            app.windows.firstMatch.swipeDown(velocity: .fast)
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
            
            // Go back
            app.windows.firstMatch.swipeDown(velocity: .fast)
        }
    }
    
    /// Documents adding multiple checklist items and the 3-item limit
    func testMultipleChecklistItems() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
        XCTContext.runActivity(named: "1. Create Three CustomEventTypes") { _ in
            // Navigate to History -> Custom Event Type Management
            app.buttons["History"].tap()
            
            // Find and tap the event type picker or add button
            // Since there are no events, we need to access management differently
            app.windows.firstMatch.swipeDown(velocity: .fast)
            
            // Enter config mode first
            app.buttons["Configure Daily Checklist"].tap()
            app.buttons["PlaceholderChecklistButton"].tap()
            
            // Create first event type: Vitamin 💊
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Manage Event Types")).firstMatch.tap()
            createEventType(name: "Vitamin", emoji: "💊")
            
            // Create second event type: Bath 🛁
            app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Add Event Type")).firstMatch.tap()
            let nameField2 = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS %@", "Vomit")).firstMatch
            nameField2.tap()
            nameField2.typeText("Bath")
            app.textFields["Tap to add emoji"].tap()
            app.textFields["Tap to add emoji"].typeText("🛁")
            app.buttons["Save"].tap()
            
            // Create third event type: Medicine 💉
            app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Add Event Type")).firstMatch.tap()
            let nameField3 = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS %@", "Vomit")).firstMatch
            nameField3.tap()
            nameField3.typeText("Medicine")
            app.textFields["Tap to add emoji"].tap()
            app.textFields["Tap to add emoji"].typeText("💉")
            app.buttons["Save"].tap()
            
            app.buttons["Done"].tap()
        }
        
        XCTContext.runActivity(named: "2. Add All Three Items to Checklist") { _ in
            // Add Vitamin
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Vitamin")).firstMatch.tap()
            sleep(1)
            
            // Placeholder should still be visible (max not reached)
            XCTAssertTrue(
                app.buttons["PlaceholderChecklistButton"].exists,
                "Placeholder should still be visible after adding 1 item"
            )
            
            // Add Bath
            app.buttons["PlaceholderChecklistButton"].tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Bath")).firstMatch.tap()
            sleep(1)
            
            // Placeholder should still be visible (max not reached)
            XCTAssertTrue(
                app.buttons["PlaceholderChecklistButton"].exists,
                "Placeholder should still be visible after adding 2 items"
            )
            
            // Add Medicine
            app.buttons["PlaceholderChecklistButton"].tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Medicine")).firstMatch.tap()
            sleep(1)
            
            // Placeholder should NO LONGER be visible (max of 3 reached)
            XCTAssertFalse(
                app.buttons["PlaceholderChecklistButton"].exists,
                "Placeholder should be hidden after adding 3 items (max limit)"
            )
        }
        
        XCTContext.runActivity(named: "3. Verify All Three Items Wiggling") { _ in
            // All three buttons should have "editable" hint (wiggling)
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            let bathButton = findChecklistButton(withEmoji: "🛁")
            let medicineButton = findChecklistButton(withEmoji: "💉")
            
            XCTAssertEqual(vitaminButton.value(forKey: "hint") as? String, "editable")
            XCTAssertEqual(bathButton.value(forKey: "hint") as? String, "editable")
            XCTAssertEqual(medicineButton.value(forKey: "hint") as? String, "editable")
        }
        
        XCTContext.runActivity(named: "4. Exit Config Mode - All Stop Wiggling") { _ in
            app.buttons["Configure Daily Checklist"].tap()
            sleep(1)
            
            // All buttons should no longer have "editable" hint
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            let bathButton = findChecklistButton(withEmoji: "🛁")
            let medicineButton = findChecklistButton(withEmoji: "💉")
            
            let vitaminHint = vitaminButton.value(forKey: "hint") as? String
            let bathHint = bathButton.value(forKey: "hint") as? String
            let medicineHint = medicineButton.value(forKey: "hint") as? String
            
            XCTAssertTrue(vitaminHint == nil || vitaminHint == "")
            XCTAssertTrue(bathHint == nil || bathHint == "")
            XCTAssertTrue(medicineHint == nil || medicineHint == "")
        }
    }
    
    /// Documents removing checklist items via delete badge
    func testRemoveChecklistItem() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
        XCTContext.runActivity(named: "1. Setup - Add Checklist Item") { _ in
            app.buttons["Configure Daily Checklist"].tap()
            app.buttons["PlaceholderChecklistButton"].tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Manage Event Types")).firstMatch.tap()
            createEventType(name: "Vitamin", emoji: "💊")
            app.buttons["Done"].tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Vitamin")).firstMatch.tap()
        }
        
        XCTContext.runActivity(named: "2. Remove Item via Delete Badge") { _ in
            // Should still be in config mode, verify delete badge exists
            let deleteButton = app.buttons["Remove from checklist"]
            XCTAssertTrue(deleteButton.exists, "Delete badge should be visible")
            
            // Tap delete badge
            deleteButton.tap()
            
            // Vitamin button should disappear
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            XCTAssertTrue(
                vitaminButton.waitForNonExistence(timeout: 2),
                "Vitamin button should be removed from checklist"
            )
            
            // Placeholder should reappear
            XCTAssertTrue(
                app.buttons["PlaceholderChecklistButton"].exists,
                "Placeholder should reappear after removing item"
            )
        }
        
        XCTContext.runActivity(named: "3. Verify Persistence - Item Stays Removed") { _ in
            // Exit config mode
            app.buttons["Configure Daily Checklist"].tap()
            
            // Vitamin button should still not exist
            let vitaminButton = findChecklistButton(withEmoji: "💊")
            XCTAssertFalse(vitaminButton.exists, "Removed item should not reappear")
            
            // Re-enter config mode
            app.buttons["Configure Daily Checklist"].tap()
            
            // Should still be empty with placeholder
            XCTAssertTrue(
                app.buttons["PlaceholderChecklistButton"].exists,
                "Placeholder should persist indicating item is permanently removed"
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
        let nameField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS %@", "Vomit")).firstMatch
        nameField.tap()
        nameField.typeText(name)
        
        let emojiField = app.textFields["Tap to add emoji"]
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

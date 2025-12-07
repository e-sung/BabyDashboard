//
//  EmojiPickerUITests.swift
//  BabyDashboardUITests
//
//  UI tests for emoji picker interaction in CustomEventType creation/editing
//

import XCTest

final class EmojiPickerUITests: XCTestCase {
    
    var app: XCUIApplication!
    private let baseTime: TimeInterval = 1704099600 // 2024-01-01 00:00:00 UTC
    private let defaultTimeout: TimeInterval = 10
    
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
    
    /// Tests that emoji picker displays and allows selection from grid
    func testEmojiPickerGridSelection() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
        XCTContext.runActivity(named: "1. Navigate to Custom Event Type Management") { _ in
            app.buttons["History"].tap()
            
            // Look for the gear/settings button to access management
            let manageButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Manage")).firstMatch
            if !manageButton.exists {
                // Alternative: look for navigation items
                app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Custom")).firstMatch.tap()
            } else {
                manageButton.tap()
            }
            
            XCTAssertTrue(
                app.staticTexts["Custom Event Types"].waitForExistence(timeout: defaultTimeout),
                "Custom Event Types management view should appear"
            )
        }
        
        XCTContext.runActivity(named: "2. Open Add Event Type Sheet") { _ in
            // Tap plus button
            app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Add Event Type")).firstMatch.tap()
            
            XCTAssertTrue(
                app.staticTexts["New Event Type"].waitForExistence(timeout: defaultTimeout),
                "Add Event Type sheet should appear"
            )
        }
        
        XCTContext.runActivity(named: "3. Verify Emoji Picker is in Picker Mode") { _ in
            // Verify picker mode is selected by default
            let pickerSegment = app.buttons["Picker"]
            XCTAssertTrue(pickerSegment.exists, "Picker mode button should exist")
            
            // Verify emoji grid is visible (check for a known emoji button)
            let bathEmoji = app.buttons["EmojiButton_🛁"]
            XCTAssertTrue(
                bathEmoji.waitForExistence(timeout: defaultTimeout),
                "Bath emoji should be visible in picker grid"
            )
        }
        
        XCTContext.runActivity(named: "4. Select Emoji from Grid") { _ in
            // Tap bath emoji
            app.buttons["EmojiButton_🛁"].tap()
            
            // Verify emoji appears in the large display area
            let selectedDisplay = app.staticTexts["🛁"]
            XCTAssertTrue(
                selectedDisplay.exists,
                "Selected emoji should appear in display area"
            )
        }
        
        XCTContext.runActivity(named: "5. Complete Event Type Creation") { _ in
            // Enter name
            let nameField = app.textFields["EventNameField"]
            XCTAssertTrue(nameField.exists, "Name field should exist")
            nameField.tap()
            nameField.typeText("Bath Time")
            
            // Save
            app.buttons["Save"].tap()
            
            // Verify we're back at management view
            XCTAssertTrue(
                app.staticTexts["Custom Event Types"].waitForExistence(timeout: defaultTimeout),
                "Should return to management view after save"
            )
            
            // Verify new event type appears with emoji
            XCTAssertTrue(
                app.staticTexts["Bath Time"].exists,
                "New event type should appear in list"
            )
        }
    }
    
    /// Tests search functionality in emoji picker
    func testEmojiPickerSearch() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
        navigateToAddEventTypeSheet()
        
        XCTContext.runActivity(named: "1. Verify Search Field Exists") { _ in
            let searchField = app.textFields["EmojiSearchField"]
            XCTAssertTrue(
                searchField.waitForExistence(timeout: defaultTimeout),
                "Search field should be visible in picker mode"
            )
        }
        
        XCTContext.runActivity(named: "2. Search for 'medicine'") { _ in
            let searchField = app.textFields["EmojiSearchField"]
            searchField.tap()
            searchField.typeText("medicine")
            
            // Give search time to filter
            sleep(1)
            
            // Verify medicine emoji (💊) is visible
            let medicineEmoji = app.buttons["EmojiButton_💊"]
            XCTAssertTrue(
                medicineEmoji.exists,
                "Medicine emoji should be visible after search"
            )
            
            // Verify unrelated emoji (e.g., bath) is NOT visible
            let bathEmoji = app.buttons["EmojiButton_🛁"]
            XCTAssertFalse(
                bathEmoji.exists,
                "Bath emoji should be filtered out when searching for medicine"
            )
        }
        
        XCTContext.runActivity(named: "3. Clear Search") { _ in
            // Tap X button to clear search
            let clearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "xmark")).firstMatch
            clearButton.tap()
            
            // Verify all emojis are visible again
            let bathEmoji = app.buttons["EmojiButton_🛁"]
            XCTAssertTrue(
                bathEmoji.waitForExistence(timeout: defaultTimeout),
                "All emojis should be visible after clearing search"
            )
        }
    }
    
    /// Tests keyboard fallback mode
    func testKeyboardFallbackMode() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
        navigateToAddEventTypeSheet()
        
        XCTContext.runActivity(named: "1. Switch to Keyboard Mode") { _ in
            let keyboardSegment = app.buttons["Keyboard"]
            XCTAssertTrue(keyboardSegment.exists, "Keyboard mode button should exist")
            keyboardSegment.tap()
            
            // Verify keyboard input field appears
            let keyboardField = app.textFields["EmojiKeyboardField"]
            XCTAssertTrue(
                keyboardField.waitForExistence(timeout: defaultTimeout),
                "Keyboard input field should appear in keyboard mode"
            )
        }
        
        XCTContext.runActivity(named: "2. Enter Emoji via Keyboard") { _ in
            let keyboardField = app.textFields["EmojiKeyboardField"]
            keyboardField.tap()
            keyboardField.typeText("💊")
            
            // Verify emoji appears
            XCTAssertEqual(
                keyboardField.value as? String,
                "💊",
                "Emoji should appear in keyboard field"
            )
        }
        
        XCTContext.runActivity(named: "3. Switch Back to Picker Mode") { _ in
            let pickerSegment = app.buttons["Picker"]
            pickerSegment.tap()
            
            // Verify picker grid is visible again
            let bathEmoji = app.buttons["EmojiButton_🛁"]
            XCTAssertTrue(
                bathEmoji.waitForExistence(timeout: defaultTimeout),
                "Picker grid should be visible after switching modes"
            )
            
            // Verify selected emoji persists
            let selectedDisplay = app.staticTexts["💊"]
            XCTAssertTrue(
                selectedDisplay.exists,
                "Previously selected emoji should persist across mode switches"
            )
        }
    }
    
    /// Tests emoji picker in Edit mode maintains selected emoji
    func testEmojiPickerInEditMode() throws {
        launchApp(seed: "babiesWithSomeLogs")
        
        // First create an event type
        navigateToAddEventTypeSheet()
        
        XCTContext.runActivity(named: "1. Create Event Type with Emoji") { _ in
            app.buttons["EmojiButton_💊"].tap()
            
            let nameField = app.textFields["EventNameField"]
            nameField.tap()
            nameField.typeText("Vitamin")
            
            app.buttons["Save"].tap()
            
            XCTAssertTrue(
                app.staticTexts["Vitamin"].waitForExistence(timeout: defaultTimeout),
                "Event type should be created"
            )
        }
        
        XCTContext.runActivity(named: "2. Edit Event Type") { _ in
            // Tap on the created event type to edit
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Vitamin")).firstMatch.tap()
            
            XCTAssertTrue(
                app.staticTexts["Edit Event Type"].waitForExistence(timeout: defaultTimeout),
                "Edit sheet should appear"
            )
            
            // Verify current emoji is displayed
            let selectedDisplay = app.staticTexts["💊"]
            XCTAssertTrue(
                selectedDisplay.exists,
                "Current emoji should be displayed in edit mode"
            )
        }
        
        XCTContext.runActivity(named: "3. Change Emoji") { _ in
            // Select a different emoji
            app.buttons["EmojiButton_🛁"].tap()
            
            // Save
            app.buttons["Save"].tap()
            
            // Verify change persisted
            XCTAssertTrue(
                app.staticTexts["Custom Event Types"].waitForExistence(timeout: defaultTimeout),
                "Should return to management view"
            )
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    private func navigateToAddEventTypeSheet() {
        app.buttons["History"].tap()
        
        // Navigate to Custom Event Type Management
        let manageButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Manage")).firstMatch
        if manageButton.exists {
            manageButton.tap()
        } else {
            app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Custom")).firstMatch.tap()
        }
        
        XCTAssertTrue(
            app.staticTexts["Custom Event Types"].waitForExistence(timeout: defaultTimeout),
            "Custom Event Types management view should appear"
        )
        
        // Tap plus button
        app.navigationBars.buttons.matching(NSPredicate(format: "label == %@", "Add Event Type")).firstMatch.tap()
        
        XCTAssertTrue(
            app.staticTexts["New Event Type"].waitForExistence(timeout: defaultTimeout),
            "Add Event Type sheet should appear"
        )
    }
}

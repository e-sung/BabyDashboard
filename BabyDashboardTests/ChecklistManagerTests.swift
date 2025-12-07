import Testing
import Foundation
import CoreData
import Model
@testable import BabyDashboard

/// Tests for ChecklistManager - Documents the daily checklist workflow
/// This replaces the slow UI test with fast, focused unit tests
@Suite("Daily Checklist Manager")
@MainActor
struct ChecklistManagerTests {
    
    // Each test gets a fresh in-memory context
    func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).viewContext
    }
    
    // MARK: - Configuration Tests
    
    @Test("Can add event type to checklist")
    func addEventTypeToChecklist() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        
        // When
        let item = try manager.addToChecklist(baby: baby, eventType: eventType)
        
        // Then
        #expect(item.eventTypeEmoji == "💊")
        #expect(item.eventTypeName == "Vitamin")
        #expect(item.baby.id == baby.id)
        #expect(baby.dailyChecklistArray.count == 1)
    }
    
    @Test("Can remove event type from checklist")
    func removeEventTypeFromChecklist() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        let item = try manager.addToChecklist(baby: baby, eventType: eventType)
        #expect(baby.dailyChecklistArray.count == 1)
        
        // When
        try manager.removeFromChecklist(item: item)
        
        // Then
        #expect(baby.dailyChecklistArray.count == 0)
    }
    
    @Test("Cannot add more than 3 items to checklist")
    func enforceMaximumChecklistItems() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let type1 = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        let type2 = CustomEventType(context: context, name: "Bath", emoji: "🛁")
        let type3 = CustomEventType(context: context, name: "Medicine", emoji: "💉")
        let type4 = CustomEventType(context: context, name: "Walk", emoji: "🚶")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        
        // When: Add 3 items
        _ = try manager.addToChecklist(baby: baby, eventType: type1)
        _ = try manager.addToChecklist(baby: baby, eventType: type2)
        _ = try manager.addToChecklist(baby: baby, eventType: type3)
        
        // Then: 4th should fail
        #expect(throws: ChecklistError.self) {
            try manager.addToChecklist(baby: baby, eventType: type4)
        }
        
        #expect(baby.dailyChecklistArray.count == 3)
    }
    
    @Test("Cannot add duplicate emoji to checklist")
    func preventDuplicateEmojis() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        _ = try manager.addToChecklist(baby: baby, eventType: eventType)
        
        // When: Try to add same emoji again
        let duplicate = CustomEventType(context: context, name: "Vitamin B", emoji: "💊")
        try context.save()
        
        // Then: Should fail
        #expect(throws: ChecklistError.self) {
            try manager.addToChecklist(baby: baby, eventType: duplicate)
        }
    }
    
    // MARK: - Toggle Tests
    
    @Test("Toggle ON creates CustomEvent")
    func toggleOnCreatesEvent() throws {
        // Given: Checklist item exists
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        _ = try manager.addToChecklist(baby: baby, eventType: eventType)
        
        let timestamp = Date()
        
        // When: Toggle ON (currently unchecked)
        let event = try manager.toggleChecklistItem(
            baby: baby,
            emoji: "💊",
            name: "Vitamin",
            currentlyChecked: false,
            timestamp: timestamp
        )
        
        // Then
        #expect(event != nil)
        #expect(event?.eventTypeEmoji == "💊")
        #expect(event?.eventTypeName == "Vitamin")
        #expect(event?.profile?.id == baby.id)
        #expect(baby.customEventsArray.count == 1)
    }
    
    @Test("Toggle OFF deletes CustomEvent")
    func toggleOffDeletesEvent() throws {
        // Given: Checklist item exists and is checked
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        _ = try manager.addToChecklist(baby: baby, eventType: eventType)
        
        let timestamp = Date()
        
        // Create event (toggle ON)
        let event = try manager.toggleChecklistItem(
            baby: baby,
            emoji: "💊",
            name: "Vitamin",
            currentlyChecked: false,
            timestamp: timestamp
        )
        #expect(event != nil)
        #expect(baby.customEventsArray.count == 1)
        
        // When: Toggle OFF (currently checked)
        let result = try manager.toggleChecklistItem(
            baby: baby,
            emoji: "💊",
            name: "Vitamin",
            currentlyChecked: true,
            timestamp: timestamp
        )
        
        // Then
        #expect(result == nil)
        #expect(baby.customEventsArray.count == 0)
    }
    
    @Test("isCheckedToday returns correct state")
    func isCheckedTodayQuery() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        _ = try manager.addToChecklist(baby: baby, eventType: eventType)
        
        let timestamp = Date()
        
        // Initially unchecked
        #expect(manager.isCheckedToday(baby: baby, emoji: "💊", timestamp: timestamp) == false)
        
        // Toggle ON
        _ = try manager.toggleChecklistItem(
            baby: baby,
            emoji: "💊",
            name: "Vitamin",
            currentlyChecked: false,
            timestamp: timestamp
        )
        
        // Now checked
        #expect(manager.isCheckedToday(baby: baby, emoji: "💊", timestamp: timestamp) == true)
    }
    
    @Test("Toggle only affects today's events")
    func toggleOnlyAffectsTodaysEvents() throws {
        // Given: Checklist item and yesterday's event
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        let manager = ChecklistManager(context: context)
        _ = try manager.addToChecklist(baby: baby, eventType: eventType)
        
        // Create yesterday's event
        let yesterday = Date().addingTimeInterval(-24 * 3600)
        let yesterdayEvent = CustomEvent(
            context: context,
            timestamp: yesterday,
            eventTypeName: "Vitamin",
            eventTypeEmoji: "💊"
        )
        yesterdayEvent.profile = baby
        try context.save()
        
        #expect(baby.customEventsArray.count == 1)
        
        // Create today's event
        let today = Date()
        _ = try manager.toggleChecklistItem(
            baby: baby,
            emoji: "💊",
            name: "Vitamin",
            currentlyChecked: false,
            timestamp: today
        )
        
        // Now we have 2 events: yesterday and today
        #expect(baby.customEventsArray.count == 2)
        
        // When: Toggle OFF today (should only delete today's event)
        _ = try manager.toggleChecklistItem(
            baby: baby,
            emoji: "💊",
            name: "Vitamin",
            currentlyChecked: true,
            timestamp: today
        )
        
        // Then: Only yesterday's event should remain
        #expect(baby.customEventsArray.count == 1)
        
        let remainingEvent = baby.customEventsArray.first!
        let timeDiff = abs(remainingEvent.timestamp.timeIntervalSince(yesterday))
        #expect(timeDiff < 1.0) // Should be yesterday's event
    }
    
    // MARK: - Edge Cases
    
    @Test("Start of day respects app settings")
    func startOfDayRespectsSettings() throws {
        // Given: App start of day is 4 AM
        let settings = AppSettings()
        settings.startOfDayHour = 4
        settings.startOfDayMinute = 0
        
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        try context.save()
        
        // Create manager with settings
        let manager = ChecklistManager(context: context, settings: settings)
        _ = try manager.addToChecklist(baby: baby, eventType: eventType)
        
        // When: Create event at 2 AM (should be "yesterday")
        let calendar = Calendar.current
        let twoAM = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: Date())!
        
        _ = try manager.toggleChecklistItem(
            baby: baby,
            emoji: "💊",
            name: "Vitamin",
            currentlyChecked: false,
            timestamp: twoAM
        )
        
        // Then: Event should exist
        #expect(baby.customEventsArray.count == 1)
        
        // When: Check if it's checked "today" (from 6 AM perspective)
        let sixAM = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: Date())!
        let isChecked = manager.isCheckedToday(baby: baby, emoji: "💊", timestamp: sixAM)
        
        // Then: 2 AM event should not count as "today" (it's before 4 AM cutoff)
        #expect(isChecked == false)
    }
}

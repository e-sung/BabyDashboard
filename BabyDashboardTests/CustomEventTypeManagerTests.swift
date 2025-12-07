import Testing
import Foundation
import CoreData
import Model
@testable import BabyDashboard

/// Tests for CustomEventTypeManager - Documents event type management workflow
/// Replaces slow UI tests with fast, focused unit tests
@Suite("CustomEventType Manager")
@MainActor
struct CustomEventTypeManagerTests {
    
    // Each test gets a fresh in-memory context
    func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).viewContext
    }
    
    // MARK: - Creation Tests
    
    @Test("Can create event type with valid inputs")
    func createValidEventType() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        // When
        let eventType = try manager.create(name: "Vitamin", emoji: "💊")
        
        // Then
        #expect(eventType.name == "Vitamin")
        #expect(eventType.emoji == "💊")
        #expect(eventType.id != nil)
        #expect(eventType.createdAt != nil)
    }
    
    @Test("Cannot create with empty name")
    func rejectEmptyName() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        // When/Then
        #expect(throws: CustomEventTypeError.self) {
            try manager.create(name: "", emoji: "💊")
        }
    }
    
    @Test("Cannot create with empty emoji")
    func rejectEmptyEmoji() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        // When/Then
        #expect(throws: CustomEventTypeError.self) {
            try manager.create(name: "Vitamin", emoji: "")
        }
    }
    
    @Test("Cannot create with duplicate emoji")
    func preventDuplicateEmoji() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        // Create first event type
        _ = try manager.create(name: "Vitamin", emoji: "💊")
        
        // When/Then: Attempt to create duplicate
        #expect(throws: CustomEventTypeError.self) {
            try manager.create(name: "Medicine", emoji: "💊")
        }
    }
    
    // MARK: - Update Tests
    
    @Test("Can update event type name")
    func updateName() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        let eventType = try manager.create(name: "Vitamin", emoji: "💊")
        
        // When
        try manager.update(eventType, name: "Vitamin D", emoji: "💊")
        
        // Then
        #expect(eventType.name == "Vitamin D")
        #expect(eventType.emoji == "💊")
    }
    
    @Test("Can update emoji to unique value")
    func updateEmojiToUnique() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        let eventType = try manager.create(name: "Vitamin", emoji: "💊")
        
        // When
        try manager.update(eventType, name: "Vitamin", emoji: "💉")
        
        // Then
        #expect(eventType.name == "Vitamin")
        #expect(eventType.emoji == "💉")
    }
    
    @Test("Cannot update emoji to duplicate")
    func preventEmojiUpdateToDuplicate() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        _ = try manager.create(name: "Vitamin", emoji: "💊")
        let eventType2 = try manager.create(name: "Bath", emoji: "🛁")
        
        // When/Then: Try to change Bath emoji to Vitamin emoji
        #expect(throws: CustomEventTypeError.self) {
            try manager.update(eventType2, name: "Bath", emoji: "💊")
        }
    }
    
    @Test("Can update emoji to same value (no-op)")
    func updateEmojiToSameValue() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        let eventType = try manager.create(name: "Vitamin", emoji: "💊")
        
        // When: Update to same emoji (should not throw)
        try manager.update(eventType, name: "Vitamin D", emoji: "💊")
        
        // Then
        #expect(eventType.name == "Vitamin D")
        #expect(eventType.emoji == "💊")
    }
    
    // MARK: - Deletion Tests
    
    @Test("Can delete event type")
    func deleteEventType() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        let eventType = try manager.create(name: "Vitamin", emoji: "💊")
        
        let fetchRequest: NSFetchRequest<CustomEventType> = CustomEventType.fetchRequest()
        var allTypes = try context.fetch(fetchRequest)
        #expect(allTypes.count == 1)
        
        // When
        try manager.delete(eventType)
        
        // Then
        allTypes = try context.fetch(fetchRequest)
        #expect(allTypes.count == 0)
    }
    
    @Test("Deletion preserves denormalized data in CustomEvents")
    func deletionPreservesDenormalizedData() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        let baby = BabyProfile(context: context, name: "Test Baby")
        
        let eventType = try manager.create(name: "Vitamin", emoji: "💊")
        
        // Create CustomEvent with denormalized data
        let event = CustomEvent(
            context: context,
            timestamp: Date(),
            eventTypeName: eventType.name,
            eventTypeEmoji: eventType.emoji
        )
        event.profile = baby
        try context.save()
        
        #expect(baby.customEventsArray.count == 1)
        
        // When: Delete event type
        try manager.delete(eventType)
        
        // Then: CustomEvent should still exist with denormalized data
        #expect(baby.customEventsArray.count == 1)
        #expect(baby.customEventsArray.first?.eventTypeName == "Vitamin")
        #expect(baby.customEventsArray.first?.eventTypeEmoji == "💊")
    }
    
    // MARK: - Edge Cases
    
    @Test("Trims whitespace from name and emoji")
    func trimWhitespace() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        // When: Create with whitespace
        let eventType = try manager.create(name: "  Vitamin  ", emoji: "  💊  ")
        
        // Then: Whitespace should be trimmed
        #expect(eventType.name == "Vitamin")
        #expect(eventType.emoji == "💊")
    }
    
    @Test("Emoji comparison is exact match")
    func emojiExactMatch() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        // When: Create with specific emoji
        _ = try manager.create(name: "Type1", emoji: "💊")
        
        // Then: Same emoji should be considered duplicate
        #expect(throws: CustomEventTypeError.self) {
            try manager.create(name: "Type2", emoji: "💊")
        }
    }
    
    @Test("Empty string after trimming is invalid")
    func emptyAfterTrimming() throws {
        // Given
        let context = makeContext()
        let manager = CustomEventTypeManager(context: context)
        
        // When/Then: Whitespace-only strings should be rejected
        #expect(throws: CustomEventTypeError.self) {
            try manager.create(name: "   ", emoji: "💊")
        }
        
        #expect(throws: CustomEventTypeError.self) {
            try manager.create(name: "Vitamin", emoji: "   ")
        }
    }
}

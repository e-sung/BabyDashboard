import Foundation
import CoreData
import Model

/// Errors that can occur during CustomEventType operations
enum CustomEventTypeError: LocalizedError {
    case invalidName
    case invalidEmoji
    case duplicateEmoji(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Event type name cannot be empty"
        case .invalidEmoji:
            return "Event type emoji cannot be empty"
        case .duplicateEmoji(let emoji):
            return "An event type with emoji \(emoji) already exists. Please choose a different emoji."
        }
    }
}

/// Manages CustomEventType CRUD operations with validation
@MainActor
class CustomEventTypeManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Create
    
    /// Creates a new CustomEventType with validation
    /// - Parameters:
    ///   - name: The display name for the event type
    ///   - emoji: The emoji identifier for the event type
    /// - Returns: The created CustomEventType
    /// - Throws: `CustomEventTypeError` if validation fails
    @discardableResult
    func create(name: String, emoji: String) throws -> CustomEventType {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name
        guard !trimmedName.isEmpty else {
            throw CustomEventTypeError.invalidName
        }
        
        // Validate emoji
        guard !trimmedEmoji.isEmpty else {
            throw CustomEventTypeError.invalidEmoji
        }
        
        // Check for duplicate emoji
        try validateUniqueEmoji(trimmedEmoji, excluding: nil)
        
        // Create event type
        let eventType = CustomEventType(context: context, name: trimmedName, emoji: trimmedEmoji)
        
        try context.save()
        NearbySyncManager.shared.sendPing()
        
        return eventType
    }
    
    // MARK: - Update
    
    /// Updates an existing CustomEventType with validation
    /// - Parameters:
    ///   - eventType: The event type to update
    ///   - name: The new name
    ///   - emoji: The new emoji
    /// - Throws: `CustomEventTypeError` if validation fails
    func update(_ eventType: CustomEventType, name: String, emoji: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name
        guard !trimmedName.isEmpty else {
            throw CustomEventTypeError.invalidName
        }
        
        // Validate emoji
        guard !trimmedEmoji.isEmpty else {
            throw CustomEventTypeError.invalidEmoji
        }
        
        // Check for duplicate emoji (excluding self)
        try validateUniqueEmoji(trimmedEmoji, excluding: eventType)
        
        // Update properties
        eventType.name = trimmedName
        eventType.emoji = trimmedEmoji
        
        try context.save()
        NearbySyncManager.shared.sendPing()
    }
    
    // MARK: - Delete
    
    /// Deletes a CustomEventType
    /// Note: Associated CustomEvents and DailyChecklist items will keep their denormalized data
    /// - Parameter eventType: The event type to delete
    /// - Throws: Core Data errors if deletion fails
    func delete(_ eventType: CustomEventType) throws {
        context.delete(eventType)
        try context.save()
        NearbySyncManager.shared.sendPing()
    }
    
    // MARK: - Validation Helpers
    
    /// Validates that an emoji is unique (not already used by another event type)
    /// - Parameters:
    ///   - emoji: The emoji to validate
    ///   - excluding: An optional event type to exclude from the check (for updates)
    /// - Throws: `CustomEventTypeError.duplicateEmoji` if emoji is already in use
    private func validateUniqueEmoji(_ emoji: String, excluding: CustomEventType?) throws {
        let fetchRequest: NSFetchRequest<CustomEventType> = CustomEventType.fetchRequest()
        let existingTypes = try context.fetch(fetchRequest)
        
        // Check if any other event type uses this emoji
        let hasDuplicate = existingTypes.contains { existingType in
            // Exclude the event type being updated (same object ID)
            if let excluding = excluding, existingType.objectID == excluding.objectID {
                return false
            }
            return existingType.emoji == emoji
        }
        
        if hasDuplicate {
            throw CustomEventTypeError.duplicateEmoji(emoji)
        }
    }
}

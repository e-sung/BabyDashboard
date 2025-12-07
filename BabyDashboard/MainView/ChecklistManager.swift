import Foundation
import CoreData
import Model

/// Errors that can occur during checklist operations
enum ChecklistError: LocalizedError {
    case maximumItemsReached
    case duplicateEmoji(String)
    case itemNotFound
    case eventNotFound
    
    var errorDescription: String? {
        switch self {
        case .maximumItemsReached:
            return "Maximum of 3 checklist items reached"
        case .duplicateEmoji(let emoji):
            return "An item with emoji \(emoji) already exists"
        case .itemNotFound:
            return "Checklist item not found"
        case .eventNotFound:
            return "Event not found for today"
        }
    }
}

/// Manages daily checklist operations including adding/removing items and toggling events
@MainActor
class ChecklistManager {
    private let context: NSManagedObjectContext
    private let settings: AppSettings
    
    private let maxChecklistItems = 3
    
    init(context: NSManagedObjectContext, settings: AppSettings = AppSettings()) {
        self.context = context
        self.settings = settings
    }
    
    // MARK: - Configuration Operations
    
    /// Adds an event type to the baby's daily checklist
    /// - Parameters:
    ///   - baby: The baby profile to add the checklist item to
    ///   - eventType: The custom event type to add
    /// - Returns: The created DailyChecklist item
    /// - Throws: `ChecklistError.maximumItemsReached` if already at 3 items,
    ///          `ChecklistError.duplicateEmoji` if emoji already exists in checklist
    @discardableResult
    func addToChecklist(baby: BabyProfile, eventType: CustomEventType) throws -> DailyChecklist {
        // Validate maximum items
        guard baby.dailyChecklistArray.count < maxChecklistItems else {
            throw ChecklistError.maximumItemsReached
        }
        
        // Validate no duplicate emojis
        let existingEmojis = Set(baby.dailyChecklistArray.map { $0.eventTypeEmoji })
        guard !existingEmojis.contains(eventType.emoji) else {
            throw ChecklistError.duplicateEmoji(eventType.emoji)
        }
        
        // Create checklist item
        let maxOrder = baby.dailyChecklistArray.map(\.order).max() ?? -1
        let item = DailyChecklist(
            context: context,
            baby: baby,
            eventTypeName: eventType.name,
            eventTypeEmoji: eventType.emoji,
            order: maxOrder + 1
        )
        
        try context.save()
        NearbySyncManager.shared.sendPing()
        
        return item
    }
    
    /// Removes a checklist item
    /// - Parameter item: The checklist item to remove
    /// - Throws: Core Data errors if save fails
    func removeFromChecklist(item: DailyChecklist) throws {
        context.delete(item)
        try context.save()
        NearbySyncManager.shared.sendPing()
    }
    
    // MARK: - Toggle Operations
    
    /// Toggles a checklist item on or off
    /// - Parameters:
    ///   - baby: The baby profile
    ///   - emoji: The emoji identifier for the checklist item
    ///   - name: The name of the event type
    ///   - currentlyChecked: Whether the item is currently checked
    ///   - timestamp: The current timestamp
    /// - Returns: The created CustomEvent if toggled ON, nil if toggled OFF
    /// - Throws: Core Data errors if operations fail
    @discardableResult
    func toggleChecklistItem(
        baby: BabyProfile,
        emoji: String,
        name: String,
        currentlyChecked: Bool,
        timestamp: Date
    ) throws -> CustomEvent? {
        if currentlyChecked {
            // Toggle OFF: Delete today's event
            try deleteEventForToday(baby: baby, emoji: emoji, timestamp: timestamp)
            return nil
        } else {
            // Toggle ON: Create new event
            return try createEvent(baby: baby, emoji: emoji, name: name, timestamp: timestamp)
        }
    }
    
    // MARK: - Queries
    
    /// Checks if a checklist item is checked today
    /// - Parameters:
    ///   - baby: The baby profile
    ///   - emoji: The emoji identifier
    ///   - timestamp: The reference timestamp for "today"
    /// - Returns: True if an event with this emoji exists today
    func isCheckedToday(baby: BabyProfile, emoji: String, timestamp: Date) -> Bool {
        let startOfDay = getStartOfDay(now: timestamp)
        
        return baby.customEventsArray.contains { event in
            event.eventTypeEmoji == emoji && event.timestamp >= startOfDay
        }
    }
    
    // MARK: - Private Helpers
    
    private func deleteEventForToday(baby: BabyProfile, emoji: String, timestamp: Date) throws {
        let startOfDay = getStartOfDay(now: timestamp)
        
        guard let event = baby.customEventsArray.first(where: { event in
            event.eventTypeEmoji == emoji && event.timestamp >= startOfDay
        }) else {
            throw ChecklistError.eventNotFound
        }
        
        context.delete(event)
        try context.save()
        NearbySyncManager.shared.sendPing()
    }
    
    private func createEvent(baby: BabyProfile, emoji: String, name: String, timestamp: Date) throws -> CustomEvent {
        let event = CustomEvent(
            context: context,
            timestamp: timestamp,
            eventTypeName: name,
            eventTypeEmoji: emoji
        )
        event.profile = baby
        
        try context.save()
        NearbySyncManager.shared.sendPing()
        
        return event
    }
    
    private func getStartOfDay(now: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        // Set to today's start time
        components.hour = settings.startOfDayHour
        components.minute = settings.startOfDayMinute
        components.second = 0
        
        guard let todayStart = calendar.date(from: components) else { return now }
        
        // If now is before today's start time, then the "current day" started yesterday
        if now < todayStart {
            return calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        }
        
        return todayStart
    }
}

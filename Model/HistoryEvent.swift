import Foundation
import SwiftData

// A view-specific wrapper to unify different event models for display in a single list.
public enum HistoryEventType { case feed, diaper }

public struct HistoryEvent: Identifiable, Hashable {
    public let id: UUID
    public let date: Date
    public let babyName: String
    public let type: HistoryEventType
    public let details: String
    public let diaperType: DiaperType? // New property

    // A reference to the underlying SwiftData object for editing/deleting.
    // Note: Hashable conformance requires a stable hash value.
    // Make this optional so previews can pass nil without constructing a PersistentIdentifier.
    public let underlyingObjectId: PersistentIdentifier?

    public init(id: UUID, date: Date, babyName: String, type: HistoryEventType, details: String, diaperType: DiaperType?, underlyingObjectId: PersistentIdentifier?) {
        self.id = id
        self.date = date
        self.babyName = babyName
        self.type = type
        self.details = details
        self.diaperType = diaperType
        self.underlyingObjectId = underlyingObjectId
    }

    public static func == (lhs: HistoryEvent, rhs: HistoryEvent) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Add initializers to easily convert from our SwiftData models.
public extension HistoryEvent {
    init(from session: FeedSession) {
        self.id = session.id
        self.date = session.startTime
        self.babyName = session.profile?.name ?? "Unknown"
        self.type = .feed
        self.diaperType = nil // Not a diaper event
        
        let duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0
        let durationMinutes = Int(duration / 60)
        
        if let amount = session.amount {
            let formattedAmount = String(format: "%.1f", amount.value)
            self.details = "\(formattedAmount) \(amount.unit.symbol) over \(durationMinutes) min"
        } else {
            self.details = "In progress for \(durationMinutes) min"
        }
        self.underlyingObjectId = session.persistentModelID
    }
    
    init(from diaperChange: DiaperChange) {
        self.id = diaperChange.id
        self.date = diaperChange.timestamp
        self.babyName = diaperChange.profile?.name ?? "Unknown"
        self.type = .diaper
        self.diaperType = diaperChange.type // Set the diaper type
        if diaperType == .pee {
            self.details = String(localized: "Pee")
        } else {
            self.details = String(localized: "Poo")
        }

        self.underlyingObjectId = diaperChange.persistentModelID
    }
}

// Add an ID to our models to make them Identifiable for the wrapper.
public extension FeedSession {
    var id: UUID { return self.startTime.hashValue.uuid } // Simple identifiable conformance
}
public extension DiaperChange {
    var id: UUID { return self.timestamp.hashValue.uuid } // Simple identifiable conformance
}

// Helper for creating a UUID from a hash value for Identifiable conformance.
public extension Int {
    var uuid: UUID {
        return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", self))") ?? UUID()
    }
}

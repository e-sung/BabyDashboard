import Foundation
import SwiftData

// A view-specific wrapper to unify different event models for display in a single list.
enum HistoryEventType { case feed, diaper }

struct HistoryEvent: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let babyName: String
    let type: HistoryEventType
    let details: String
    let diaperType: DiaperType? // New property
    
    // A reference to the underlying SwiftData object for editing/deleting.
    // Note: Hashable conformance requires a stable hash value.
    // Make this optional so previews can pass nil without constructing a PersistentIdentifier.
    let underlyingObjectId: PersistentIdentifier?

    static func == (lhs: HistoryEvent, rhs: HistoryEvent) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Add initializers to easily convert from our SwiftData models.
extension HistoryEvent {
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
extension FeedSession {
    var id: UUID { return self.startTime.hashValue.uuid } // Simple identifiable conformance
}
extension DiaperChange {
    var id: UUID { return self.timestamp.hashValue.uuid } // Simple identifiable conformance
}

// Helper for creating a UUID from a hash value for Identifiable conformance.
extension Int {
    var uuid: UUID {
        return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", self))") ?? UUID()
    }
}

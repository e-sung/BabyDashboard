import Foundation
import SwiftData

// A view-specific wrapper to unify different event models for display in a single list.
public enum HistoryEventType { case feed, diaper }

public struct HistoryEvent: Identifiable, Hashable, Equatable {
    public let id: UUID
    public let date: Date
    public let babyName: String
    public let type: HistoryEventType
    public let details: String
    public let diaperType: DiaperType?

    // New: hashtags extracted from the underlying model (feed memo), kept as strings with leading '#'
    public let hashtags: [String]

    // A reference to the underlying SwiftData object for editing/deleting.
    // Optional so previews can pass nil.
    public let underlyingObjectId: PersistentIdentifier?

    // Keep the public initializer usable for previews/tests; default hashtags to empty.
    public init(
        id: UUID,
        date: Date,
        babyName: String,
        type: HistoryEventType,
        details: String,
        diaperType: DiaperType?,
        underlyingObjectId: PersistentIdentifier?,
        hashtags: [String] = []
    ) {
        self.id = id
        self.date = date
        self.babyName = babyName
        self.type = type
        self.details = details
        self.diaperType = diaperType
        self.underlyingObjectId = underlyingObjectId
        self.hashtags = hashtags
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
        self.diaperType = nil

        let duration = session.endTime?.timeIntervalSince(session.startTime) ?? 0
        let durationMinutes = Int(duration / 60)

        if let value = session.amountValue {
            let unit: UnitVolume = unitVolume(from: session.amountUnitSymbol) ?? ((Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
            let formattedAmount = String(format: "%.1f", value)
            self.details = "\(formattedAmount) \(unit.symbol) over \(durationMinutes) min"
        } else {
            self.details = "In progress for \(durationMinutes) min"
        }

        self.underlyingObjectId = session.persistentModelID
        // Pull hashtags from the model’s memo
        self.hashtags = session.hashtags
    }
    
    init(from diaperChange: DiaperChange) {
        self.id = diaperChange.id
        self.date = diaperChange.timestamp
        self.babyName = diaperChange.profile?.name ?? "Unknown"
        self.type = .diaper
        self.diaperType = diaperChange.type
        if diaperType == .pee {
            self.details = String(localized: "Pee")
        } else {
            self.details = String(localized: "Poo")
        }
        self.underlyingObjectId = diaperChange.persistentModelID
        self.hashtags = [] // no hashtags for diaper events
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

// Decode a UnitVolume from a symbol/name
private func unitVolume(from symbolOrName: String?) -> UnitVolume? {
    guard let s = symbolOrName else { return nil }
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    switch lower {
    case "ml", "mL".lowercased(), "milliliter", "milliliters":
        return .milliliters
    case "fl oz", "fl oz", "fl. oz", "fluid ounce", "fluid ounces", "floz":
        return .fluidOunces
    case "l", "liter", "liters":
        return .liters
    case "cup", "cups":
        return .cups
    default:
        return nil
    }
}


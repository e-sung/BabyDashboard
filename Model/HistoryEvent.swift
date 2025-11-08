import Foundation
import CoreData

public enum HistoryEventType { case feed, diaper }

public struct HistoryEvent: Identifiable, Hashable, Equatable {
    public let id: UUID
    public let date: Date
    public let babyName: String
    public let type: HistoryEventType
    public let details: String
    public let diaperType: DiaperType?
    public let hashtags: [String]
    public let underlyingObjectId: NSManagedObjectID?

    public init(
        id: UUID,
        date: Date,
        babyName: String,
        type: HistoryEventType,
        details: String,
        diaperType: DiaperType?,
        underlyingObjectId: NSManagedObjectID?,
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

public extension HistoryEvent {
    init(from session: FeedSession) {
        let start = session.startTime
        let duration = session.endTime?.timeIntervalSince(start) ?? 0
        let durationMinutes = max(0, Int(duration / 60))

        var detailsText: String
        if let amount = session.amount {
            detailsText = "\(String(format: "%.1f", amount.value)) \(amount.unit.symbol) over \(durationMinutes) min"
        } else if session.isInProgress {
            detailsText = "In progress for \(durationMinutes) min"
        } else {
            detailsText = "\(durationMinutes) min"
        }

        self.init(
            id: session.uuid,
            date: start,
            babyName: session.profile?.name ?? "Unknown",
            type: .feed,
            details: detailsText,
            diaperType: nil,
            underlyingObjectId: session.objectID,
            hashtags: session.hashtags
        )
    }

    init(from diaperChange: DiaperChange) {
        let diaper = diaperChange.diaperType
        let detailsText = diaper == .pee ? String(localized: "Pee") : String(localized: "Poo")

        self.init(
            id: diaperChange.uuid,
            date: diaperChange.timestamp,
            babyName: diaperChange.profile?.name ?? "Unknown",
            type: .diaper,
            details: detailsText,
            diaperType: diaper,
            underlyingObjectId: diaperChange.objectID,
            hashtags: []
        )
    }
}

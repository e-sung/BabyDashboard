import Foundation
import SwiftData

@Model
public class BabyProfile {
    public var id: UUID = UUID()
    public var name: String = ""
    public var lastFeedAmountValue: Double?
    public var lastFeedAmountUnitSymbol: String?

    // Keep history: when a BabyProfile is deleted, nullify its relationships so events remain as orphans.
    @Relationship(deleteRule: .nullify, inverse: \FeedSession.profile)
    public var feedSessions: [FeedSession]? = []

    @Relationship(deleteRule: .nullify, inverse: \DiaperChange.profile)
    public var diaperChanges: [DiaperChange]? = []

    // Keep convenience initializer used across the codebase/tests
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    public var inProgressFeedSession: FeedSession? {
        (feedSessions ?? []).first(where: { $0.isInProgress })
    }

    public var lastFinishedFeedSession: FeedSession? {
        (feedSessions ?? [])
            .filter { !$0.isInProgress && $0.endTime != nil }
            .sorted(by: { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) })
            .first
    }

    public var lastFeedSession: FeedSession? {
        feedSessions?
            .sorted(by: { ($0.startTime ) > ($1.startTime ) })
            .first
    }

    public var lastDiaperChange: DiaperChange? {
        (diaperChanges ?? []).sorted(by: { $0.timestamp > $1.timestamp }).first
    }
}

@Model
public class FeedSession {
    // Provide defaults for non-optional attributes
    public var startTime: Date = Date()
    public var endTime: Date?
    public var amountValue: Double?
    public var amountUnitSymbol: String?
    public var profile: BabyProfile?

    public init(startTime: Date) {
        self.startTime = startTime
    }

    // Map persisted symbols to canonical UnitVolume instances
    private func canonicalUnit(from symbol: String) -> UnitVolume? {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        switch lower {
        case "ml", "mL".lowercased(), "milliliter", "milliliters":
            return .milliliters
        case "fl oz", "fl oz", "fl. oz", "fluid ounce", "fluid ounces":
            return .fluidOunces
        case "l", "liter", "liters":
            return .liters
        case "cup", "cups":
            return .cups
        default:
            return nil
        }
    }

    // Use canonical units everywhere
    @Transient
    public var amount: Measurement<UnitVolume>? {
        get {
            guard let value = amountValue, let symbol = amountUnitSymbol else { return nil }
            guard let unit = canonicalUnit(from: symbol) else {
                // Fallback: treat as milliliters to avoid crashes (conversion may be off)
                return Measurement(value: value, unit: .milliliters)
            }
            return Measurement(value: value, unit: unit)
        }
        set {
            if let newValue {
                let unit: UnitVolume = canonicalUnit(from: newValue.unit.symbol) ?? newValue.unit
                self.amountValue = newValue.converted(to: unit).value
                self.amountUnitSymbol = unit.symbol
            } else {
                self.amountValue = nil
                self.amountUnitSymbol = nil
            }
        }
    }

    @Transient
    public var isInProgress: Bool {
        endTime == nil
    }
}

public enum DiaperType: String, Codable {
    case pee
    case poo
}

@Model
public class DiaperChange {
    // Provide defaults for non-optional attributes
    public var timestamp: Date = Date()
    public var type: DiaperType = DiaperType.pee
    public var profile: BabyProfile?

    public init(timestamp: Date, type: DiaperType) {
        self.timestamp = timestamp
        self.type = type
    }
}

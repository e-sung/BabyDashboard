import Foundation
import SwiftData

@Model
class BabyProfile {
    // CloudKit: attributes must be optional or have defaults; remove unique constraint.
    var id: UUID = UUID()
    var name: String = ""
    var lastFeedAmountValue: Double?
    var lastFeedAmountUnitSymbol: String?

    // Keep history: when a BabyProfile is deleted, nullify its relationships so events remain as orphans.
    @Relationship(deleteRule: .nullify, inverse: \FeedSession.profile)
    var feedSessions: [FeedSession]? = []

    @Relationship(deleteRule: .nullify, inverse: \DiaperChange.profile)
    var diaperChanges: [DiaperChange]? = []

    // Keep convenience initializer used across the codebase/tests
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

@Model
class FeedSession {
    // Provide defaults for non-optional attributes
    var startTime: Date = Date()
    var endTime: Date?
    var amountValue: Double?
    var amountUnitSymbol: String?
    var profile: BabyProfile?

    init(startTime: Date) {
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
    var amount: Measurement<UnitVolume>? {
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
    var isInProgress: Bool {
        endTime == nil
    }
}

enum DiaperType: String, Codable {
    case pee
    case poo
}

@Model
class DiaperChange {
    // Provide defaults for non-optional attributes
    var timestamp: Date = Date()
    var type: DiaperType = DiaperType.pee
    var profile: BabyProfile?

    init(timestamp: Date, type: DiaperType) {
        self.timestamp = timestamp
        self.type = type
    }
}

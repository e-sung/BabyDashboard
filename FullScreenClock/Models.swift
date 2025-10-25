import Foundation
import SwiftData

@Model
class BabyProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var lastFeedAmountValue: Double?
    var lastFeedAmountUnitSymbol: String?

    @Relationship(deleteRule: .cascade, inverse: \FeedSession.profile)
    var feedSessions: [FeedSession] = []

    @Relationship(deleteRule: .cascade, inverse: \DiaperChange.profile)
    var diaperChanges: [DiaperChange] = []

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

@Model
class FeedSession {
    var startTime: Date
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
                // Fallback: if we can’t map, treat as milliliters to avoid crashes (but conversions may be wrong).
                return Measurement(value: value, unit: .milliliters)
            }
            return Measurement(value: value, unit: unit)
        }
        set {
            if let newValue {
                // Normalize to a canonical unit (keep the provided unit if it’s one of the canonical ones)
                let unit: UnitVolume = {
                    // Try to map the provided unit’s symbol to a canonical unit
                    if let mapped = canonicalUnit(from: newValue.unit.symbol) {
                        return mapped
                    }
                    // Otherwise, if it’s already a known UnitVolume (e.g., .milliliters/.fluidOunces), keep it
                    // Note: UnitVolume has many cases; we’ll preserve its symbol as-is.
                    return newValue.unit
                }()

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
    var timestamp: Date
    var type: DiaperType
    var profile: BabyProfile?

    init(timestamp: Date, type: DiaperType) {
        self.timestamp = timestamp
        self.type = type
    }
}

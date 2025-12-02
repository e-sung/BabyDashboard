import Foundation
import Model

struct DaySummary: Identifiable, Equatable {
    public let id: Date // startOfDay
    public let date: Date
    public let events: [HistoryEvent]
    public let feedTotalsByBaby: [String: Measurement<UnitVolume>]
    public let diaperCountsByBaby: [String: Int]
}

func makeDaySummaries(
    events: [HistoryEvent],
    feedSessions: [FeedSession],
    diaperChanges: [DiaperChange],
    targetUnit: UnitVolume = UnitUtils.preferredUnit,
    calendar: Calendar,
    startOfDayHour: Int,
    startOfDayMinute: Int
) -> [DaySummary] {

    // Group events by day for rows
    let groupedEvents = Dictionary(grouping: events) { event in
        calendar.logicalStartOfDay(for: event.date, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
    }

    // Group models by day for accurate aggregates
    let groupedFeeds = Dictionary(grouping: feedSessions) { session in
        return calendar.logicalStartOfDay(for: session.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
    }
    let groupedDiapers = Dictionary(grouping: diaperChanges) { change in
        return calendar.logicalStartOfDay(for: change.timestamp, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
    }

    // Build sections for all days that have any events
    let allDays = Set(groupedEvents.keys).union(groupedFeeds.keys).union(groupedDiapers.keys)
    let summaries: [DaySummary] = allDays.map { day in
        let eventsForDay = (groupedEvents[day] ?? []).sorted(by: { $0.date > $1.date })

        // Feed totals per baby
        var feedTotals: [String: Measurement<UnitVolume>] = [:]
        if let feeds = groupedFeeds[day] {
            for session in feeds {
                guard let babyName = session.profile?.name else { continue }
                guard session.amountUnitSymbol != nil else { continue }
                let value = session.amountValue
                let unit = unitVolume(from: session.amountUnitSymbol) ?? UnitUtils.preferredUnit
                let convertedValue = Measurement(value: value, unit: unit).converted(to: targetUnit).value
                if let existing = feedTotals[babyName] {
                    feedTotals[babyName] = Measurement(value: existing.value + convertedValue, unit: targetUnit)
                } else {
                    feedTotals[babyName] = Measurement(value: convertedValue, unit: targetUnit)
                }
            }
        }

        // Diaper counts per baby
        var diaperCounts: [String: Int] = [:]
        if let diapers = groupedDiapers[day] {
            for change in diapers {
                let babyName = change.profile?.name ?? "Unknown"
                diaperCounts[babyName, default: 0] += 1
            }
        }

        return DaySummary(
            id: day,
            date: day,
            events: eventsForDay,
            feedTotalsByBaby: feedTotals,
            diaperCountsByBaby: diaperCounts
        )
    }

    // Sort sections by day descending (newest first)
    return summaries.sorted(by: { $0.date > $1.date })
}

// Local helper to decode a UnitVolume from a symbol/name
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

import Foundation
import SwiftData

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
    targetUnit: UnitVolume = (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters,
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
        calendar.logicalStartOfDay(for: session.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
    }
    let groupedDiapers = Dictionary(grouping: diaperChanges) { change in
        calendar.logicalStartOfDay(for: change.timestamp, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
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
                if let amount = session.amount {
                    let converted = amount.converted(to: targetUnit)
                    if let existing = feedTotals[babyName] {
                        feedTotals[babyName] = Measurement(value: existing.value + converted.value, unit: targetUnit)
                    } else {
                        feedTotals[babyName] = Measurement(value: converted.value, unit: targetUnit)
                    }
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


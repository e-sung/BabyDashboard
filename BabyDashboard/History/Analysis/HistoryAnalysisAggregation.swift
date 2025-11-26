import Foundation
import CoreData
import Model

// MARK: - Chart Models

struct DailyFeedPoint: Identifiable, Hashable {
    let id = UUID()
    let day: Date
    let babyID: UUID
    let babyName: String
    let amountValue: Double
    let unit: UnitVolume

    var feedValue: Double { amountValue } // already in target unit at aggregation time
}

// Per-session (non-aggregated) chart model
struct FeedSessionPoint: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let babyID: UUID
    let babyName: String
    let amountValue: Double
    let unit: UnitVolume
    let objectID: NSManagedObjectID

    var feedValue: Double { amountValue }
}

// Keys for aggregation dictionaries
struct FeedKey: Hashable {
    let day: Date
    let babyID: UUID
    let babyName: String
}

func aggregateForChart(
    feeds: [FeedSession],
    unit: UnitVolume,
    calendar: Calendar,
    startOfDayHour: Int,
    startOfDayMinute: Int
) -> [DailyFeedPoint] {

    // Compute the current logical "today" and omit it from aggregation
    let logicalToday = calendar.logicalStartOfDay(for: Date(), startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)

    // Compute the earliest logical day present in the feeds and omit it as well, since users often start mid-day
    let initialLogicalDay = feeds.map { calendar.logicalStartOfDay(for: $0.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute) }.min()

    var feedTotals: [FeedKey: Double] = [:]
    for s in feeds {
        guard let baby = s.profile, let amount = s.amount else { continue }
        let babyID = baby.id
        let day = calendar.logicalStartOfDay(for: s.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)

        // Omit any feeds that fall on the current logical day or the initial logical day (when data likely started mid-day)
        if day == logicalToday { continue }
        if let firstDay = initialLogicalDay, day == firstDay { continue }

        let key = FeedKey(day: day, babyID: babyID, babyName: baby.name)
        let value = amount.converted(to: unit).value
        feedTotals[key, default: 0] += value
    }

    var feedPoints: [DailyFeedPoint] = feedTotals.map { (key, sum) in
        DailyFeedPoint(day: key.day, babyID: key.babyID, babyName: key.babyName, amountValue: sum, unit: unit)
    }
    feedPoints.sort { (a: DailyFeedPoint, b: DailyFeedPoint) in
        if a.day != b.day { return a.day < b.day }
        return a.babyName < b.babyName
    }

    return feedPoints
}

// Build one chart point per finished feed session (non-aggregated).
// By default we include today's logical day so the latest feeds appear in the per-feed trend.
func makePerSessionPoints(
    feeds: [FeedSession],
    unit: UnitVolume,
    calendar: Calendar,
    startOfDayHour: Int,
    startOfDayMinute: Int,
    omitLogicalToday: Bool = false
) -> [FeedSessionPoint] {

    let logicalToday = calendar.logicalStartOfDay(for: Date(), startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)

    var points: [FeedSessionPoint] = []
    points.reserveCapacity(feeds.count)

    for s in feeds {
        guard let baby = s.profile, let amount = s.amount else { continue }
        let babyID = baby.id
        let day = calendar.logicalStartOfDay(for: s.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
        if omitLogicalToday && day == logicalToday { continue }

        let converted = amount.converted(to: unit)
        points.append(
            FeedSessionPoint(
                timestamp: s.startTime,
                babyID: babyID,
                babyName: baby.name,
                amountValue: converted.value,
                unit: unit,
                objectID: s.objectID
            )
        )
    }

    points.sort { (a, b) in
        if a.timestamp != b.timestamp { return a.timestamp < b.timestamp }
        return a.babyName < b.babyName
    }

    return points
}


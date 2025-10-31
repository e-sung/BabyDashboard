
import Foundation
import SwiftData
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

    var feedTotals: [FeedKey: Double] = [:]
    for s in feeds {
        guard let baby = s.profile, let amount = s.amount else { continue }
        let day = calendar.logicalStartOfDay(for: s.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)

        // Omit any feeds that fall on the current logical day
        if day == logicalToday { continue }

        let key = FeedKey(day: day, babyID: baby.id, babyName: baby.name)
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

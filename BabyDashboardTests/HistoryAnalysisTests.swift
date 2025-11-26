//import Foundation
//import Testing
//@testable import BabyDashboard
//
//@Suite("History analysis for chart")
//struct HistoryAnalysisSpecs {
//
//    // MARK: - Test data builders
//
//    private func makeBabyProfile(named name: String) -> BabyProfile {
//        BabyProfile(id: UUID(), name: name)
//    }
//
//    private func makeUTCGregorianCalendar() -> Calendar {
//        var calendar = Calendar(identifier: .gregorian)
//        calendar.timeZone = TestTime.utcTimeZone
//        return calendar
//    }
//
//    // MARK: - Specifications
//
//    @Test("Aggregates per logical day (07:00 start) per baby; verifies ordering, totals, and logical day key")
//    func aggregatesPerLogicalDay_perBaby_withCustomStart_7amUTC() throws {
//        // Given: two babies and a fixed UTC calendar with a 07:00 logical start
//        let babyA = makeBabyProfile(named: "Baby A")
//        let babyB = makeBabyProfile(named: "Baby B")
//        let calendar = makeUTCGregorianCalendar()
//        let startOfDayHour = 7
//        let startOfDayMinute = 0
//
//        // Day 1 (logical day starting 2025-10-21 07:00:00)
//        let day1_b1_s1 = FeedSession(startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 7, minute: 0, second: 0))
//        day1_b1_s1.amount = Measurement(value: 100, unit: .milliliters)
//        day1_b1_s1.profile = babyA
//
//        let day1_b1_s2 = FeedSession(startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 15, minute: 0, second: 0))
//        day1_b1_s2.amount = Measurement(value: 50, unit: .milliliters)
//        day1_b1_s2.profile = babyA
//
//        let day1_b2_s1 = FeedSession(startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 8, minute: 0, second: 0))
//        day1_b2_s1.amount = Measurement(value: 120, unit: .milliliters)
//        day1_b2_s1.profile = babyB
//
//        // Day 0 (previous logical day: starts 2025-10-20 07:00:00)
//        let day0_b1_s1 = FeedSession(startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 6, minute: 59, second: 59))
//        day0_b1_s1.amount = Measurement(value: 80, unit: .milliliters)
//        day0_b1_s1.profile = babyA
//
//        let allFeeds = [day1_b1_s1, day1_b1_s2, day1_b2_s1, day0_b1_s1]
//
//        // When: aggregating for chart in milliliters with 07:00 logical start
//        let result = aggregateForChart(
//            feeds: allFeeds,
//            unit: .milliliters,
//            calendar: calendar,
//            startOfDayHour: startOfDayHour,
//            startOfDayMinute: startOfDayMinute
//        )
//
//        // Then: we expect three rows — (Day0, Baby A), (Day1, Baby A), (Day1, Baby B)
//        #expect(result.count == 3)
//
//        // And: verify ordering (sorted by day ascending, then baby name)
//        let expectedDay0 = calendar.logicalStartOfDay(for: day0_b1_s1.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
//        let expectedDay1 = calendar.logicalStartOfDay(for: day1_b1_s1.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
//
//        let row0 = result[0]
//        #expect(row0.day == expectedDay0, "Row 0 should be Day 0 logical start")
//        #expect(row0.babyName == "Baby A")
//        #expect(row0.amountValue == 80)
//
//        let row1 = result[1]
//        #expect(row1.day == expectedDay1, "Row 1 should be Day 1 logical start")
//        #expect(row1.babyName == "Baby A")
//        #expect(row1.amountValue == 150)
//
//        let row2 = result[2]
//        #expect(row2.day == expectedDay1, "Row 2 should be Day 1 logical start")
//        #expect(row2.babyName == "Baby B")
//        #expect(row2.amountValue == 120)
//    }
//
//    @Test("Groups events before and after midnight into the same logical day when day starts at 07:00 UTC; verifies logical day key")
//    func groupsAcrossMidnightWithinSameLogicalDay_7amUTC() throws {
//        // Scenario: With a 07:00 logical start, events at 23:30 and 01:00 fall into the same logical day.
//        // Given: a baby, a UTC calendar, and a 07:00 logical day start
//        let babyA = makeBabyProfile(named: "Baby A")
//        let calendar = makeUTCGregorianCalendar()
//        let startOfDayHour = 7
//        let startOfDayMinute = 0
//
//        // Two feeds on the same logical day (starting 2025-10-21 07:00:00), one before and one after midnight:
//        let feed_oct21_2330 = FeedSession(startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 23, minute: 30, second: 0))
//        feed_oct21_2330.amount = Measurement(value: 60, unit: .milliliters)
//        feed_oct21_2330.profile = babyA
//
//        let feed_oct22_0100 = FeedSession(startTime: calendar.dateUTC(year: 2025, month: 10, day: 22, hour: 1, minute: 0, second: 0))
//        feed_oct22_0100.amount = Measurement(value: 40, unit: .milliliters)
//        feed_oct22_0100.profile = babyA
//
//        // Control: a feed exactly at the next logical day start (2025-10-22 07:00:00)
//        let feed_nextDayStart_oct22_0700 = FeedSession(startTime: calendar.dateUTC(year: 2025, month: 10, day: 22, hour: 7, minute: 0, second: 0))
//        feed_nextDayStart_oct22_0700.amount = Measurement(value: 10, unit: .milliliters)
//        feed_nextDayStart_oct22_0700.profile = babyA
//
//        let feeds = [feed_oct21_2330, feed_oct22_0100, feed_nextDayStart_oct22_0700]
//
//        // When: aggregating with the 07:00 logical start
//        let result = aggregateForChart(
//            feeds: feeds,
//            unit: .milliliters,
//            calendar: calendar,
//            startOfDayHour: startOfDayHour,
//            startOfDayMinute: startOfDayMinute
//        )
//
//        // Then: exactly two logical-day buckets for the single baby
//        let babyRows = result.filter { $0.babyName == "Baby A" }
//        #expect(babyRows.count == 2, "Expected two logical day buckets for Baby A")
//
//        // And: verify the logical day keys and totals
//        let expectedDay_2025_10_21 = calendar.logicalStartOfDay(for: feed_oct21_2330.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
//        let expectedDay_2025_10_22 = calendar.logicalStartOfDay(for: feed_nextDayStart_oct22_0700.startTime, startOfDayHour: startOfDayHour, startOfDayMinute: startOfDayMinute)
//
//        // Sort by day to make deterministic assertions
//        let sorted = babyRows.sorted { $0.day < $1.day }
//        let firstBucket = sorted[0]
//        let secondBucket = sorted[1]
//
//        #expect(firstBucket.day == expectedDay_2025_10_21, "First bucket should be the logical day starting 2025-10-21 07:00")
//        #expect(firstBucket.amountValue == 100, "Expected 60 + 40 combined across midnight")
//
//        #expect(secondBucket.day == expectedDay_2025_10_22, "Second bucket should be the logical day starting 2025-10-22 07:00")
//        #expect(secondBucket.amountValue == 10, "Expected only the 07:00 event in the next logical day")
//    }
//}

//import Foundation
//import Testing
//import Model
//@testable import BabyDashboard
//
//@Suite("History aggregation")
//struct HistoryAggregationTests {
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
//    @Test("Aggregates by logical day, newest day first; sums feed totals and counts diapers per baby")
//    func aggregatesByDay_sortsNewestFirst_sumsFeeds_countsDiapers() throws {
//        // Scenario: Daily summaries are computed per baby, sorted by newest day first.
//        // Given: two babies and a fixed UTC calendar for deterministic dates
//        let babyA = makeBabyProfile(named: "A")
//        let babyB = makeBabyProfile(named: "B")
//        let calendar = makeUTCGregorianCalendar()
//
//        // And: two logical days (Feb 10 and Feb 11, 2025, UTC)
//        let feb10_0800 = calendar.dateUTC(year: 2025, month: 2, day: 10, hour: 8, minute: 0)
//        let feb11_0900 = calendar.dateUTC(year: 2025, month: 2, day: 11, hour: 9, minute: 0)
//
//        // And: feed sessions across both days (mixing units to exercise conversion to mL)
//        let feedA_feb10_0800 = FeedSession(startTime: feb10_0800)
//        feedA_feb10_0800.endTime = feb10_0800.addingTimeInterval(15 * 60)
//        feedA_feb10_0800.amount = Measurement(value: 120, unit: .milliliters)
//        feedA_feb10_0800.profile = babyA
//
//        let feedB_feb10_0830 = FeedSession(startTime: feb10_0800.addingTimeInterval(30 * 60))
//        feedB_feb10_0830.endTime = feedB_feb10_0830.startTime.addingTimeInterval(10 * 60)
//        feedB_feb10_0830.amount = Measurement(value: 4, unit: .fluidOunces) // ≈118.29 mL
//        feedB_feb10_0830.profile = babyB
//
//        let feedA_feb11_0900 = FeedSession(startTime: feb11_0900)
//        feedA_feb11_0900.endTime = feedA_feb11_0900.startTime.addingTimeInterval(20 * 60)
//        feedA_feb11_0900.amount = Measurement(value: 2, unit: .fluidOunces) // ≈59.15 mL
//        feedA_feb11_0900.profile = babyA
//
//        // And: diaper changes across both days
//        let diaperA_feb10_0840 = DiaperChange(timestamp: feb10_0800.addingTimeInterval(40 * 60), type: .pee)
//        diaperA_feb10_0840.profile = babyA
//
//        let diaperB_feb10_0850 = DiaperChange(timestamp: feb10_0800.addingTimeInterval(50 * 60), type: .poo)
//        diaperB_feb10_0850.profile = babyB
//
//        let diaperA_feb11_0930 = DiaperChange(timestamp: feb11_0900.addingTimeInterval(30 * 60), type: .pee)
//        diaperA_feb11_0930.profile = babyA
//
//        // And: the unified history events (used to populate rows per day)
//        let historyEvents = [
//            HistoryEvent(from: feedA_feb10_0800),
//            HistoryEvent(from: feedB_feb10_0830),
//            HistoryEvent(from: feedA_feb11_0900),
//            HistoryEvent(from: diaperA_feb10_0840),
//            HistoryEvent(from: diaperB_feb10_0850),
//            HistoryEvent(from: diaperA_feb11_0930),
//        ]
//
//        // When: we summarize by day using milliliters as the target unit
//        let dailySummaries = makeDaySummaries(
//            events: historyEvents,
//            feedSessions: [feedA_feb10_0800, feedB_feb10_0830, feedA_feb11_0900],
//            diaperChanges: [diaperA_feb10_0840, diaperB_feb10_0850, diaperA_feb11_0930],
//            targetUnit: .milliliters,
//            calendar: calendar,
//            startOfDayHour: 0,
//            startOfDayMinute: 0
//        )
//
//        // Then: two days are present, ordered newest-first (Feb 11 then Feb 10)
//        let feb11Start = calendar.startOfDay(for: feb11_0900)
//        let feb10Start = calendar.startOfDay(for: feb10_0800)
//
//        #expect(dailySummaries.count == 2, "Expected exactly two day summaries")
//        #expect(dailySummaries[0].date == feb11Start, "Newest day (Feb 11) should be first")
//        #expect(dailySummaries[1].date == feb10Start, "Older day (Feb 10) should be second")
//
//        // And: Feb 11 totals — baby A has ~59.15 mL feed and 1 diaper
//        let feb11Summary = dailySummaries[0]
//        let babyA_Feb11_mL = feb11Summary.feedTotalsByBaby["A"]?.converted(to: .milliliters).value ?? -1
//        #expect(abs(babyA_Feb11_mL - 59.15) < 0.5, "Expected ~59 mL for baby A on Feb 11")
//        #expect(feb11Summary.diaperCountsByBaby["A"] == 1, "Expected 1 diaper for baby A on Feb 11")
//
//        // And: Feb 10 totals — baby A ~120 mL; baby B ~118.3 mL; 1 diaper each
//        let feb10Summary = dailySummaries[1]
//        let babyA_Feb10_mL = feb10Summary.feedTotalsByBaby["A"]?.converted(to: .milliliters).value ?? -1
//        let babyB_Feb10_mL = feb10Summary.feedTotalsByBaby["B"]?.converted(to: .milliliters).value ?? -1
//
//        #expect(abs(babyA_Feb10_mL - 120.0) < 0.1, "Expected ~120 mL for baby A on Feb 10")
//        #expect(abs(babyB_Feb10_mL - 118.3) < 1.0, "Expected ~118.3 mL for baby B on Feb 10")
//        #expect(feb10Summary.diaperCountsByBaby["A"] == 1, "Expected 1 diaper for baby A on Feb 10")
//        #expect(feb10Summary.diaperCountsByBaby["B"] == 1, "Expected 1 diaper for baby B on Feb 10")
//
//        // And: within each day, events are ordered from most recent to oldest
//        #expect(feb10Summary.events == feb10Summary.events.sorted(by: { $0.date > $1.date }), "Feb 10 events should be newest-first")
//        #expect(feb11Summary.events == feb11Summary.events.sorted(by: { $0.date > $1.date }), "Feb 11 events should be newest-first")
//    }
//
//    @Test("Groups events by a custom logical start of day (07:00 UTC)")
//    func groupsByCustomStartOfDay_7amUTC() throws {
//        // Scenario: Events are assigned to a logical day that starts at 07:00 UTC.
//        // Given: a baby, a UTC calendar, and a non-midnight logical day start (07:00)
//        let babyA = makeBabyProfile(named: "A")
//        let calendar = makeUTCGregorianCalendar()
//        let startOfDayHour = 7
//        let startOfDayMinute = 0
//
//        // And: one event exactly at the logical day start -> belongs to Day 1
//        // Logical Day 1 starts at 2025-10-21 07:00:00 UTC
//        let feed_atDay1Start_0700 = FeedSession(
//            startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 7, minute: 0, second: 0)
//        )
//        feed_atDay1Start_0700.amount = Measurement(value: 100, unit: .milliliters)
//        feed_atDay1Start_0700.profile = babyA
//
//        // And: one event one second before the logical day start -> belongs to previous logical day (Day 0)
//        // Logical Day 0 starts at 2025-10-20 07:00:00 UTC
//        let feed_justBeforeDay1Start_065959 = FeedSession(
//            startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 6, minute: 59, second: 59)
//        )
//        feed_justBeforeDay1Start_065959.amount = Measurement(value: 50, unit: .milliliters)
//        feed_justBeforeDay1Start_065959.profile = babyA
//
//        let historyEvents = [
//            HistoryEvent(from: feed_atDay1Start_0700),
//            HistoryEvent(from: feed_justBeforeDay1Start_065959)
//        ]
//        let feedSessions = [feed_atDay1Start_0700, feed_justBeforeDay1Start_065959]
//
//        // When: we summarize days using the custom logical start
//        let dailySummaries = makeDaySummaries(
//            events: historyEvents,
//            feedSessions: feedSessions,
//            diaperChanges: [],
//            targetUnit: .milliliters,
//            calendar: calendar,
//            startOfDayHour: startOfDayHour,
//            startOfDayMinute: startOfDayMinute
//        )
//
//        // Then: we get two distinct logical days
//        #expect(dailySummaries.count == 2, "Expected two logical day summaries with a 07:00 start")
//
//        let day1Start = calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 7, minute: 0, second: 0)
//        let day0Start = calendar.dateUTC(year: 2025, month: 10, day: 20, hour: 7, minute: 0, second: 0)
//
//        let day1Summary = dailySummaries.first { $0.date == day1Start }
//        let day0Summary = dailySummaries.first { $0.date == day0Start }
//
//        #expect(day1Summary != nil, "Expected a summary for Day 1 (starting 2025-10-21 07:00 UTC)")
//        #expect(day0Summary != nil, "Expected a summary for Day 0 (starting 2025-10-20 07:00 UTC)")
//
//        // And: each day contains exactly the event that belongs to it, with correct feed totals
//        #expect(day1Summary?.events.count == 1, "Day 1 should contain only the 07:00 event")
//        #expect(day1Summary?.feedTotalsByBaby["A"]?.value == 100, "Day 1 should total 100 mL for baby A")
//
//        #expect(day0Summary?.events.count == 1, "Day 0 should contain only the 06:59:59 event")
//        #expect(day0Summary?.feedTotalsByBaby["A"]?.value == 50, "Day 0 should total 50 mL for baby A")
//    }
//
//    @Test("Keeps events before and after midnight in the same logical day when day starts at 07:00 UTC")
//    func groupsAcrossMidnightWithinSameLogicalDay_7amUTC() throws {
//        // Scenario: With a 07:00 logical start, events at 23:30 and 01:00 belong to the same logical day.
//        // Given: a baby, a UTC calendar, and a 07:00 logical day start
//        let babyA = makeBabyProfile(named: "A")
//        let calendar = makeUTCGregorianCalendar()
//        let startOfDayHour = 7
//        let startOfDayMinute = 0
//
//        // Logical day starting 2025-10-21 07:00:00 UTC spans until 2025-10-22 06:59:59 UTC.
//        // And: one event late at night (23:30 on Oct 21)
//        let feed_oct21_2330 = FeedSession(
//            startTime: calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 23, minute: 30, second: 0)
//        )
//        feed_oct21_2330.amount = Measurement(value: 60, unit: .milliliters)
//        feed_oct21_2330.profile = babyA
//
//        // And: another event after midnight (01:00 on Oct 22) — still part of the same logical day
//        let feed_oct22_0100 = FeedSession(
//            startTime: calendar.dateUTC(year: 2025, month: 10, day: 22, hour: 1, minute: 0, second: 0)
//        )
//        feed_oct22_0100.amount = Measurement(value: 40, unit: .milliliters)
//        feed_oct22_0100.profile = babyA
//
//        // And: a control event exactly at next logical day start (07:00 on Oct 22) — belongs to next day
//        let feed_nextDayStart_oct22_0700 = FeedSession(
//            startTime: calendar.dateUTC(year: 2025, month: 10, day: 22, hour: 7, minute: 0, second: 0)
//        )
//        feed_nextDayStart_oct22_0700.amount = Measurement(value: 10, unit: .milliliters)
//        feed_nextDayStart_oct22_0700.profile = babyA
//
//        let historyEvents = [
//            HistoryEvent(from: feed_oct21_2330),
//            HistoryEvent(from: feed_oct22_0100),
//            HistoryEvent(from: feed_nextDayStart_oct22_0700)
//        ]
//        let feedSessions = [feed_oct21_2330, feed_oct22_0100, feed_nextDayStart_oct22_0700]
//
//        // When: we summarize by day with the 07:00 logical start
//        let dailySummaries = makeDaySummaries(
//            events: historyEvents,
//            feedSessions: feedSessions,
//            diaperChanges: [],
//            targetUnit: .milliliters,
//            calendar: calendar,
//            startOfDayHour: startOfDayHour,
//            startOfDayMinute: startOfDayMinute
//        )
//
//        // Then: we get two logical days
//        #expect(dailySummaries.count == 2, "Expected two logical day summaries: 2025-10-21 07:00 and 2025-10-22 07:00")
//
//        let dayStart_2025_10_21_0700 = calendar.dateUTC(year: 2025, month: 10, day: 21, hour: 7, minute: 0, second: 0)
//        let dayStart_2025_10_22_0700 = calendar.dateUTC(year: 2025, month: 10, day: 22, hour: 7, minute: 0, second: 0)
//
//        let oct21LogicalDay = dailySummaries.first { $0.date == dayStart_2025_10_21_0700 }
//        let oct22LogicalDay = dailySummaries.first { $0.date == dayStart_2025_10_22_0700 }
//
//        #expect(oct21LogicalDay != nil, "Expected a summary for the logical day starting 2025-10-21 07:00 UTC")
//        #expect(oct22LogicalDay != nil, "Expected a summary for the logical day starting 2025-10-22 07:00 UTC")
//
//        // And: the Oct 21 logical day contains both pre- and post-midnight events (23:30 and 01:00)
//        #expect(oct21LogicalDay?.events.count == 2, "Oct 21 logical day should contain the 23:30 and 01:00 events")
//        #expect(oct21LogicalDay?.feedTotalsByBaby["A"]?.value == 100, "Oct 21 logical day should total 100 mL for baby A")
//
//        // And: the Oct 22 logical day contains only the 07:00 event
//        #expect(oct22LogicalDay?.events.count == 1, "Oct 22 logical day should contain only the 07:00 event")
//        #expect(oct22LogicalDay?.feedTotalsByBaby["A"]?.value == 10, "Oct 22 logical day should total 10 mL for baby A")
//    }
//}

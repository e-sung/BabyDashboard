import Foundation

// Canonical UTC TimeZone/Calendar for deterministic tests
enum TestTime {
    static let utcTimeZone = TimeZone(identifier: "UTC")!

    static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utcTimeZone
        return cal
    }
}

extension Calendar {
    /// Creates a Date from explicit components in this calendar's time zone.
    /// Force-unwrap is acceptable in tests; a bad date should fail loudly.
    func dateUTC(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var comps = DateComponents()
        comps.calendar = self
        comps.timeZone = self.timeZone
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = second
        return self.date(from: comps)!
    }
}


import Foundation

extension Calendar {
    func logicalStartOfDay(for date: Date, startOfDayHour: Int, startOfDayMinute: Int) -> Date {
        let calendarDayStart = self.startOfDay(for: date)
        
        var components = self.dateComponents([.year, .month, .day], from: calendarDayStart)
        components.hour = startOfDayHour
        components.minute = startOfDayMinute
        
        guard let logicalStartForToday = self.date(from: components) else {
            // Fallback to midnight if date creation fails
            return calendarDayStart
        }
        
        if date < logicalStartForToday {
            // The event occurred before this calendar day's logical start, so it belongs to the *previous* logical day.
            return self.date(byAdding: .day, value: -1, to: logicalStartForToday)!
        } else {
            // The event occurred on or after the logical start, so it belongs to *this* logical day.
            return logicalStartForToday
        }
    }
}

//
//  Utils.swift
//  BabyDashboardTests
//
//  Created by 류성두 on 11/27/25.
//

import Foundation

var defaultDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = defaultTimezone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

var defaultNow: Date = {
    return defaultDateFormatter.date(from: "2025-01-01 00:00:00")!
}()

var defaultTimezone: TimeZone = {
    let timeZone = TimeZone(secondsFromGMT: 3600 * 9)!
    return timeZone
}()

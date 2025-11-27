//
//  Date+Extension.swift
//  Model
//
//  Created by 류성두 on 11/26/25.
//

import Foundation


public extension Date {
    static var current: Date {
        // For injecting time from UI Test
        if let timeStr = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-FixedTime:") })?.components(separatedBy: ":").last,
           let timeInterval = TimeInterval(timeStr) {
            return Date(timeIntervalSince1970: timeInterval)
        }
        // For injecting time from Unit Test
        if let fixedDate {
            return fixedDate
        }
        return Date()
    }
    #if DEBUG
    static var fixedDate: Date?
    #endif
}

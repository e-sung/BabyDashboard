//
//  Date+Extension.swift
//  Model
//
//  Created by 류성두 on 11/26/25.
//

import Foundation


public extension Date {
    static var current: Date {
        if let timeStr = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-FixedTime:") })?.components(separatedBy: ":").last,
           let timeInterval = TimeInterval(timeStr) {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return Date()
    }
}

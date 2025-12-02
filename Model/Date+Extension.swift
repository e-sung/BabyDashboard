//
//  Date+Extension.swift
//  Model
//
//  Created by 류성두 on 11/26/25.
//

import Foundation


public extension Date {
    private static var fixedBaseline: (start: TimeInterval, uptime: TimeInterval)? = {
        guard let timeStr = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-BaseTime:") })?.components(separatedBy: ":").last,
              let timeInterval = TimeInterval(timeStr) else {
            return nil
        }
        return (start: timeInterval, uptime: ProcessInfo.processInfo.systemUptime)
    }()

    /// Returns a deterministic current date. If `-BaseTime:` is supplied, time starts at that
    /// point but continues to advance using monotonic uptime; otherwise it mirrors `Date()`.
    static var current: Date {
        if let baseline = fixedBaseline {
            let elapsed = ProcessInfo.processInfo.systemUptime - baseline.uptime
            return Date(timeIntervalSince1970: baseline.start + elapsed)
        }
        return Date()
    }
}

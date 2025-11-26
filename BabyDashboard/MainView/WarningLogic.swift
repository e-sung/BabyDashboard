import Foundation

/// Pure, stateless warning logic helpers.
/// Keep thresholds outside so they can be user-configured by callers.
enum WarningLogic {

    /// Returns true when the time since startOfLastFeed is at or beyond threshold.
    /// Suppresses the warning while a feed is in progress or if startOfLastFeed is nil.
    static func shouldWarnFeed(now: Date, startOfLastFeed: Date?, inProgress: Bool, threshold: TimeInterval) -> Bool {
        guard !inProgress, let startOfLastFeed else { return false }
        return now.timeIntervalSince(startOfLastFeed) >= threshold
    }

    /// Returns true when the time since lastDiaperTime is at or beyond threshold.
    /// Returns false if lastDiaperTime is nil.
    static func shouldWarnDiaper(now: Date, lastDiaperTime: Date?, threshold: TimeInterval) -> Bool {
        guard let lastDiaperTime else { return false }
        return now.timeIntervalSince(lastDiaperTime) >= threshold
    }
}

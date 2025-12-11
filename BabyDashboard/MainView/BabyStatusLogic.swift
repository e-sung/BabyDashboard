import Foundation
import Model

/// Snapshot of feed session data for display logic.
/// Using snapshots decouples display logic from Core Data.
struct FeedSessionSnapshot {
    let startTime: Date
    let endTime: Date?
    let amount: Measurement<UnitVolume>?
    let feedType: FeedType?
    let isInProgress: Bool
    
    init(startTime: Date, endTime: Date?, amount: Measurement<UnitVolume>?, feedType: FeedType?, isInProgress: Bool) {
        self.startTime = startTime
        self.endTime = endTime
        self.amount = amount
        self.feedType = feedType
        self.isInProgress = isInProgress
    }
    
    init?(from session: FeedSession?) {
        guard let session else { return nil }
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.amount = session.amount
        self.feedType = session.feedType
        self.isInProgress = session.isInProgress
    }
}

/// Snapshot of diaper change data for display logic.
struct DiaperChangeSnapshot {
    let timestamp: Date
    let type: DiaperType
    
    init(timestamp: Date, type: DiaperType) {
        self.timestamp = timestamp
        self.type = type
    }
    
    init?(from diaper: DiaperChange?) {
        guard let diaper else { return nil }
        self.timestamp = diaper.timestamp
        self.type = diaper.diaperType
    }
}

/// Pure business logic for baby status display.
/// Extracted from BabyStatusView for testability.
struct BabyStatusLogic {
    let lastFeedSession: FeedSessionSnapshot?
    let inProgressFeedSession: FeedSessionSnapshot?
    let lastDiaperChange: DiaperChangeSnapshot?
    let feedTerm: TimeInterval
    let diaperWarningThreshold: TimeInterval
    let isLargeDynamicType: Bool
    let preferredVolumeUnit: UnitVolume
    
    init(
        lastFeedSession: FeedSessionSnapshot?,
        inProgressFeedSession: FeedSessionSnapshot?,
        lastDiaperChange: DiaperChangeSnapshot?,
        feedTerm: TimeInterval,
        diaperWarningThreshold: TimeInterval = 60 * 60, // 1 hour default
        isLargeDynamicType: Bool = false,
        preferredVolumeUnit: UnitVolume = .milliliters
    ) {
        self.lastFeedSession = lastFeedSession
        self.inProgressFeedSession = inProgressFeedSession
        self.lastDiaperChange = lastDiaperChange
        self.feedTerm = feedTerm
        self.diaperWarningThreshold = diaperWarningThreshold
        self.isLargeDynamicType = isLargeDynamicType
        self.preferredVolumeUnit = preferredVolumeUnit
    }
    
    /// Convenience initializer for use with BabyProfile from views
    init(
        baby: BabyProfile,
        settings: AppSettings,
        diaperWarningThreshold: TimeInterval = 60 * 60,
        preferredVolumeUnit: UnitVolume = UnitUtils.preferredUnit
    ) {
        self.lastFeedSession = FeedSessionSnapshot(from: baby.lastFinishedFeedSession)
        self.inProgressFeedSession = FeedSessionSnapshot(from: baby.inProgressFeedSession)
        self.lastDiaperChange = DiaperChangeSnapshot(from: baby.lastDiaperChange)
        self.feedTerm = baby.feedTerm
        self.diaperWarningThreshold = diaperWarningThreshold
        
        // Compute isLargeDynamicType from settings
        if let size = settings.preferredFontScale.dynamicTypeSize {
            self.isLargeDynamicType = size > .accessibility3
        } else {
            self.isLargeDynamicType = false
        }
        
        self.preferredVolumeUnit = preferredVolumeUnit
    }
    
    // MARK: - Feed Display Logic
    
    /// Main text for feed card (e.g., "2h 30m ago" or "1m 30s" during feeding)
    func feedMainText(now: Date) -> String {
        if let inProgress = inProgressFeedSession {
            let interval = now.timeIntervalSince(inProgress.startTime)
            return formattedElapsedIncludingSeconds(from: interval)
        }
        
        guard let session = lastFeedSession else { return "--" }
        let interval = now.timeIntervalSince(session.startTime)
        return formatElapsedTime(from: interval)
    }
    
    /// Progress value (0.0 to 1.0+) for feed progress bar
    func feedProgress(now: Date) -> Double {
        let startTime: Date
        if let inProgress = inProgressFeedSession {
            startTime = inProgress.startTime
        } else if let session = lastFeedSession {
            startTime = session.startTime
        } else {
            return 0
        }
        
        let interval = now.timeIntervalSince(startTime)
        return interval / feedTerm
    }
    
    /// Secondary progress (feeding duration overlay)
    func feedSecondaryProgress(now: Date) -> Double? {
        if let inProgress = inProgressFeedSession {
            let interval = now.timeIntervalSince(inProgress.startTime)
            return min(interval / feedTerm, 1.0)
        }
        
        guard let session = lastFeedSession, let endTime = session.endTime else { return nil }
        let duration = endTime.timeIntervalSince(session.startTime)
        return min(duration / feedTerm, 1.0)
    }
    
    /// Footer text (e.g., "in 15m • 90 ml") - emoji is returned separately via feedFooterIcon
    func feedFooterText(now: Date) -> String {
        if inProgressFeedSession != nil {
            return ""
        }
        
        guard let session = lastFeedSession else { return "No data" }
        guard let endTime = session.endTime else { return "No data" }
        
        let duration = endTime.timeIntervalSince(session.startTime)
        var text = formattedDuration(from: duration)
        
        if let amount = session.amount {
            let converted = amount.converted(to: preferredVolumeUnit)
            text += " • \(UnitUtils.format(measurement: converted))".lowercased()
        }
        return text
    }
    
    /// Returns the feed type emoji for the footer, or nil if not applicable
    var feedFooterIcon: String? {
        guard inProgressFeedSession == nil else { return nil }
        guard let session = lastFeedSession else { return nil }
        return session.feedType?.emoji ?? FeedType.babyFormula.emoji
    }
    
    // MARK: - Diaper Display Logic
    
    /// Time since last diaper change (e.g., "30m ago")
    func diaperTimeAgo(now: Date) -> String {
        guard let diaper = lastDiaperChange else { return "--" }
        let interval = now.timeIntervalSince(diaper.timestamp)
        return formatElapsedTime(from: interval)
    }
    
    /// Progress value (0.0 to 1.0) for diaper progress bar
    func diaperProgress(now: Date) -> Double {
        guard let diaper = lastDiaperChange else { return 0 }
        let interval = now.timeIntervalSince(diaper.timestamp)
        return min(interval / diaperWarningThreshold, 1.0)
    }
    
    /// Footer text for diaper card
    func diaperFooterText() -> String {
        guard let diaper = lastDiaperChange else { return "No data" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: diaper.timestamp)
    }
    
    // MARK: - Private Helpers
    
    private func makeComponentsFormatter(allowedUnits: NSCalendar.Unit) -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = allowedUnits
        formatter.unitsStyle = .abbreviated
        if isLargeDynamicType {
            var enCalendar = Calendar(identifier: .gregorian)
            enCalendar.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = enCalendar
        }
        formatter.zeroFormattingBehavior = [.dropAll]
        return formatter
    }
    
    private func formattedDuration(from interval: TimeInterval) -> String {
        let formatter = makeComponentsFormatter(allowedUnits: [.hour, .minute])
        guard let formatted = formatter.string(from: interval) else { return "" }
        return String(localized: "in \(formatted)")
    }
    
    private func formatElapsedTime(from interval: TimeInterval) -> String {
        if interval < 60 { return String(localized: "Just now") }
        let formatter = makeComponentsFormatter(allowedUnits: [.hour, .minute])
        if let formatted = formatter.string(from: interval) {
            if isLargeDynamicType {
                return formatted
            }
            return String(localized: "\(formatted) ago")
        }
        return String(localized: "Just now")
    }
    
    private func formattedElapsedIncludingSeconds(from interval: TimeInterval) -> String {
        let units: NSCalendar.Unit = interval < 60 ? [.second] : [.hour, .minute, .second]
        let formatter = makeComponentsFormatter(allowedUnits: units)
        if let formatted = formatter.string(from: interval) {
            return formatted
        }
        return "0s"
    }
}

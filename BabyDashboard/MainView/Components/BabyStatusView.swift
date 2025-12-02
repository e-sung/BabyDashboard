import SwiftUI
import CoreData
import Model

struct BabyStatusView2: View {
    @ObservedObject var baby: BabyProfile
    
    // Animation States
    var isFeedAnimating: Bool = false
    var isDiaperAnimating: Bool = false
    
    // Actions
    let onFeedTap: () -> Void
    let onFeedLongPress: () -> Void
    let onDiaperTap: () -> Void
    let onNameTap: () -> Void
    let onLastFeedTap: ((FeedSession) -> Void)?
    let onLastDiaperTap: ((DiaperChange) -> Void)?
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private let diaperWarningThreshold: TimeInterval = 60 * 60 * 1 // 1 hours default
    
    private var isIPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = Date.current
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Button {
                    onNameTap()
                } label: {
                    Text(baby.name)
                        .font(.system(size: isIPad ? 50 : 34, weight: .bold))
                        .padding(.horizontal)
                }
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)


                VStack(spacing: 16) {
                    // Feed Card
                    StatusCard(
                        icon: .image("bottle"),
                        title: baby.inProgressFeedSession != nil ? String(localized: "Feeding") : String(localized: "Last Feed"),
                        mainText: feedMainText(now: now),
                        progressBarColor: .green,
                        progress: feedProgress(now: now),
                        secondaryProgress: feedSecondaryProgress(now: now),
                        secondaryProgressColor: .blue,
                        footerText: feedFooterText(now: now),
                        criteriaLabel: feedCriteriaLabel,
                        isAnimating: isFeedAnimating,
                        shouldWarn: shouldWarnFeed,
                        mainTextColor: baby.inProgressFeedSession != nil ? .blue : nil,
                        accessibilityCriteriaLabel: feedAccessibilityCriteriaLabel,
                        accessibilityHintText: "Double tap to start or stop feeding",
                        onTap: onFeedTap,
                        onFooterTap: {
                            if baby.inProgressFeedSession != nil {
                                return
                            }
                            if let session = baby.lastFinishedFeedSession {
                                onLastFeedTap?(session)
                            }
                        }
                    )
                    .onLongPressGesture(perform: onFeedLongPress)
                    
                    // Diaper Card
                    StatusCard(
                        icon: .image("diaper"),
                        title: String(localized:"Diaper"),
                        mainText: diaperTimeAgo(now: now),
                        progressBarColor: Color("diaperProgressColor"),
                        progress: diaperProgress(now: now),
                        footerText: diaperFooterText,
                        criteriaLabel: "1h",
                        isAnimating: isDiaperAnimating,
                        shouldWarn: shouldWarnDiaper,
                        warningColor: Color("diaperProgressColor"),
                        accessibilityCriteriaLabel: "1 hour",
                        accessibilityHintText: "Double tap to log a diaper change",

                        onTap: onDiaperTap,
                        onFooterTap: {
                            if let diaper = baby.lastDiaperChange {
                                onLastDiaperTap?(diaper)
                            }
                        }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
            .background(Color(uiColor: .systemGroupedBackground)) // Light gray background
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Computed Properties

    private var shouldWarnFeed: Bool {
        WarningLogic.shouldWarnFeed(
            now: Date.current,
            startOfLastFeed: baby.lastFinishedFeedSession?.startTime,
            inProgress: baby.inProgressFeedSession != nil,
            threshold: baby.feedTerm
        )
    }

    private var shouldWarnDiaper: Bool {
        WarningLogic.shouldWarnDiaper(
            now: Date.current,
            lastDiaperTime: baby.lastDiaperChange?.timestamp,
            threshold: diaperWarningThreshold
        )
    }
    
    private func feedMainText(now: Date) -> String {
        if baby.inProgressFeedSession != nil {
            let interval = now.timeIntervalSince(baby.inProgressFeedSession?.startTime ?? now)
            return formattedElapsedIncludingSeconds(from: interval)
        }
        
        guard let session = baby.lastFinishedFeedSession else { return "--" }
        let interval = now.timeIntervalSince(session.startTime)
        return formatElapsedTime(from: interval)
    }
    
    private func feedProgress(now: Date) -> Double {
        let startTime: Date
        if let current = baby.inProgressFeedSession {
            startTime = current.startTime
        } else if let finished = baby.lastFinishedFeedSession {
            startTime = finished.startTime
        } else {
            return 0
        }
        
        let interval = now.timeIntervalSince(startTime)
        let term = baby.feedTerm
        return interval / term
    }
    
    private func feedSecondaryProgress(now: Date) -> Double? {
        if let current = baby.inProgressFeedSession {
            let interval = now.timeIntervalSince(current.startTime)
            let term = baby.feedTerm
            return min(interval / term, 1.0)
        }
        
        guard let session = baby.lastFinishedFeedSession, let endTime = session.endTime else { return nil }
        let duration = endTime.timeIntervalSince(session.startTime)
        let term = baby.feedTerm
        return min(duration / term, 1.0)
    }
    
    private func feedFooterText(now: Date) -> String {
        if baby.inProgressFeedSession != nil {
            return ""
        }

        guard let session = baby.lastFinishedFeedSession else { return "No data" }
        guard let endTime = session.endTime else { return "No Data" }
        let duration = endTime.timeIntervalSince(session.startTime)
        var text = formattedDuration(from: duration)
        if let amount = session.amount {
            text += " • \(amount.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))))".lowercased()
        }
        return text
    }
    
    private var feedCriteriaLabel: String {
        let term = baby.feedTerm
        let hours = Int(term / 3600)
        return "\(hours)h"
    }
    
    private var feedAccessibilityCriteriaLabel: String {
        let term = baby.feedTerm
        let hours = Int(term / 3600)
        return "\(hours) hours"
    }
    
    private func diaperTimeAgo(now: Date) -> String {
        guard let diaper = baby.lastDiaperChange else { return "--" }
        let interval = now.timeIntervalSince(diaper.timestamp)
        return formatElapsedTime(from: interval)
    }
    
    private func diaperProgress(now: Date) -> Double {
        guard let diaper = baby.lastDiaperChange else { return 0 }
        let interval = now.timeIntervalSince(diaper.timestamp)
        return min(interval / diaperWarningThreshold, 1.0)
    }
    
    private var diaperFooterText: String {
        guard let diaper = baby.lastDiaperChange else { return "No data" }
        return "\(timeFormatter.string(from: diaper.timestamp))"
    }
    
    private var diaperCriteriaLabel: String {
        let hours = Int(diaperWarningThreshold / 3600)
        return "\(hours)h"
    }
    
    // MARK: - Helpers
    
    private func formattedDuration(from interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropAll]
        guard let formatted = formatter.string(from: interval) else { return "" }
        return "\(formatted)간"
    }
    
    private func formattedElapsingTime(from interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropAll]
        guard let formatted = formatter.string(from: interval) else { return "" }
        return "\(formatted) ago"
    }

    private func formatElapsedTime(from interval: TimeInterval) -> String {
        if interval < 60 {
            return "Just now"
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated // e.g. "1h 20m"
        formatter.zeroFormattingBehavior = [.dropAll]
        if let formatted = formatter.string(from: interval) {
            return String(localized: "\(formatted) ago")
        }
        return "Just now"
    }

    private func formattedElapsedIncludingSeconds(from interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval < 60 ? [.second] : [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropAll]
        if let formatted = formatter.string(from: interval) {
            return formatted
        }
        return "0s"
    }
}



#if DEBUG
struct BabyStatusView2_Previews: PreviewProvider {
    static var previews: some View {
        let controller = PersistenceController.preview
        let context = controller.viewContext
        
        // Scenario 1: Normal Data
        let babyNormal = BabyProfile(context: context, name: "연두")
        let session1 = FeedSession(context: context, startTime: Date.current.addingTimeInterval(-20 * 60))
        session1.amount = Measurement(value: 140, unit: .milliliters)
        session1.profile = babyNormal
        
        let diaper1 = DiaperChange(context: context, timestamp: Date.current.addingTimeInterval(-30 * 60), type: .pee)
        diaper1.profile = babyNormal
        
        // Scenario 2: Empty Data
        let babyEmpty = BabyProfile(context: context, name: "New Baby")
        
        // Scenario 3: Overdue / Warning (Simulated by long time ago)
        let babyOverdue = BabyProfile(context: context, name: "Overdue")
        let session2 = FeedSession(context: context, startTime: Date.current.addingTimeInterval(-5 * 60 * 60)) // 5 hours ago
        session2.endTime = Date.current.addingTimeInterval(-4 * 60 * 60)
        session2.profile = babyOverdue
        let diaper2 = DiaperChange(context: context, timestamp: Date.current.addingTimeInterval(-6 * 60 * 60), type: .poo)
        diaper2.profile = babyOverdue
        
        // Scenario 4: In Progress
        let babyInProgress = BabyProfile(context: context, name: "Feeding")
        let session3 = FeedSession(context: context, startTime: Date.current.addingTimeInterval(-10 * 60)) // Started 10 mins ago
        session3.profile = babyInProgress

        return Group {
            BabyStatusView2(
                baby: babyNormal,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in },
                onLastDiaperTap: { _ in }
            )
            .previewDisplayName("Normal")
            
            BabyStatusView2(
                baby: babyEmpty,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in },
                onLastDiaperTap: { _ in }
            )
            .previewDisplayName("Empty")
            
            BabyStatusView2(
                baby: babyOverdue,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in },
                onLastDiaperTap: { _ in }
            )
            .previewDisplayName("Overdue")
            
            BabyStatusView2(
                baby: babyInProgress,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in },
                onLastDiaperTap: { _ in }
            )
            .previewDisplayName("In Progress")
        }
        .environment(\.managedObjectContext, context)
        .previewLayout(.sizeThatFits)
        .previewInterfaceOrientation(.landscapeLeft)
        .padding()
        .background(.background)
        .environment(\.colorScheme, .dark)
    }
}
#endif

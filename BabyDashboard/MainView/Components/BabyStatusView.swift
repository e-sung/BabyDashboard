import SwiftUI
import CoreData
import Model

struct BabyStatusView: View {
    @ObservedObject var baby: BabyProfile
    @EnvironmentObject var settings: AppSettings
    @Environment(\.managedObjectContext) private var viewContext

    // Animation States
    var isFeedAnimating: Bool = false
    var isDiaperAnimating: Bool = false
    
    // Daily Checklist Configuration
    let checklistEmojis: [String]
    let isConfiguringChecklist: Bool
    let onConfigureChecklist: (BabyProfile) -> Void
    let onRemoveFromChecklist: (String) -> Void
    
    // Actions
    let onFeedTap: () -> Void
    let onFeedLongPress: () -> Void
    let onDiaperTap: () -> Void
    let onNameTap: () -> Void
    let onLastFeedTap: ((FeedSession) -> Void)?
    let onLastDiaperTap: ((DiaperChange) -> Void)?
    
    // Fetch today's checklist events
    @FetchRequest private var todaysChecklistEvents: FetchedResults<CustomEvent>
    
    // Fetch all custom event types (global)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CustomEventType.createdAt, ascending: true)],
        animation: .default
    )
    private var allEventTypes: FetchedResults<CustomEventType>
    
    init(
        baby: BabyProfile,
        checklistEmojis: [String],
        isConfiguringChecklist: Bool,
        isFeedAnimating: Bool = false,
        isDiaperAnimating: Bool = false,
        onFeedTap: @escaping () -> Void,
        onFeedLongPress: @escaping () -> Void,
        onDiaperTap: @escaping () -> Void,
        onNameTap: @escaping () -> Void,
        onLastFeedTap: ((FeedSession) -> Void)?,
        onLastDiaperTap: ((DiaperChange) -> Void)?,
        onConfigureChecklist: @escaping (BabyProfile) -> Void,
        onRemoveFromChecklist: @escaping (String) -> Void
    ) {
        self.baby = baby
        self.checklistEmojis = checklistEmojis
        self.isConfiguringChecklist = isConfiguringChecklist
        self.isFeedAnimating = isFeedAnimating
        self.isDiaperAnimating = isDiaperAnimating
        self.onFeedTap = onFeedTap
        self.onFeedLongPress = onFeedLongPress
        self.onDiaperTap = onDiaperTap
        self.onNameTap = onNameTap
        self.onLastFeedTap = onLastFeedTap
        self.onLastDiaperTap = onLastDiaperTap
        self.onConfigureChecklist = onConfigureChecklist
        self.onRemoveFromChecklist = onRemoveFromChecklist
        
        // Fetch today's checklist events using emoji (no relationship needed)
        let startOfDay = Calendar.current.startOfDay(for: Date.current)
        let checklistEmojis = baby.dailyChecklistArray.map { $0.eventTypeEmoji }
        
        _todaysChecklistEvents = FetchRequest<CustomEvent>(
            sortDescriptors: [NSSortDescriptor(keyPath: \CustomEvent.timestamp, ascending: false)],
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "profile == %@", baby),
                NSPredicate(format: "timestamp >= %@", startOfDay as NSDate),
                NSPredicate(format: "eventTypeEmoji IN %@", checklistEmojis)
            ])
        )
    }

    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private let diaperWarningThreshold: TimeInterval = 60 * 60 * 1 // 1 hours default
    
    private var isIPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = Date.current
            
            VStack(alignment: .leading, spacing: isIPhone ? 12 : 20) {
                // Header
                HStack {
                    Button {
                        onNameTap()
                    } label: {
                        Text(baby.name)
                            .font(.system(size: isIPhone ? 34 : 50, weight: .bold))
                            .padding(.horizontal)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    // Daily Checklist Items
                    HStack(spacing: 12) {
                        // Show placeholder if in config mode and not at max capacity
                        if isConfiguringChecklist && baby.dailyChecklistArray.count < AppSettings.maxChecklistItems {
                            PlaceholderToggleButton {
                                onConfigureChecklist(baby)
                            }
                        }
                        
                        // Show configured checklist items
                        ForEach(baby.dailyChecklistArray) { item in
                            let isChecked = todaysChecklistEvents.contains { $0.eventTypeEmoji == item.eventTypeEmoji }
                            
                            StatusToggleButton(
                                emoji: item.eventTypeEmoji,
                                isOn: isChecked,
                                isInConfigMode: isConfiguringChecklist,
                                action: {
                                    if !isConfiguringChecklist {
                                        toggleChecklist(emoji: item.eventTypeEmoji, name: item.eventTypeName, isChecked: isChecked, now: now)
                                    }
                                },
                                onDelete: {
                                    onRemoveFromChecklist(item.eventTypeEmoji)
                                }
                            )
                        }
                    }
                    .padding(.trailing)
                }


                // Conditional layout: HStack for iPhone, VStack for iPad
                if isIPhone {
                    HStack(spacing: 10) {
                        // Compact Feed Card
                        CompactStatusCard(
                            icon: .image("bottle"),
                            title: baby.inProgressFeedSession != nil ? String(localized: "Feeding") : String(localized: "Feed"),
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
                            accessibilityHintText: "Double tap to start or stop feeding",
                            onTap: onFeedTap,
                            onFooterTap: {
                                if baby.inProgressFeedSession != nil {
                                    onLastFeedTap?(baby.inProgressFeedSession!)
                                } else if let session = baby.lastFinishedFeedSession {
                                    onLastFeedTap?(session)
                                }
                            }
                        )
                        .onLongPressGesture(perform: onFeedLongPress)
                        
                        // Compact Diaper Card
                        CompactStatusCard(
                            icon: .image("diaper"),
                            title: String(localized: "Diaper"),
                            mainText: diaperTimeAgo(now: now),
                            progressBarColor: Color("diaperProgressColor"),
                            progress: diaperProgress(now: now),
                            footerText: diaperFooterText,
                            criteriaLabel: "1h",
                            isAnimating: isDiaperAnimating,
                            shouldWarn: shouldWarnDiaper,
                            warningColor: Color("diaperProgressColor"),
                            accessibilityHintText: "Double tap to log a diaper change",
                            onTap: onDiaperTap,
                            onFooterTap: {
                                if let diaper = baby.lastDiaperChange {
                                    onLastDiaperTap?(diaper)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 16) {
                        // Feed Card (iPad)
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
                                    onLastFeedTap?(baby.inProgressFeedSession!)
                                } else if let session = baby.lastFinishedFeedSession {
                                    onLastFeedTap?(session)
                                }
                            }
                        )
                        .onLongPressGesture(perform: onFeedLongPress)
                        
                        // Diaper Card (iPad)
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
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, isIPhone ? 12 : 20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
            .background(Color(uiColor: .systemGroupedBackground)) // Light gray background
            .cornerRadius(isIPhone ? 16 : 20)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Creates a BabyStatusLogic instance for display calculations
    private func makeStatusLogic() -> BabyStatusLogic {
        BabyStatusLogic(
            baby: baby,
            diaperWarningThreshold: diaperWarningThreshold,
            isLargeDynamicType: isLargeDynamicType
        )
    }

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
        makeStatusLogic().feedMainText(now: now)
    }
    
    private func feedProgress(now: Date) -> Double {
        makeStatusLogic().feedProgress(now: now)
    }
    
    private func feedSecondaryProgress(now: Date) -> Double? {
        makeStatusLogic().feedSecondaryProgress(now: now)
    }
    
    private func feedFooterText(now: Date) -> String {
        makeStatusLogic().feedFooterText(now: now)
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
        makeStatusLogic().diaperTimeAgo(now: now)
    }
    
    private func diaperProgress(now: Date) -> Double {
        makeStatusLogic().diaperProgress(now: now)
    }
    
    private var diaperFooterText: String {
        makeStatusLogic().diaperFooterText()
    }
    
    private var diaperCriteriaLabel: String {
        let hours = Int(diaperWarningThreshold / 3600)
        return "\(hours)h"
    }
    
    // MARK: - Helpers
    
    private var isLargeDynamicType: Bool {
        if let size = settings.preferredFontScale.dynamicTypeSize {
            return size > .accessibility3
        }
        return false
    }

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
    
    private func formattedElapsingTime(from interval: TimeInterval) -> String {
        let formatter = makeComponentsFormatter(allowedUnits: [.hour, .minute])
        guard let formatted = formatter.string(from: interval) else { return "" }
        if isLargeDynamicType {
            return formatted
        }
        return String(localized: "\(formatted) ago")
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
    
    // MARK: - Checklist Toggle Logic
    
    private func toggleChecklist(emoji: String, name: String, isChecked: Bool, now: Date) {
        let manager = ChecklistManager(context: viewContext, settings: settings)
        
        do {
            try manager.toggleChecklistItem(
                baby: baby,
                emoji: emoji,
                name: name,
                currentlyChecked: isChecked,
                timestamp: now
            )
        } catch {
            print("Failed to toggle checklist item '\(name)': \(error.localizedDescription)")
        }
    }

    private func getStartOfDay(now: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        // Set to today's start time
        components.hour = settings.startOfDayHour
        components.minute = settings.startOfDayMinute
        components.second = 0
        
        guard let todayStart = calendar.date(from: components) else { return now }
        
        // If now is before today's start time, then the "current day" started yesterday
        if now < todayStart {
            return calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        }
        
        return todayStart
    }
}



#if DEBUG
struct BabyStatusView_Previews: PreviewProvider {
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
        
        // Add custom event type for preview
        let eventType = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        
        return Group {
            BabyStatusView(
                baby: babyNormal,
                checklistEmojis: [eventType.emoji],
                isConfiguringChecklist: false,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in },
                onLastDiaperTap: { _ in },
                onConfigureChecklist: { _ in },
                onRemoveFromChecklist: { _ in }
            )
            .previewDisplayName("With Checklist")
            .environmentObject(AppSettings())
            
            BabyStatusView(
                baby: babyNormal,
                checklistEmojis: [eventType.emoji],
                isConfiguringChecklist: true,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperTap: {},
                onNameTap: {},
                onLastFeedTap: nil,
                onLastDiaperTap: nil,
                onConfigureChecklist: { _ in },
                onRemoveFromChecklist: { _ in }
            )
            .previewDisplayName("Config Mode")
            .environmentObject(AppSettings())
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



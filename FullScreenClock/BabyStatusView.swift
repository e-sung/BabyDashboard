import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct BabyStatusView: View {
    // The source of truth is now the SwiftData model.
    @Bindable var baby: BabyProfile

    // Animation states are still controlled from the parent
    @Binding var isFeedAnimating: Bool
    @Binding var isDiaperAnimating: Bool

    // Closures for intents, to be implemented by the parent view.
    let onFeedTap: () -> Void
    let onFeedLongPress: () -> Void
    let onDiaperUpdateTap: () -> Void
    let onDiaperEditTap: () -> Void
    let onNameTap: () -> Void
    let onLastFeedTap: ((FeedSession) -> Void)?

    // A date formatter for HH:mm format.
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // Device idiom: default is iPad, adjust only for iPhone
    private var isIPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    // MARK: - Computed Properties for Display

    private var lastFeedTime: String {
        guard let lastSession = baby.lastFinishedFeedSession else { return "--:--" }
        let start = lastSession.startTime
        return timeFormatter.string(from: start)
    }

    private var lastDiaperTime: String {
        guard let lastDiaper = baby.lastDiaperChange else { return "--:--" }
        return timeFormatter.string(from: lastDiaper.timestamp)
    }
    
    private var lastFeedAmountString: String? {
        guard let session = baby.lastFinishedFeedSession, let amount = session.amount else { return nil }
        return amount.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    private var lastFeedDurationString: String? {
        guard let session = baby.lastFinishedFeedSession, let endTime = session.endTime else { return nil }
        let duration = endTime.timeIntervalSince(session.startTime)
        guard duration > 0 else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        
        return formatter.string(from: duration)
    }

    private var diaperImageSize: CGFloat {
        return 50
    }

    // Static thresholds for warnings (in seconds). Later, read from user settings.
    private let feedWarningThreshold: TimeInterval = 3 * 60 * 60
    private let diaperWarningThreshold: TimeInterval = 1 * 60 * 60

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date

            let shouldWarnFeed = WarningLogic.shouldWarnFeed(
                now: now,
                startOfLastFeed: baby.lastFinishedFeedSession?.startTime,
                inProgress: baby.inProgressFeedSession != nil,
                threshold: feedWarningThreshold
            )

            let shouldWarnDiaper = WarningLogic.shouldWarnDiaper(
                now: now,
                lastDiaperTime: baby.lastDiaperChange?.timestamp,
                threshold: diaperWarningThreshold
            )

            VStack(alignment: .leading) {
                Text(baby.name)
                    .font(isIPhone ? .largeTitle : .system(size: 40))
                    .fontWeight(.bold)
                    .onTapGesture(perform: onNameTap)
                
                VStack(alignment: .leading, spacing: 6) {
                    feedStateView(now: now, shouldWarn: shouldWarnFeed)
                    diaperStateView(now: now, shouldWarn: shouldWarnDiaper)
                }
                .font(isIPhone ? .title : .system(size: 60)) // iPad keeps 60, iPhone uses semantic .title
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func feedStateView(now: Date, shouldWarn: Bool) -> some View {
        HStack(alignment: .center) {
            ZStack(alignment: .topTrailing) {
                Text("🍼")
                    .font(isIPhone ? .title : .system(size: 50))
                if shouldWarn {
                    warningBadge()
                        .offset(x: 6, y: -6)
                }
            }
            
            VStack(alignment: .leading) {
                if let inProgressSession = baby.inProgressFeedSession {
                    Text("Feeding...")
                        .fontWeight(.heavy)
                        .foregroundColor(.blue)
                    Text(formattedElapsingTime(from: now.timeIntervalSince(inProgressSession.startTime)))
                        .font(.title)
                        .monospacedDigit()
                } else {
                    Text(lastFeedTime)
                        .fontWeight(.heavy)
                        .foregroundColor(shouldWarn ? .red : .primary)
                    HStack {
                        if let time = baby.lastFinishedFeedSession?.startTime {
                            Text(formatElapsedTime(from: now.timeIntervalSince(time)))
                                .font(.title)
                        }
                        if let amount = lastFeedAmountString, let duration = lastFeedDurationString, let session = baby.lastFinishedFeedSession {
                            LastFeedDetailsView(amountString: amount, durationString: duration)
                                .onTapGesture {
                                    onLastFeedTap?(session)
                                }
                        }
                    }

                }
            }
        }
        .onTapGesture(perform: onFeedTap)
        .onLongPressGesture(perform: onFeedLongPress)
        .scaleEffect(isFeedAnimating ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.3), value: isFeedAnimating)
    }

    private func diaperStateView(now: Date, shouldWarn: Bool) -> some View {
        HStack(alignment: .center, spacing: 15) {
            ZStack(alignment: .topTrailing) {
                Image("diaper")
                    .resizable()
                    .frame(width: diaperImageSize, height: diaperImageSize)
                    .foregroundStyle(shouldWarn ? .red : .primary)
                if shouldWarn {
                    warningBadge()
                        .offset(x: 6, y: -6)
                }
            }
            
            VStack(alignment: .leading) {
                Text(lastDiaperTime)
                    .fontWeight(.heavy)
                    .foregroundStyle(shouldWarn ? .yellow : .primary)
                if let ts = baby.lastDiaperChange?.timestamp {
                    Text(formatElapsedTime(from: now.timeIntervalSince(ts)))
                        .font(.title)
                }
            }
        }
        .onTapGesture { onDiaperUpdateTap() }
        .onLongPressGesture { onDiaperEditTap() }
        .scaleEffect(isDiaperAnimating ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.3), value: isDiaperAnimating)
    }

    // Small red circular badge with an exclamation mark
    private func warningBadge(size: CGFloat = 18, color: Color = .red) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text("!")
                .font(.system(size: size * 0.75, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .offset(y: -0.5)
        }
        .accessibilityLabel(Text("Warning"))
        .accessibilityHidden(false)
        .allowsHitTesting(false) // badge should not intercept taps
    }

    // MARK: - Formatting helpers

    private func formattedElapsingTime(from interval: TimeInterval) -> String {
        let comps = DateComponentsFormatter()
        comps.allowedUnits = [.hour, .minute, .second]
        comps.unitsStyle = .abbreviated
        comps.zeroFormattingBehavior = [.dropAll]
        if let formatted = comps.string(from: interval) {
            return String(localized: "\(formatted) passed")
        }
        return ""
    }

    private func formatElapsedTime(from interval: TimeInterval) -> String {
        if interval < 60 {
            return String(localized: "Just now")
        }
        let comps = DateComponentsFormatter()
        comps.allowedUnits = [.hour, .minute]
        comps.unitsStyle = .short
        comps.zeroFormattingBehavior = [.dropAll]
        if let formatted = comps.string(from: interval) {
            return String(localized: "\(formatted) ago")
        } else {
            return String(localized: "Just now")
        }
    }
}

// Add convenience computed properties to the SwiftData model.
extension BabyProfile {
    var inProgressFeedSession: FeedSession? {
        (feedSessions ?? []).first(where: { $0.isInProgress })
    }
    
    var lastFinishedFeedSession: FeedSession? {
        (feedSessions ?? [])
            .filter { !$0.isInProgress && $0.endTime != nil }
            .sorted(by: { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) })
            .first
    }

    var lastFeedSession: FeedSession? {
        feedSessions?
            .sorted(by: { ($0.startTime ) > ($1.startTime ) })
            .first
    }

    var lastDiaperChange: DiaperChange? {
        (diaperChanges ?? []).sorted(by: { $0.timestamp > $1.timestamp }).first
    }
}

// MARK: - Focused Previews

#Preview("Initial (no data)") {
    let schema = Schema([BabyProfile.self, FeedSession.self, DiaperChange.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    let baby = BabyProfile(id: UUID(), name: "초기")
    container.mainContext.insert(baby)

    struct Wrapper: View {
        @State var feed = false
        @State var diaper = false
        let baby: BabyProfile
        var body: some View {
            BabyStatusView(
                baby: baby,
                isFeedAnimating: $feed,
                isDiaperAnimating: $diaper,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperUpdateTap: {},
                onDiaperEditTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in }
            )
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    return Wrapper(baby: baby)
        .modelContainer(container)
}

#Preview("Normal") {
    let schema = Schema([BabyProfile.self, FeedSession.self, DiaperChange.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    let baby = BabyProfile(id: UUID(), name: "정상")
    container.mainContext.insert(baby)

    // feed ended ~35m ago (start 50m ago, duration 15m)
    let start = Date().addingTimeInterval(-50*60)
    let session = FeedSession(startTime: start)
    session.endTime = Calendar.current.date(byAdding: .minute, value: 15, to: start)
    session.amount = Measurement(value: (Locale.current.measurementSystem == .us) ? 4.0 : 120.0,
                                 unit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
    session.profile = baby
    container.mainContext.insert(session)

    // diaper 25m ago
    let diaper = DiaperChange(timestamp: Date().addingTimeInterval(-25*60), type: .pee)
    diaper.profile = baby
    container.mainContext.insert(diaper)

    struct Wrapper: View {
        @State var feed = false
        @State var diaper = false
        let baby: BabyProfile
        var body: some View {
            BabyStatusView(
                baby: baby,
                isFeedAnimating: $feed,
                isDiaperAnimating: $diaper,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperUpdateTap: {},
                onDiaperEditTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in }
            )
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    return Wrapper(baby: baby)
        .modelContainer(container)
}

#Preview("Feeding (in progress)") {
    let schema = Schema([BabyProfile.self, FeedSession.self, DiaperChange.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    let baby = BabyProfile(id: UUID(), name: "수유중")
    container.mainContext.insert(baby)

    // in-progress feed started 5 min ago
    let inProgress = FeedSession(startTime: Date().addingTimeInterval(-5*60))
    inProgress.profile = baby
    container.mainContext.insert(inProgress)

    // older diaper, but we’re previewing feed state
    let diaper = DiaperChange(timestamp: Date().addingTimeInterval(-70*60), type: .poo)
    diaper.profile = baby
    container.mainContext.insert(diaper)

    struct Wrapper: View {
        @State var feed = true
        @State var diaper = false
        let baby: BabyProfile
        var body: some View {
            BabyStatusView(
                baby: baby,
                isFeedAnimating: $feed,
                isDiaperAnimating: $diaper,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperUpdateTap: {},
                onDiaperEditTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in }
            )
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    return Wrapper(baby: baby)
        .modelContainer(container)
}

#Preview("Feed Warning (>3h since last feed)") {
    let schema = Schema([BabyProfile.self, FeedSession.self, DiaperChange.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    let baby = BabyProfile(id: UUID(), name: "수유경고")
    container.mainContext.insert(baby)

    // last feed ended > 3h ago
    let start = Date().addingTimeInterval(-(3*60*60 + 40*60)) // start 3h40m ago
    let session = FeedSession(startTime: start)
    session.endTime = Calendar.current.date(byAdding: .minute, value: 20, to: start) // ended ~3h20m ago
    session.amount = Measurement(value: (Locale.current.measurementSystem == .us) ? 3.5 : 105.0,
                                 unit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
    session.profile = baby
    container.mainContext.insert(session)

    // recent diaper to avoid diaper warning
    let diaper = DiaperChange(timestamp: Date().addingTimeInterval(-20*60), type: .pee)
    diaper.profile = baby
    container.mainContext.insert(diaper)

    struct Wrapper: View {
        @State var feed = false
        @State var diaper = false
        let baby: BabyProfile
        var body: some View {
            BabyStatusView(
                baby: baby,
                isFeedAnimating: $feed,
                isDiaperAnimating: $diaper,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperUpdateTap: {},
                onDiaperEditTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in }
            )
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    return Wrapper(baby: baby)
        .modelContainer(container)
}

#Preview("Diaper Warning (>1h since last diaper)") {
    let schema = Schema([BabyProfile.self, FeedSession.self, DiaperChange.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])

    let baby = BabyProfile(id: UUID(), name: "기저귀경고")
    container.mainContext.insert(baby)

    // recent feed
    let start = Date().addingTimeInterval(-40*60)
    let session = FeedSession(startTime: start)
    session.endTime = Calendar.current.date(byAdding: .minute, value: 15, to: start)
    session.amount = Measurement(value: (Locale.current.measurementSystem == .us) ? 4.0 : 120.0,
                                 unit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
    session.profile = baby
    container.mainContext.insert(session)

    // last diaper > 1h ago
    let diaper = DiaperChange(timestamp: Date().addingTimeInterval(-(60*60 + 5*60)), type: .poo)
    diaper.profile = baby
    container.mainContext.insert(diaper)

    struct Wrapper: View {
        @State var feed = false
        @State var diaper = false
        let baby: BabyProfile
        var body: some View {
            BabyStatusView(
                baby: baby,
                isFeedAnimating: $feed,
                isDiaperAnimating: $diaper,
                onFeedTap: {},
                onFeedLongPress: {},
                onDiaperUpdateTap: {},
                onDiaperEditTap: {},
                onNameTap: {},
                onLastFeedTap: { _ in }
            )
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    return Wrapper(baby: baby)
        .modelContainer(container)
}

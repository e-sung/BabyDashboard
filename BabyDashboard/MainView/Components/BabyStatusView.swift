import SwiftUI
import CoreData
import Model
#if canImport(UIKit)
import UIKit
#endif

struct BabyStatusView: View {
    @ObservedObject var baby: BabyProfile

    @Binding var isFeedAnimating: Bool
    @Binding var isDiaperAnimating: Bool

    let onFeedTap: () -> Void
    let onFeedLongPress: () -> Void
    let onDiaperUpdateTap: () -> Void
    let onDiaperEditTap: () -> Void
    let onNameTap: () -> Void
    let onLastFeedTap: ((FeedSession) -> Void)?

    /// Whether this tile is highlighted (e.g., newly added baby from sharing).
    var isHighlighted: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var isIPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    private var lastFeedTime: String {
        guard let session = baby.lastFinishedFeedSession else { return "--:--" }
        return timeFormatter.string(from: session.startTime)
    }

    private var lastDiaperTime: String {
        guard let diaper = baby.lastDiaperChange else { return "--:--" }
        return timeFormatter.string(from: diaper.timestamp)
    }

    private var lastFeedAmountString: String? {
        guard let session = baby.lastFinishedFeedSession,
              let amount = session.amount else { return nil }
        return amount.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    private var lastFeedDurationString: String? {
        guard let session = baby.lastFinishedFeedSession,
              let end = session.endTime else { return nil }
        let duration = max(0, end.timeIntervalSince(session.startTime))
        guard duration > 0 else { return nil }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: duration)
    }

    private let diaperWarningThreshold: TimeInterval = 60 * 60

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = Date.current

            let shouldWarnFeed = WarningLogic.shouldWarnFeed(
                now: now,
                startOfLastFeed: baby.lastFinishedFeedSession?.startTime,
                inProgress: baby.inProgressFeedSession != nil,
                threshold: baby.feedTerm
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
                .font(isIPhone ? .title : .system(size: 60))
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHighlighted ? Color.accentColor : .clear, lineWidth: 3)
                    .shadow(color: isHighlighted ? Color.accentColor.opacity(0.3) : .clear, radius: 12)
            )
            .scaleEffect(isHighlighted && !reduceMotion ? 1.03 : 1)
            .animation(reduceMotion ? .default : .spring(response: 0.5, dampingFraction: 0.75), value: isHighlighted)
        }
    }

    @ViewBuilder
    private func feedStateView(now: Date, shouldWarn: Bool) -> some View {
        HStack(alignment: .center) {
            Button(action: onFeedTap) {
                ZStack(alignment: .topTrailing) {
                    Text("🍼")
                        .font(isIPhone ? .title : .system(size: 50))
                    if shouldWarn {
                        warningBadge()
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(TappableIconStyle())
            .accessibilityLabel("Log a feed")
            .accessibilityHint("Tap to start or view feeding")

            VStack(alignment: .leading) {
                if let session = baby.inProgressFeedSession {
                    Text("Feeding...")
                        .fontWeight(.heavy)
                        .foregroundColor(.blue)
                    Text(formattedElapsingTime(from: now.timeIntervalSince(session.startTime)))
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
                        if let amount = lastFeedAmountString,
                           let duration = lastFeedDurationString,
                           let session = baby.lastFinishedFeedSession {
                            LastFeedDetailsView(amountString: amount, durationString: duration)
                                .onTapGesture {
                                    onLastFeedTap?(session)
                                }
                                .accessibilityIdentifier("LastFeedDetails")
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
            Button(action: onDiaperUpdateTap) {
                ZStack(alignment: .topTrailing) {
                    Image("diaper")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundStyle(shouldWarn ? .red : .primary)
                    if shouldWarn {
                        warningBadge()
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(TappableIconStyle())
            .accessibilityLabel("Log a diaper change")
            .accessibilityHint("Tap to add a diaper change")
            .contextMenu {
                Button("Edit diaper…", systemImage: "pencil", action: onDiaperEditTap)
            }

            VStack(alignment: .leading) {
                Text(lastDiaperTime)
                    .fontWeight(.heavy)
                    .foregroundStyle(shouldWarn ? .yellow : .primary)
                if let timestamp = baby.lastDiaperChange?.timestamp {
                    Text(formatElapsedTime(from: now.timeIntervalSince(timestamp)))
                        .font(.title)
                }
            }
        }
        .onTapGesture { onDiaperUpdateTap() }
        .onLongPressGesture { onDiaperEditTap() }
        .scaleEffect(isDiaperAnimating ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.3), value: isDiaperAnimating)
    }

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
        .allowsHitTesting(false)
    }

    private func formattedElapsingTime(from interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropAll]
        guard let formatted = formatter.string(from: interval) else { return "" }
        return String(localized: "\(formatted) passed")
    }

    private func formatElapsedTime(from interval: TimeInterval) -> String {
        if interval < 60 {
            return String(localized: "Just now")
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = [.dropAll]
        if let formatted = formatter.string(from: interval) {
            return String(localized: "\(formatted) ago")
        }
        return String(localized: "Just now")
    }
}

#if DEBUG
#Preview("Normal Status") {
    let controller = PersistenceController.preview
    let context = controller.viewContext
    let baby = BabyProfile(context: context, name: "연두")
    context.performAndWait {

        let session1 = FeedSession(context: context, startTime: Date().addingTimeInterval(-60 * 60))
        session1.endTime = Date().addingTimeInterval(-15 * 60)
        session1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.0 : 120.0,
                                      unit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
        session1.profile = baby

        let diaper1 = DiaperChange(context: context, timestamp: Date().addingTimeInterval(-30 * 60), type: .pee)
        diaper1.profile = baby

        try? context.save()
    }

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
        }
    }

    return PreviewWrapper(baby: baby)
        .environment(\.managedObjectContext, context)
}

#Preview("Initial (no data)") {
    let controller = PersistenceController.preview
    let context = controller.viewContext

    var previewBaby: BabyProfile!
    context.performAndWait {
        previewBaby = BabyProfile(context: context, name: "초기")
        try? context.save()
    }

    return PreviewWrapper(baby: previewBaby)
        .environment(\.managedObjectContext, context)
}

fileprivate struct PreviewWrapper: View {
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
    }
}
#endif

private struct TappableIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .hoverEffect(.highlight)
    }
}

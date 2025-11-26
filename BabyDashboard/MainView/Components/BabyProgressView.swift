import SwiftUI
import Model

@MainActor
class BabyProgressViewModel: ObservableObject {

    let baby: BabyProfile
    let timeScope: TimeInterval

    @Published var totalProgress: Double = 0
    @Published var feedingProgress: Double = 0

    private var totalTimer: Timer?
    private var blueTimer: Timer?

    private var lastStart: Date? {
        baby.lastFeedSession?.startTime
    }

    init (baby: BabyProfile, timeScope: TimeInterval) {
        self.baby = baby
        self.timeScope = timeScope

        totalTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard let start = self.lastStart else { return }
                let elapsed = Date().timeIntervalSince(start)
                self.totalProgress = elapsed / timeScope
            }

        }

        blueTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.baby.inProgressFeedSession != nil {
                    self.feedingProgress = self.totalProgress
                } else if let finished = self.baby.lastFinishedFeedSession, let end = finished.endTime {
                    let duration = max(0, end.timeIntervalSince(finished.startTime))
                    self.feedingProgress = duration / timeScope
                }
            }
        }
    }

    deinit {
        totalTimer?.invalidate()
        blueTimer?.invalidate()
    }
}

struct BabyProgressView: View {
    @ObservedObject var baby: BabyProfile
    let timeScope: TimeInterval
    var feedingColor: Color = .blue
    @StateObject var viewModel: BabyProgressViewModel

    init(baby: BabyProfile, timeScope: TimeInterval, feedingColor: Color) {
        self.baby = baby
        self.timeScope = timeScope
        self.feedingColor = feedingColor
        _viewModel = .init(wrappedValue: .init(baby: baby, timeScope: timeScope))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VerticalProgressView(
                progress: viewModel.totalProgress,
                timeScope: timeScope
            )
            // 수유 기간을 표시하는 프로그레스 바
            if viewModel.totalProgress <= 1 {
                VerticalProgressView(
                    progress: viewModel.feedingProgress,
                    timeScope: timeScope,
                    progressColor: feedingColor,
                    drawTrackAndBackground: true
                )
            }

        }
    }
}

#Preview("BabyProgressView Scenarios") {
    let controller = PersistenceController.preview
    let context = controller.viewContext
    let scope: TimeInterval = 60
    let now = Date()

    var babyFeeding: BabyProfile!
    var babyFinished: BabyProfile!
    var babyOverdue: BabyProfile!

    context.performAndWait {
        // Scenario 1: Feeding just started (in-progress)
        babyFeeding = BabyProfile(context: context, name: "Feeding Now")
        let inProgress = FeedSession(context: context, startTime: now)
        inProgress.profile = babyFeeding

        // Scenario 2: Finished 45-minute feed, ended 30 minutes ago
        babyFinished = BabyProfile(context: context, name: "45 min ended 30m ago")
        let start2 = now.addingTimeInterval(-75 * 60)
        let end2 = now.addingTimeInterval(-30 * 60)
        let finished = FeedSession(context: context, startTime: start2)
        finished.endTime = end2
        finished.profile = babyFinished

        // Scenario 3: Overdue
        babyOverdue = BabyProfile(context: context, name: "Overdue 4h since start")
        let start3 = now.addingTimeInterval(-4 * 3600)
        let end3 = now.addingTimeInterval(-3 * 3600 - 45 * 60)
        let overdue = FeedSession(context: context, startTime: start3)
        overdue.endTime = end3
        overdue.profile = babyOverdue

        try? context.save()
    }

    return HStack(spacing: 24) {
        VStack {
            Text("Feeding Now")
                .font(.caption)
            BabyProgressView(baby: babyFeeding, timeScope: scope, feedingColor: .blue)
                .frame(width: 20)
        }
        VStack {
            Text("45m ended 30m")
                .font(.caption)
            BabyProgressView(baby: babyFinished, timeScope: scope, feedingColor: .blue)
                .frame(width: 20)
        }
        VStack {
            Text("Overdue 4h")
                .font(.caption)
            BabyProgressView(baby: babyOverdue, timeScope: scope, feedingColor: .blue)
                .frame(width: 20)
        }
    }
    .frame(height: 300)
    .padding()
    .environment(\.managedObjectContext, context)
}

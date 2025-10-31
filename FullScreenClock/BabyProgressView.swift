import SwiftUI
import Model

struct BabyProgressView: View {
    let baby: BabyProfile
    let timeScope: TimeInterval
    var feedingColor: Color = .blue

    private var lastStart: Date? {
        baby.lastFeedSession?.startTime
    }

    // Total progress since last session start (drives the base VerticalProgressView)
    private var totalProgress: Double {
        guard let start = lastStart else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return elapsed / timeScope
    }

    // Blue segment height ratio: duration of the latest feed session.
    // - If feeding now: grows live (now - start).
    // - If last session finished: fixed at (end - start).
    // - If no session: 0.
    private var blueProgress: Double {
        if let inProgress = baby.inProgressFeedSession {
            let elapsed = Date().timeIntervalSince(inProgress.startTime)
            return max(0, elapsed / timeScope)
        }
        if let finished = baby.lastFinishedFeedSession, let end = finished.endTime {
            let duration = max(0, end.timeIntervalSince(finished.startTime))
            return duration / timeScope
        }
        return 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Base: existing behavior (green fill; red on overdue; indicators)
            VerticalProgressView(progress: totalProgress, timeScope: timeScope)

            // Blue overlay: show only when not overdue and there is something to show
            if totalProgress <= 1.0, blueProgress > 0 {
                VerticalProgressView(
                    progress: blueProgress,
                    timeScope: timeScope,
                    progressColor: feedingColor,
                    drawTrackAndBackground: false
                )
                .allowsHitTesting(false)
            }
        }
    }
}

#Preview("BabyProgressView Scenarios") {
    // timeScope: 3 hours
    let scope: TimeInterval = 3 * 3600
    let now = Date()

    // Scenario 1: Feeding just started (in-progress)
    let babyFeeding = BabyProfile(id: UUID(), name: "Feeding Now")
    let inProgress = FeedSession(startTime: now) // just started
    inProgress.profile = babyFeeding
    babyFeeding.feedSessions = [inProgress]

    // Scenario 2: Finished 45-minute feed, ended 30 minutes ago
    // Start 75 minutes ago, end 30 minutes ago => duration 45 minutes
    let babyFinished = BabyProfile(id: UUID(), name: "45 min ended 30m ago")
    let start2 = now.addingTimeInterval(-75 * 60)
    let end2 = now.addingTimeInterval(-30 * 60)
    let finished = FeedSession(startTime: start2)
    finished.endTime = end2
    finished.profile = babyFinished
    babyFinished.feedSessions = [finished]

    // Scenario 3: Overdue — last feed started 4 hours ago (blue hidden)
    // Start 4 hours ago, end 3h 45m ago (15 min duration)
    let babyOverdue = BabyProfile(id: UUID(), name: "Overdue 4h since start")
    let start3 = now.addingTimeInterval(-4 * 3600)
    let end3 = now.addingTimeInterval(-3 * 3600 - 45 * 60)
    let overdue = FeedSession(startTime: start3)
    overdue.endTime = end3
    overdue.profile = babyOverdue
    babyOverdue.feedSessions = [overdue]

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
}

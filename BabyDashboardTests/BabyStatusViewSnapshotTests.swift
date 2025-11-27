import SnapshotTesting
import SwiftUI
import XCTest
@testable import BabyDashboard
import Model

final class BabyStatusViewSnapshotTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var originalArguments: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        originalArguments = CommandLine.arguments
        CommandLine.arguments.append("-FixedTime:1700000000")
    }

    override func tearDown() {
        CommandLine.arguments = originalArguments
        persistenceController = nil
        super.tearDown()
    }

    @MainActor
    func testBabyStatusViewDefaultState() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let baby = makeBabyProfile(now: now)

        let view = BabyStatusView(
            baby: baby,
            isFeedAnimating: .constant(false),
            isDiaperAnimating: .constant(false),
            onFeedTap: {},
            onFeedLongPress: {},
            onDiaperUpdateTap: {},
            onDiaperEditTap: {},
            onNameTap: {},
            onLastFeedTap: { _ in }
        )
        .environment(\.managedObjectContext, persistenceController.viewContext)
        .environment(\.locale, Locale(identifier: "en_US"))
        .preferredColorScheme(.light)

        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "Default"
        )
    }

    @MainActor
    func testBabyStatusViewWarningState() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let baby = makeBabyProfile(now: now, feedHoursAgo: 7, diaperMinutesAgo: 90)

        let view = BabyStatusView(
            baby: baby,
            isFeedAnimating: .constant(true),
            isDiaperAnimating: .constant(true),
            onFeedTap: {},
            onFeedLongPress: {},
            onDiaperUpdateTap: {},
            onDiaperEditTap: {},
            onNameTap: {},
            onLastFeedTap: { _ in }
        )
        .environment(\.managedObjectContext, persistenceController.viewContext)
        .environment(\.locale, Locale(identifier: "en_US"))
        .preferredColorScheme(.light)

        assertSnapshot(
            of: view,
            as: .image(layout: .device(config: .iPhone13Pro)),
            named: "Warnings"
        )
    }

    private func makeBabyProfile(now: Date, feedHoursAgo: TimeInterval = 2, diaperMinutesAgo: TimeInterval = 30) -> BabyProfile {
        let context = persistenceController.viewContext
        let baby = BabyProfile(context: context, name: "Baby A")
        baby.feedTerm = 3 * 3600

        let feedSession = FeedSession(context: context, startTime: now.addingTimeInterval(-(feedHoursAgo * 3600)))
        feedSession.endTime = feedSession.startTime.addingTimeInterval(900)
        feedSession.amount = Measurement(value: 120, unit: .milliliters)
        feedSession.profile = baby

        let diaperChange = DiaperChange(
            context: context,
            timestamp: now.addingTimeInterval(-(diaperMinutesAgo * 60)),
            type: .pee
        )
        diaperChange.profile = baby

        try? context.save()

        return baby
    }
}

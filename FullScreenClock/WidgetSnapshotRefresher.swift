// WidgetSnapshotRefresher.swift
import Foundation
import CoreData
import Model
import WidgetKit

public func refreshBabyWidgetSnapshots(using context: NSManagedObjectContext) {
    context.perform {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        // We only need IDs/names/feedTerm but fetching full objects is fine here.
        let babies = (try? context.fetch(request)) ?? []

        let now = Date()
        for baby in babies {
            let id = baby.id
            let name = baby.name
            let timeScope = max(1, baby.feedTerm)

            let lastStart = baby.lastFeedSession?.startTime
            let totalProgress: Double = {
                guard let start = lastStart else { return 0 }
                return now.timeIntervalSince(start) / timeScope
            }()

            let inProgress = (baby.inProgressFeedSession != nil)
            let feedingProgress: Double = {
                if inProgress { return totalProgress }
                if let finished = baby.lastFinishedFeedSession,
                   let end = finished.endTime {
                    let duration = max(0, end.timeIntervalSince(finished.startTime))
                    return duration / timeScope
                }
                return 0
            }()

            let snapshot = WidgetBabySnapshot(
                id: id,
                name: name,
                totalProgress: totalProgress,
                feedingProgress: feedingProgress,
                updatedAt: now,
                feedTerm: timeScope,
                isFeeding: inProgress
            )
            WidgetCache.writeSnapshot(snapshot)
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "DashboardWidget")
    }
}

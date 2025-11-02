// WidgetSnapshotRefresher.swift
import Foundation
import SwiftData
import Model
import WidgetKit

public func refreshBabyWidgetSnapshots(using modelContext: ModelContext) {
    // Fetch all babies
    let descriptor = FetchDescriptor<BabyProfile>(sortBy: [])
    let babies = (try? modelContext.fetch(descriptor)) ?? []

    let now = Date()
    for baby in babies {
        let timeScope = max(1, baby.feedTerm) // guard divide-by-zero

        // totalProgress: elapsed since last start
        let lastStart = baby.lastFeedSession?.startTime
        let totalProgress: Double = {
            guard let start = lastStart else { return 0 }
            return (now.timeIntervalSince(start)) / timeScope
        }()

        // feedingProgress: in-progress mirrors totalProgress; else last finished duration / scope
        let feedingProgress: Double = {
            if baby.inProgressFeedSession != nil { return totalProgress }
            if let finished = baby.lastFinishedFeedSession, let end = finished.endTime {
                let duration = max(0, end.timeIntervalSince(finished.startTime))
                return duration / timeScope
            }
            return 0
        }()

        let snapshot = WidgetBabySnapshot(
            id: baby.id,
            name: baby.name,
            totalProgress: totalProgress,
            feedingProgress: feedingProgress,
            updatedAt: now
        )
        WidgetCache.writeSnapshot(snapshot)
    }

    // Reload only our widget kind
    WidgetCenter.shared.reloadTimelines(ofKind: "DashboardWidget")
}

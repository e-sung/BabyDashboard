import Foundation
import SwiftData

struct SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema([
            BabyProfile.self,
            FeedSession.self,
            DiaperChange.self,
        ])
        // Configure the container to use a shared App Group location
        let appGroupID = "group.sungdoo.fullscreenClock"
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Failed to get container URL for app group: \(appGroupID)")
        }
        let storeURL = url.appendingPathComponent("BabyMonitor.sqlite")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

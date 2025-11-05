import Foundation
import SwiftData

public struct SharedModelContainer {
    public static let container: ModelContainer = {
        let schema = Schema([
            BabyProfile.self,
            FeedSession.self,
            DiaperChange.self,
        ])

        #if DEBUG
            let appGroupID = "group.sungdoo.babyDashboard.dev"
            let containerID = "iCloud.sungdoo.babyDashboard.dev"
        #else
            let appGroupID = "group.sungdoo.babyDashboard"
            let containerID = "iCloud.sungdoo.babyDashboard"
        #endif
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Failed to get container URL for app group: \(appGroupID)")
        }

        // Local store in App Group (for potential sharing with extensions)
        let storeURL = url.appendingPathComponent("BabyDashboard.sqlite")

        // Enable CloudKit mirroring to your selected iCloud container’s private database
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .private(containerID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

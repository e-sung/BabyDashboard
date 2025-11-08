import Foundation
import CoreData

public final class PersistenceController {
    public static let shared = PersistenceController()
    public static let preview = PersistenceController(inMemory: true)

    public let container: NSPersistentCloudKitContainer

    @MainActor
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    public init(inMemory: Bool = false) {
        let model = Self.makeManagedObjectModel()
        container = NSPersistentCloudKitContainer(name: "Model", managedObjectModel: model)

        let description: NSPersistentStoreDescription

        if inMemory {
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
        } else {
            #if DEBUG
            let appGroupID = "group.sungdoo.babyDashboard.dev"
            let containerID = "iCloud.sungdoo.babyDashboard.dev"
            #else
            let appGroupID = "group.sungdoo.babyDashboard"
            let containerID = "iCloud.sungdoo.babyDashboard"
            #endif

            guard let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                fatalError("Failed to retrieve App Group container for \(appGroupID)")
            }

            let storeURL = baseURL.appendingPathComponent("BabyDashboardCoreData.sqlite")
            description = NSPersistentStoreDescription(url: storeURL)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
        }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved Core Data error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let bundle = Bundle(for: BundleToken.self)
        if let url = bundle.url(forResource: "Model", withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: url) {
            return model
        }
        if let url = bundle.url(forResource: "Model", withExtension: "mom"),
           let model = NSManagedObjectModel(contentsOf: url) {
            return model
        }
        fatalError("Unable to locate Core Data model named 'Model'")
    }

    private final class BundleToken {}
}

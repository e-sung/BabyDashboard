import Foundation
import CoreData
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

public final class PersistenceController {
    public static let shared = PersistenceController()
    public static let preview = PersistenceController(inMemory: true)

    public let container: NSPersistentCloudKitContainer
    public let cloudKitContainer: CKContainer

    @MainActor
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    public init(inMemory: Bool = false) {
        let model = Self.makeManagedObjectModel()
        container = NSPersistentCloudKitContainer(name: "Model", managedObjectModel: model)

        #if DEBUG
        let defaultAppGroupID = "group.sungdoo.babyDashboard.dev"
        let defaultContainerID = "iCloud.sungdoo.babyDashboard.dev"
        #else
        let defaultAppGroupID = "group.sungdoo.babyDashboard"
        let defaultContainerID = "iCloud.sungdoo.babyDashboard"
        #endif

        if inMemory || ProcessInfo.processInfo.arguments.contains("-UITest") {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            cloudKitContainer = CKContainer(identifier: defaultContainerID)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [description]
        } else {
            let appGroupID = defaultAppGroupID
            let containerID = defaultContainerID

            guard let baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                fatalError("Failed to retrieve App Group container for \(appGroupID)")
            }

            cloudKitContainer = CKContainer(identifier: containerID)

            let privateStoreURL = baseURL.appendingPathComponent("BabyDashboardCoreData.sqlite")
            let sharedStoreURL = baseURL.appendingPathComponent("BabyDashboardCoreData-Shared.sqlite")

            let privateDescription = NSPersistentStoreDescription(url: privateStoreURL)
            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
            privateOptions.databaseScope = .private
            privateDescription.cloudKitContainerOptions = privateOptions
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            let sharedDescription = NSPersistentStoreDescription(url: sharedStoreURL)
            sharedDescription.configuration = "Shared"
            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
            sharedOptions.databaseScope = .shared
            sharedDescription.cloudKitContainerOptions = sharedOptions
            sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.persistentStoreDescriptions = [privateDescription, sharedDescription]
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved Core Data error: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        if container.viewContext.undoManager == nil {
            container.viewContext.undoManager = UndoManager()
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Seeding for UI Tests
        if ProcessInfo.processInfo.arguments.contains("-UITest") {
            seedDataForUITests()
        }
    }
    
    private func seedDataForUITests() {
        let context = container.viewContext
        let args = ProcessInfo.processInfo.arguments
        
        var feedTerm: Double?
        if let termArg = args.first(where: { $0.hasPrefix("-FeedTerm:") }),
           let termValue = Double(termArg.dropFirst("-FeedTerm:".count)) {
            feedTerm = termValue
        }
        
        if args.contains("-Seed:babyAddedWithoutLog") {
            let baby = BabyProfile(context: context, name: "Baby A")
            if let feedTerm { baby.feedTerm = feedTerm }
        } else if args.contains("-Seed:babiesWithSomeLogs") {
            let baby = BabyProfile(context: context, name: "Baby A")
            if let feedTerm { baby.feedTerm = feedTerm }
            
            // Add some logs
            let now = Date.current
            let session = FeedSession(context: context, startTime: now.addingTimeInterval(-3600)) // 1 hour ago
            session.endTime = now.addingTimeInterval(-3000)
            session.amount = Measurement(value: 120, unit: .milliliters)
            session.profile = baby
            
            let diaper = DiaperChange(context: context, timestamp: now.addingTimeInterval(-1800), type: .pee) // 30 mins ago
            diaper.profile = baby
        } else if args.contains("-Seed:babyWithSearchableHistory") {
            // Baby A with various events for search testing
            let babyA = BabyProfile(context: context, name: "Baby A")
            if let feedTerm { babyA.feedTerm = feedTerm }
            
            // Baby B for multi-baby filtering
            let babyB = BabyProfile(context: context, name: "Baby B")
            if let feedTerm { babyB.feedTerm = feedTerm }
            
            let now = Date.current
            
            // Create custom event types
            let napType = CustomEventType(context: context, name: "Nap", emoji: "😴")
            let bathType = CustomEventType(context: context, name: "Bath", emoji: "🛁")
            let medicineType = CustomEventType(context: context, name: "Medicine", emoji: "💊")
            
            // Baby A events
            let feed1 = FeedSession(context: context, startTime: now.addingTimeInterval(-7200)) // 2 hours ago
            feed1.endTime = now.addingTimeInterval(-6600)
            feed1.amount = Measurement(value: 100, unit: .milliliters)
            feed1.memoText = "Good appetite #morning"
            feed1.profile = babyA
            
            let feed2 = FeedSession(context: context, startTime: now.addingTimeInterval(-3600)) // 1 hour ago
            feed2.endTime = now.addingTimeInterval(-3000)
            feed2.amount = Measurement(value: 80, unit: .milliliters)
            feed2.memoText = "A bit fussy #tired"
            feed2.profile = babyA
            
            let pee1 = DiaperChange(context: context, timestamp: now.addingTimeInterval(-5400), type: .pee)
            pee1.memoText = "Normal"
            pee1.profile = babyA
            
            let poo1 = DiaperChange(context: context, timestamp: now.addingTimeInterval(-1800), type: .poo)
            poo1.memoText = "After feeding"
            poo1.profile = babyA
            
            let nap1 = CustomEvent(context: context, timestamp: now.addingTimeInterval(-4800),
                                  eventTypeName: napType.name, eventTypeEmoji: napType.emoji)
            nap1.memoText = "Slept well #goodsleep"
            nap1.profile = babyA
            
            let bath1 = CustomEvent(context: context, timestamp: now.addingTimeInterval(-2400),
                                   eventTypeName: bathType.name, eventTypeEmoji: bathType.emoji)
            bath1.memoText = "Quick bath before bed"
            bath1.profile = babyA
            
            // Baby B events
            let feed3 = FeedSession(context: context, startTime: now.addingTimeInterval(-4000))
            feed3.endTime = now.addingTimeInterval(-3400)
            feed3.amount = Measurement(value: 90, unit: .milliliters)
            feed3.profile = babyB
            
            let pee2 = DiaperChange(context: context, timestamp: now.addingTimeInterval(-2000), type: .pee)
            pee2.profile = babyB
            
            let medicine1 = CustomEvent(context: context, timestamp: now.addingTimeInterval(-1200),
                                       eventTypeName: medicineType.name, eventTypeEmoji: medicineType.emoji)
            medicine1.memoText = "Vitamin D drops"
            medicine1.profile = babyB
        }
        
        try? context.save()
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

// MARK: - CloudKit Sharing Helpers

public extension PersistenceController {
    struct SharePreparationResult {
        public let share: CKShare
        public let container: CKContainer
    }

    enum SharePreparationError: Error {
        case missingResult
    }

    @MainActor
    func prepareShare(for baby: BabyProfile) async throws -> SharePreparationResult {
        let objectID = baby.objectID
        var existingShare: CKShare?
        do {
            let shares = try fetchShares(matching: [objectID])
            existingShare = shares[objectID]
        } catch {
            debugPrint("[Sharing] fetchShares failed for \(baby.name): \(error)")
        }

        let container = self.container
        let viewContext = self.viewContext
        let babyName = baby.name

        return try await withCheckedThrowingContinuation { continuation in
            container.share([baby], to: existingShare) { _, share, ckContainer, error in
                Task { @MainActor in
                    if let share, let ckContainer {
                        share.publicPermission = .readWrite
                        share[CKShare.SystemFieldKey.title] = babyName as CKRecordValue
                        if #available(iOS 26.0, *) {
                            share.allowsAccessRequests = true
                        }
                        if let data = Self.defaultShareThumbnailData() {
                            share[CKShare.SystemFieldKey.thumbnailImageData] = data as CKRecordValue
                        }
                        do {
                            try viewContext.save()
                        } catch {
                            debugPrint("[Sharing] Failed to save context after preparing share: \(error)")
                        }
                        debugPrint("[Sharing] Prepared share for \(babyName)")
                        continuation.resume(returning: SharePreparationResult(share: share, container: ckContainer))
                    } else if let error {
                        debugPrint("[Sharing] Failed to prepare share for \(babyName): \(error)")
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: SharePreparationError.missingResult)
                    }
                }
            }
        }
    }

    @MainActor
    func fetchShares(matching objectIDs: [NSManagedObjectID]) throws -> [NSManagedObjectID: CKShare] {
        guard !objectIDs.isEmpty else { return [:] }
        return try container.fetchShares(matching: objectIDs)
    }

    private static func defaultShareThumbnailData() -> Data? {
        #if canImport(UIKit)
        let configuration = UIImage.SymbolConfiguration(pointSize: 60, weight: .bold)
        let image = UIImage(systemName: "baby.fill", withConfiguration: configuration)?
            .withTintColor(.systemPink, renderingMode: .alwaysOriginal)
        return image?.pngData()
        #else
        return nil
        #endif
    }

    @MainActor func existingShare(for baby: BabyProfile) -> CKShare? {
        (try? fetchShares(matching: [baby.objectID]))?[baby.objectID]
    }
}

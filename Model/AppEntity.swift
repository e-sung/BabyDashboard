import Foundation
import AppIntents
import CoreData
import Model

struct BabyProfileEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Baby"
    static var defaultQuery = BabyProfileQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct BabyProfileQuery: EntityQuery {
    @MainActor
    private var viewContext: NSManagedObjectContext {
        PersistenceController.shared.viewContext
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [BabyProfileEntity] {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        let profiles = try viewContext.fetch(request)
        return profiles
            .filter { identifiers.contains($0.id) }
            .map { BabyProfileEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [BabyProfileEntity] {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(BabyProfile.createdAt), ascending: true)]
        let profiles = try viewContext.fetch(request)
        return profiles.map { BabyProfileEntity(id: $0.id, name: $0.name) }
    }
}

enum DiaperTypeAppEnum: String, AppEnum {
    case pee, poo

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Diaper Type"
    static var caseDisplayRepresentations: [DiaperTypeAppEnum: DisplayRepresentation] = [
        .pee: "Pee",
        .poo: "Poo"
    ]
}

enum FeedTypeAppEnum: String, AppEnum {
    case babyFormula
    case breastFeed
    case solid

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Feed Type"
    static var caseDisplayRepresentations: [FeedTypeAppEnum: DisplayRepresentation] = [
        .babyFormula: "🍼 Baby Formula",
        .breastFeed: "🤱 Breastfeed",
        .solid: "🍲 Solid Food"
    ]
}

struct CustomEventTypeEntity: AppEntity {
    let id: UUID
    let name: String
    let emoji: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Custom Event Type"
    static var defaultQuery = CustomEventTypeQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(emoji) \(name)")
    }
}

struct CustomEventTypeQuery: EntityQuery {
    @MainActor
    private var viewContext: NSManagedObjectContext {
        PersistenceController.shared.viewContext
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CustomEventTypeEntity] {
        let request: NSFetchRequest<CustomEventType> = CustomEventType.fetchRequest()
        let eventTypes = try viewContext.fetch(request)
        return eventTypes
            .filter { identifiers.contains($0.id) }
            .compactMap { eventType in
                return CustomEventTypeEntity(
                    id: eventType.id,
                    name: eventType.name,
                    emoji: eventType.emoji,
                )
            }
    }

    @MainActor
    func suggestedEntities() async throws -> [CustomEventTypeEntity] {
        let request: NSFetchRequest<CustomEventType> = CustomEventType.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(CustomEventType.createdAt), ascending: true)]
        let eventTypes = try viewContext.fetch(request)
        return eventTypes.compactMap { eventType in
            return CustomEventTypeEntity(
                id: eventType.id,
                name: eventType.name,
                emoji: eventType.emoji,
            )
        }
    }
}

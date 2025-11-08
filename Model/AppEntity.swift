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

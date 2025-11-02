//
//  AppEntity.swift
//  Model
//
//  Created by 류성두 on 11/3/25.
//

import Foundation
import AppIntents
import SwiftData
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
    // Use the shared model container to fetch data.
    @MainActor
    private var modelContext: ModelContext {
        SharedModelContainer.container.mainContext
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [BabyProfileEntity] {
        let descriptor = FetchDescriptor<BabyProfile>(
            predicate: #Predicate { identifiers.contains($0.id) }
        )
        let profiles = try? modelContext.fetch(descriptor)
        return (profiles ?? []).map { BabyProfileEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [BabyProfileEntity] {
        let descriptor = FetchDescriptor<BabyProfile>(sortBy: [SortDescriptor(\BabyProfile.name)])
        let profiles = try? modelContext.fetch(descriptor)
        return (profiles ?? []).map { BabyProfileEntity(id: $0.id, name: $0.name) }
    }

}

enum DiaperTypeAppEnum: String, AppEnum {
    case pee, poo

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Diaper Type"
    public static var caseDisplayRepresentations: [DiaperTypeAppEnum: DisplayRepresentation] = [
        .pee: "Pee",
        .poo: "Poo"
    ]
}

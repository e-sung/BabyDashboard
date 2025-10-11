
import AppIntents
import Foundation

private let suiteName = "group.sungdoo.fullscreenClock"

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
    func entities(for identifiers: [UUID]) async throws -> [BabyProfileEntity] {
        let profiles = loadProfiles()
        return profiles.filter { identifiers.contains($0.id) }.map { BabyProfileEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [BabyProfileEntity] {
        let profiles = loadProfiles()
        return profiles.map { BabyProfileEntity(id: $0.id, name: $0.name) }
    }
    
    func defaultResult() async -> BabyProfileEntity? {
        return try? await suggestedEntities().first
    }

    private func loadProfiles() -> [BabyProfile] {
        if let sharedDefaults = UserDefaults(suiteName: suiteName),
           let data = sharedDefaults.data(forKey: "babyProfiles"),
           let decodedProfiles = try? JSONDecoder().decode([BabyProfile].self, from: data) {
            return decodedProfiles
        } else {
            return [
                BabyProfile(id: UUID(), name: "연두"),
                BabyProfile(id: UUID(), name: "초원")
            ]
        }
    }
}

struct UpdateFeedingTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Feeding Time"
    static var description = IntentDescription("Records the last feeding time for a baby.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Baby")
    var baby: BabyProfileEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        if let sharedDefaults = UserDefaults(suiteName: suiteName) {
            let now = Date()
            sharedDefaults.set(now, forKey: baby.id.uuidString)
            ContentViewModel.shared.updateFeedingTime(for: baby.id)
            let timeString = now.formatted(date: .omitted, time: .shortened)
            return .result(value: "\(baby.name) feeding time updated to \(timeString)")
        }
        return .result(value: "Failed to update feeding time.")
    }
}

struct BabyMonitorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UpdateFeedingTimeIntent(),
            phrases: [
                "Update feeding time for \(.applicationName)"
            ],
            shortTitle: "Log Feeding Time",
            systemImageName: "baby.bottle.fill"
        )
    }
}


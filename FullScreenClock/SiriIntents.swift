import AppIntents
import Foundation
import SwiftData

// MARK: - App Entity & Query

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
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Diaper Type"
    static var caseDisplayRepresentations: [DiaperTypeAppEnum: DisplayRepresentation] = [
        .pee: "Pee",
        .poo: "Poo"
    ]
}

// MARK: - Intents

struct StartFeedingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Feeding"
    static var description = IntentDescription("Starts a new feeding session for a baby.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Baby")
    var baby: BabyProfileEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let profile = await fetchProfile(for: baby.id) else {
            return .result(value: String(localized: "Could not find baby."))
        }
        ContentViewModel.shared.startFeeding(for: profile)
        return .result(value: String(localized: "Started feeding \(baby.name)."))
    }
}

struct UpdateDiaperTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Diaper Time"
    static var description = IntentDescription("Records the last diaper change time for a baby.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Baby")
    var baby: BabyProfileEntity
    
    @Parameter(title: "Type", default: .pee)
    var type: DiaperTypeAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let profile = await fetchProfile(for: baby.id) else {
            return .result(value: String(localized: "Could not find baby."))
        }
        
        let diaperType = DiaperType(rawValue: type.rawValue) ?? .pee
        ContentViewModel.shared.logDiaperChange(for: profile, type: diaperType)
        
        let timeString = Date().formatted(date: .omitted, time: .shortened)
        return .result(value: String(localized: "Logged \(type.rawValue) diaper for \(baby.name) at \(timeString)."))
    }
}

struct FinishFeedingIntent: AppIntent {
    static var title: LocalizedStringResource = "Finish Feeding"
    static var description = IntentDescription("Finishes an in-progress feeding session for a baby and records the amount.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Baby")
    var baby: BabyProfileEntity?

    @Parameter(title: "Amount", requestValueDialog: "How much did you feed?")
    var amount: Double

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let targetProfile: BabyProfile

        if let specifiedBaby = self.baby {
            guard let profile = await fetchProfile(for: specifiedBaby.id) else {
                return .result(value: String(localized: "Could not find baby."))
            }
            targetProfile = profile
        } else {
            let babiesWithInProgressSessions = await findBabiesWithInProgressSessions()
            if babiesWithInProgressSessions.isEmpty {
                return .result(value: String(localized: "No one is currently feeding."))
            } else if babiesWithInProgressSessions.count == 1 {
                targetProfile = babiesWithInProgressSessions.first!
            } else {
                throw $baby.needsDisambiguationError(among: babiesWithInProgressSessions.map {
                    BabyProfileEntity(id: $0.id, name: $0.name)
                }, dialog: "Which baby did you mean?")
            }
        }
        
        guard targetProfile.inProgressFeedSession != nil else {
            return .result(value: String(localized: "No feeding session in progress for \(targetProfile.name)."))
        }

        let unit: UnitVolume = (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
        let measurement = Measurement(value: amount, unit: unit)
        ContentViewModel.shared.finishFeeding(for: targetProfile, amount: measurement)

        return .result(value: "\(targetProfile.name), \(amount), \(unit.symbol)")
    }
}

// MARK: - Helper Functions for Intents

@MainActor
private func fetchProfile(for id: UUID) async -> BabyProfile? {
    let context = SharedModelContainer.container.mainContext
    let descriptor = FetchDescriptor<BabyProfile>(predicate: #Predicate { $0.id == id })
    return try? context.fetch(descriptor).first
}

@MainActor
private func findBabiesWithInProgressSessions() async -> [BabyProfile] {
    // Query FeedSession directly to avoid complex to-many relationship predicates.
    let context = SharedModelContainer.container.mainContext
    let descriptor = FetchDescriptor<FeedSession>(predicate: #Predicate { $0.endTime == nil })
    guard let sessions = try? context.fetch(descriptor) else { return [] }

    var seen = Set<UUID>()
    var result: [BabyProfile] = []
    for session in sessions {
        if let baby = session.profile, !seen.contains(baby.id) {
            seen.insert(baby.id)
            result.append(baby)
        }
    }
    return result
}

// MARK: - Shortcuts Provider

struct BabyMonitorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFeedingIntent(),
            phrases: [
                "Start feeding for \(.applicationName)"
            ],
            shortTitle: "Start Feeding",
            systemImageName: "baby.bottle.fill"
        )
        AppShortcut(
            intent: FinishFeedingIntent(),
            phrases: [
                "Finish feeding for \(.applicationName)"
            ],
            shortTitle: "Finish Feeding",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: UpdateDiaperTimeIntent(),
            phrases: [
                "Update diaper time for \(.applicationName)"
            ],
            shortTitle: "Log Diaper Change",
            systemImageName: "record.circle"
        )
    }
}

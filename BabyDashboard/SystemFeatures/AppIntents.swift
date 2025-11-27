import AppIntents
import Foundation
import CoreData
import Model
import Playgrounds

#Playground {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let date = formatter.date(from: "2025-01-01 00:00:00")
}

// MARK: - Intents

struct StartFeedingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Feeding"
    static var description = IntentDescription("Starts a new feeding session for a baby.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Baby")
    var baby: BabyProfileEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let profile = await fetchProfile(for: baby.id) else {
            let dialog: LocalizedStringResource = "Could not find baby."
            return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
        }
        ContentViewModel.shared.startFeeding(for: profile)
        let dialog: LocalizedStringResource = "Started feeding \(baby.name)."
        return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
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
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let profile = await fetchProfile(for: baby.id) else {
            let dialog: LocalizedStringResource = "Could not find baby."
            return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
        }
        
        let diaperType = DiaperType(rawValue: type.rawValue) ?? .pee
        ContentViewModel.shared.logDiaperChange(for: profile, type: diaperType)
        
        // Localized diaper type name for interpolation
        let localizedTypeName: LocalizedStringResource = {
            switch type {
            case .pee: return "Pee"
            case .poo: return "Poo"
            }
        }()
        
        let dialog: LocalizedStringResource = "Logged \(localizedTypeName) diaper for \(baby.name)"
        return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
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
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let targetProfile: BabyProfile

        if let specifiedBaby = self.baby {
            guard let profile = await fetchProfile(for: specifiedBaby.id) else {
                let dialog: LocalizedStringResource = "Could not find baby."
                return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
            }
            targetProfile = profile
        } else {
            let babiesWithInProgressSessions = await findBabiesWithInProgressSessions()
            if babiesWithInProgressSessions.isEmpty {
                let dialog: LocalizedStringResource = "No one is currently feeding."
                return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
            } else if babiesWithInProgressSessions.count == 1 {
                targetProfile = babiesWithInProgressSessions.first!
            } else {
                throw $baby.needsDisambiguationError(among: babiesWithInProgressSessions.map {
                    BabyProfileEntity(id: $0.id, name: $0.name)
                }, dialog: "Which baby did you mean?")
            }
        }
        
        guard targetProfile.inProgressFeedSession != nil else {
            let dialog: LocalizedStringResource = "No feeding session in progress for \(targetProfile.name)."
            return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
        }

        let unit: UnitVolume = (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
        let measurement = Measurement(value: amount, unit: unit)
        ContentViewModel.shared.finishFeeding(for: targetProfile, amount: measurement)

        let dialog: LocalizedStringResource = "Fed \(targetProfile.name) \(amount.formatted())."
        return .result(
            value: "\(targetProfile.name), \(amount), \(unit.symbol)",
            dialog: IntentDialog(dialog)
        )
    }
}

struct UndoLastActionIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last Change"
    static var description = IntentDescription("Undoes the most recent change.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let viewContext = PersistenceController.shared.viewContext
        if viewContext.undoManager?.canUndo == true {
            let dialog: LocalizedStringResource = "Undid the last change."
            viewContext.undo()
            return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
        } else {
            let dialog: LocalizedStringResource = "There is nothing to undo."
            return .result(value: String(localized: dialog), dialog: IntentDialog(dialog))
        }
    }
}

// MARK: - Helper Functions for Intents

@MainActor
private func fetchProfile(for id: UUID) async -> BabyProfile? {
    let context = PersistenceController.shared.viewContext
    let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    return try? context.fetch(request).first
}

@MainActor
private func findBabiesWithInProgressSessions() async -> [BabyProfile] {
    let context = PersistenceController.shared.viewContext
    let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
    request.predicate = NSPredicate(format: "endTime == nil")
    guard let sessions = try? context.fetch(request) else { return [] }

    var seen = Set<UUID>()
    var babies: [BabyProfile] = []
    for session in sessions {
        if let baby = session.profile, !seen.contains(baby.id) {
            seen.insert(baby.id)
            babies.append(baby)
        }
    }
    return babies
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
        AppShortcut(
            intent: UndoLastActionIntent(),
            phrases: [
                "Undo in \(.applicationName)"
            ],
            shortTitle: "Undo",
            systemImageName: "arrow.uturn.backward.circle"
        )
    }
}


import Foundation
import CoreData
import Combine
import Model

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var shareInfo: ShareController.ShareInfo = .unknown

    let profile: BabyProfile

    private let context: NSManagedObjectContext
    private let shareController: ShareController
    private var cancellables: Set<AnyCancellable> = []

    init(
        profile: BabyProfile,
        context: NSManagedObjectContext,
        shareController: ShareController
    ) {
        self.profile = profile
        self.context = context
        self.shareController = shareController

        shareInfo = shareController.shareInfo(for: profile)

        shareController.$shareInfoByObjectID
            .map { $0[profile.objectID] ?? .unknown }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                self?.shareInfo = info
            }
            .store(in: &cancellables)
    }

    var canDeleteProfile: Bool {
        shareInfo.role.allowsProfileEditing
    }

    func saveProfile(name: String, feedTerm: TimeInterval) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        profile.feedTerm = feedTerm
        profile.name = trimmed
        shareController.updateShareTitleIfNeeded(for: profile, newName: trimmed)
        shareController.refreshShareInfo(for: profile)

        do {
            try context.save()
            NearbySyncManager.shared.sendPing()
            refreshBabyWidgetSnapshots(using: context)
        } catch {
            debugPrint("Failed to save profile: \(error)")
        }
    }

    func deleteProfile() {
        guard canDeleteProfile else { return }
        shareController.clearShareInfo(for: profile)
        context.delete(profile)

        do {
            try context.save()
            NearbySyncManager.shared.sendPing()
            refreshBabyWidgetSnapshots(using: context)
        } catch {
            debugPrint("Failed to delete profile: \(error)")
        }
    }

    func refreshShareInfo() {
        shareController.refreshShareInfo(for: profile)
    }
}

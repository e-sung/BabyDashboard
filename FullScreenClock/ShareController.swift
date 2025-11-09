import Foundation
import CoreData
import CloudKit
import Model

@MainActor
final class ShareController: ObservableObject {
    static let shared = ShareController(context: PersistenceController.shared.viewContext)

    @Published private(set) var shareInfoByObjectID: [NSManagedObjectID: ShareInfo] = [:]
    @Published private(set) var hasParticipantRestrictions = false

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    struct ShareInfo: Equatable {
        let role: ShareRole
        let participantCount: Int
        let title: String?

        static let unknown = ShareInfo(role: .unknown, participantCount: 0, title: nil)
    }

    enum ShareRole: Equatable {
        case owner
        case participant
        case notShared
        case unknown

        var allowsProfileEditing: Bool {
            switch self {
            case .owner:
                return true
            default:
                return false
            }
        }
    }

    func primeShareInfoCache() {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        request.includesPendingChanges = true
        guard let babies = try? context.fetch(request), !babies.isEmpty else {
            shareInfoByObjectID = [:]
            hasParticipantRestrictions = false
            return
        }

        let ids = babies.map { $0.objectID }
        do {
            let shares = try PersistenceController.shared.fetchShares(matching: ids)
            var updated: [NSManagedObjectID: ShareInfo] = [:]
            for baby in babies {
                updated[baby.objectID] = shareInfo(from: shares[baby.objectID])
            }
            shareInfoByObjectID = updated
            updateParticipantRestrictionsFlag()
        } catch {
            debugPrint("Failed to prime share info: \(error)")
        }
    }

    func shareInfo(for baby: BabyProfile) -> ShareInfo {
        if let info = shareInfoByObjectID[baby.objectID] {
            return info
        }
        return refreshShareInfo(for: baby)
    }

    @discardableResult
    func refreshShareInfo(for baby: BabyProfile) -> ShareInfo {
        let info = shareInfoFromStore(for: baby)
        shareInfoByObjectID[baby.objectID] = info
        updateParticipantRestrictionsFlag()
        return info
    }

    func shareRole(for baby: BabyProfile) -> ShareRole {
        shareInfo(for: baby).role
    }

    func canEditProfile(_ baby: BabyProfile) -> Bool {
        shareRole(for: baby).allowsProfileEditing
    }

    func clearShareInfo(for baby: BabyProfile) {
        shareInfoByObjectID.removeValue(forKey: baby.objectID)
        updateParticipantRestrictionsFlag()
    }

    func clearShareInfo(forObjectID objectID: NSManagedObjectID) {
        shareInfoByObjectID.removeValue(forKey: objectID)
        updateParticipantRestrictionsFlag()
    }

    func updateShareTitleIfNeeded(for baby: BabyProfile, newName: String) {
        do {
            let shares = try PersistenceController.shared.fetchShares(matching: [baby.objectID])
            if let share = shares[baby.objectID] {
                share[CKShare.SystemFieldKey.title] = newName as CKRecordValue
            }
        } catch {
            debugPrint("Failed to update share title: \(error)")
        }
    }

    private func shareInfoFromStore(for baby: BabyProfile) -> ShareInfo {
        do {
            let shares = try PersistenceController.shared.fetchShares(matching: [baby.objectID])
            return shareInfo(from: shares[baby.objectID])
        } catch {
            debugPrint("Failed to fetch share info for \(baby.objectID): \(error)")
            return .unknown
        }
    }

    private func shareInfo(from share: CKShare?) -> ShareInfo {
        guard let share else {
            return ShareInfo(role: .notShared, participantCount: 0, title: nil)
        }
        let role: ShareRole = (share.currentUserParticipant?.role == .owner) ? .owner : .participant
        let acceptedParticipants = share.participants.filter { $0.acceptanceStatus == .accepted }
        let participantCount = max(0, acceptedParticipants.count - 1)
        let title = share[CKShare.SystemFieldKey.title] as? String
        return ShareInfo(role: role, participantCount: participantCount, title: title)
    }

    private func updateParticipantRestrictionsFlag() {
        hasParticipantRestrictions = shareInfoByObjectID.values.contains(where: { $0.role == .participant })
    }
}

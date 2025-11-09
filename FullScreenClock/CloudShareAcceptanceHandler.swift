import Foundation
import CloudKit
import Model

@MainActor
final class CloudShareAcceptanceHandler {
    static let shared = CloudShareAcceptanceHandler()

    private init() {}

    func accept(metadata: CKShare.Metadata) {
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        operation.qualityOfService = .userInitiated

        operation.perShareResultBlock = { metadata, result in
            let recordName: String = metadata.rootRecord?.recordID.recordName ?? "unknown"

            switch result {
            case .success:
                debugPrint("[Sharing] Accepted share with root \(recordName)")
            case .failure(let error):
                debugPrint("[Sharing] Failed to accept share \(recordName): \(error)")
            }
        }

        operation.acceptSharesResultBlock = { result in
            switch result {
            case .success:
                Task { @MainActor in
                    let context = PersistenceController.shared.viewContext
                    try? context.save()
                    refreshBabyWidgetSnapshots(using: context)
                }
            case .failure(let error):
                debugPrint("[Sharing] Accept shares completed with error: \(error)")
            }
        }

        PersistenceController.shared.cloudKitContainer.add(operation)
    }
}

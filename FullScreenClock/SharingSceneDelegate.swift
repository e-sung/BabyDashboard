import UIKit
import CloudKit

final class SharingSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        CloudShareAcceptanceHandler.shared.accept(metadata: cloudKitShareMetadata)
    }
}

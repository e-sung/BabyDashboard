import SwiftUI
import CloudKit
import CoreData
import Model
import UIKit

struct BabyShareSheet: UIViewControllerRepresentable {
    let baby: BabyProfile
    let onShareChange: () -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // Host a plain UIViewController; when it appears we present the right controller (activity vs. management)
    func makeUIViewController(context: Context) -> UIViewController {
        let host = CloudShareHostViewController()
        host.onDidAppear = { [weak host] in
            Task { @MainActor in
                guard let host else { return }
                do {
                    if let existingShare = PersistenceController.shared.existingShare(for: baby) {
                        let controller = UICloudSharingController(share: existingShare, container: PersistenceController.shared.cloudKitContainer)
                        configureAndPresent(controller, host: host, coordinator: context.coordinator)
                        context.coordinator.activeController = controller
                    } else {
                        let result = try await PersistenceController.shared.prepareShare(for: baby)
                        let controller = UICloudSharingController(share: result.share, container: result.container)
                        configureAndPresent(controller, host: host, coordinator: context.coordinator)
                        context.coordinator.activeController = controller
                    }
                } catch {
                    onError(error)
                    host.presentingViewController?.dismiss(animated: true)
                }
            }
        }
        context.coordinator.hostViewController = host
        return host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    // MARK: - Coordinator and Host

    final class CloudShareHostViewController: UIViewController {
        var onDidAppear: (() -> Void)?
        private var didRun = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Ensure we only kick off once
            guard !didRun else { return }
            didRun = true
            onDidAppear?()
        }
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate, UIAdaptivePresentationControllerDelegate {
        let parent: BabyShareSheet
        weak var hostViewController: UIViewController?
        var activeController: UICloudSharingController?

        init(parent: BabyShareSheet) {
            self.parent = parent
        }

        // MARK: - UICloudSharingControllerDelegate

        func itemTitle(for controller: UICloudSharingController) -> String? {
            parent.baby.name
        }

        func itemThumbnailData(for controller: UICloudSharingController) -> Data? {
            let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
            let image = UIImage(systemName: "baby.fill", withConfiguration: configuration)?
                .withTintColor(.systemPink, renderingMode: .alwaysOriginal)
            return image?.pngData()
        }

        func itemType(for controller: UICloudSharingController) -> String? {
            "com.sungdoo.babymonitor.baby"
        }

        func cloudSharingControllerDidSaveShare(_ c: UICloudSharingController) {
            parent.onShareChange()
            dismissSheet()
        }

        func cloudSharingControllerDidStopSharing(_ c: UICloudSharingController) {
            parent.onShareChange()
            dismissSheet()
        }

        func cloudSharingController(_ controller: UICloudSharingController, failedToSaveShareWithError error: Error) {
            parent.onError(error)
            dismissSheet()
        }

        // MARK: - UIAdaptivePresentationControllerDelegate

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // User cancelled the sharing controller
            dismissSheet()
        }

        // MARK: - Helpers

        private func dismissSheet() {
            hostViewController?.presentingViewController?.dismiss(animated: true)
        }
    }

    @MainActor
    private func configureAndPresent(
        _ controller: UICloudSharingController,
        host: UIViewController,
        coordinator: Coordinator
    ) {
        controller.delegate = coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.presentationController?.delegate = coordinator
        host.present(controller, animated: true)
    }

    @MainActor
    private func presentActivityController(
        using sharingController: UICloudSharingController,
        from host: UIViewController,
        coordinator: Coordinator
    ) {
        sharingController.delegate = coordinator
        sharingController.availablePermissions = [.allowReadWrite]
        let itemSource = sharingController.activityItemSource()
        let activity = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
        activity.completionWithItemsHandler = { [weak host] _, completed, _, error in
            if let error {
                onError(error)
            } else if completed {
                onShareChange()
            }
            host?.presentingViewController?.dismiss(animated: true)
        }
        if let popover = activity.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        host.present(activity, animated: true)
    }
}

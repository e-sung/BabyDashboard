// AppDelegate.swift
import UIKit
import SwiftData
import Model

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        // Let SwiftData/Core Data mirroring process the push first.
        // NSPersistentCloudKitContainer handles this automatically; we just schedule a refresh shortly after.
        let context = SharedModelContainer.container.mainContext

        // Give the import a brief moment to complete; then refresh widget snapshots.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshBabyWidgetSnapshots(using: context)
            completionHandler(.newData)
        }
    }
}

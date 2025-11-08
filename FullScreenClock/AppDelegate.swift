// AppDelegate.swift
import UIKit
import CoreData
import Model

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        // Let Core Data mirroring process the push first.
        let context = PersistenceController.shared.viewContext

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            refreshBabyWidgetSnapshots(using: context)
            completionHandler(.newData)
        }
    }
}

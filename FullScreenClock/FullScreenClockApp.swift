//
//  FullScreenClockApp.swift
//  FullScreenClock
//
//  Created by 류성두 on 10/1/25.
//

import SwiftUI
import Model
import CoreData // for NSPersistentStoreRemoteChange

@main
struct FullScreenClockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: ContentViewModel.shared
            )
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .environmentObject(settings)
            .preferredColorScheme(.dark)
            .task {
                // Start nearby sync on launch
                NearbySyncManager.shared.start()

                // Build initial widget snapshots at launch
                refreshBabyWidgetSnapshots(using: persistenceController.viewContext)

                // Observe remote-change imports from CloudKit mirroring
                NotificationCenter.default.addObserver(
                    forName: .NSPersistentStoreRemoteChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    // When Core Data imports from CloudKit, refresh widget cache
                    Task { @MainActor in
                        refreshBabyWidgetSnapshots(using: persistenceController.viewContext)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let context = persistenceController.viewContext
                try? context.save()
                NearbySyncManager.shared.sendPing()

                // Refresh widget snapshots on foreground
                refreshBabyWidgetSnapshots(using: context)
            }
        }
    }
}

//
//  FullScreenClockApp.swift
//  FullScreenClock
//
//  Created by 류성두 on 10/1/25.
//

import SwiftUI
import SwiftData
import Model
import CoreData // for NSPersistentStoreRemoteChange

@main
struct FullScreenClockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: ContentViewModel.shared
            )
            .environmentObject(settings)
            .preferredColorScheme(.dark)
            .task {
                // Start nearby sync on launch
                NearbySyncManager.shared.start()

                // Build initial widget snapshots at launch
                let context = SharedModelContainer.container.mainContext
                refreshBabyWidgetSnapshots(using: context)

                // Observe remote-change imports from CloudKit mirroring
                NotificationCenter.default.addObserver(
                    forName: .NSPersistentStoreRemoteChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    // When SwiftData/Core Data imports from CloudKit, refresh widget cache
                    refreshBabyWidgetSnapshots(using: context)
                }
            }
        }
        .modelContainer(SharedModelContainer.container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let context = SharedModelContainer.container.mainContext
                try? context.save()
                NearbySyncManager.shared.sendPing()

                // Refresh widget snapshots on foreground
                refreshBabyWidgetSnapshots(using: context)
            }
        }
    }
}

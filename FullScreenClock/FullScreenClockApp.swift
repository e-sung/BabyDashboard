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

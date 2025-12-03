//
//  BabyDashboardApp.swift
//  BabyDashboard
//
//  Created by 류성두 on 10/1/25.
//

import SwiftUI
import Model
import CoreData // for NSPersistentStoreRemoteChange

@main
struct BabyDashboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainView(
                viewModel: MainViewModel.shared
            )
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .environmentObject(settings)
            .task {
                // Start nearby sync on launch
                NearbySyncManager.shared.start()
            }
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-FastAnimations") {
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .forEach { window in
                            window.layer.speed = 100
                        }
                }
            }
            .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let context = persistenceController.viewContext
                try? context.save()
                
                // Re-establish any closed MultipeerConnectivity sessions on foreground
                NearbySyncManager.shared.start()

                // Optionally ping peers after restarting
                NearbySyncManager.shared.sendPing()

                // Refresh widget snapshots on foreground
                refreshBabyWidgetSnapshots(using: context)
            } else if newPhase == .background {
                // Stop nearby sync when moving to background to clean up resources
                NearbySyncManager.shared.stop()
            }
        }
    }
}

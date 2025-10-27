//
//  FullScreenClockApp.swift
//  FullScreenClock
//
//  Created by 류성두 on 10/1/25.
//

import SwiftUI
import SwiftData

@main
struct FullScreenClockApp: App {
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
            }
        }
        .modelContainer(SharedModelContainer.container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // When app becomes active, keep the model layer warm
                let context = SharedModelContainer.container.mainContext
                try? context.save()
                // Optionally ping peers to wake them
                NearbySyncManager.shared.sendPing()
            }
        }
    }
}

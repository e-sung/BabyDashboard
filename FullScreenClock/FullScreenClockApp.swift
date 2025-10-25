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

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: ContentViewModel.shared
            )
            .environmentObject(settings)
        }
        .modelContainer(SharedModelContainer.container)
    }
}

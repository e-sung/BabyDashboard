//
//  BabyDashboardApp.swift
//  BabyDashboard
//
//  Created by 류성두 on 10/1/25.
//

import SwiftUI
import Model
import CoreData // for NSPersistentStoreRemoteChange
import StoreKit

@main
struct BabyDashboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings = AppSettings()
    @StateObject private var forceUpdateManager = ForceUpdateManager()
    @Environment(\.scenePhase) private var scenePhase

    private let persistenceController = PersistenceController.shared
    
    private enum RootTab: Hashable {
        case dashboard
        case history
        case analysis
        case settings
    }
    
    @State private var selectedTab: RootTab = .dashboard
    @State private var hasRequestedReviewFromAnalysis = false

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                MainView(
                    viewModel: MainViewModel.shared
                )
                .tag(RootTab.dashboard)
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

                NavigationStack {
                    HistoryView()
                }
                .tag(RootTab.history)
                .tabItem {
                    Label("History", systemImage: "clock")
                }

                NavigationStack {
                    HistoryAnalysisView()
                }
                .tag(RootTab.analysis)
                .tabItem {
                    Label("Analysis", systemImage: "chart.xyaxis.line")
                }

                NavigationStack {
                    SettingsView(settings: settings, shareController: .shared)
                }
                .tag(RootTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .environment(\.managedObjectContext, persistenceController.viewContext)
            .environmentObject(settings)
            .task {
                // Check for force update on launch
                await forceUpdateManager.checkForUpdate()
                
                // Start nearby sync on launch
                NearbySyncManager.shared.start()
            }
            .fullScreenCover(isPresented: $forceUpdateManager.updateRequired) {
                ForceUpdateView()
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
            .applyDynamicTypeSize(settings.preferredFontScale.dynamicTypeSize)
            .preferredColorScheme(.dark)
            .onChange(of: selectedTab) { oldValue, newValue in
                if oldValue == .analysis,
                   newValue == .dashboard,
                   !hasRequestedReviewFromAnalysis {
                    Task { @MainActor in
                        ReviewRequestManager.shared.requestReviewIfEligible(
                            context: persistenceController.viewContext,
                            requestReview: {
                                #if canImport(UIKit)
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                    AppStore.requestReview(in: scene)
                                }
                                #endif
                            }
                        )
                    }
                    hasRequestedReviewFromAnalysis = true
                }
            }
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


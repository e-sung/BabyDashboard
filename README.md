# Baby Dashboard

SwiftUI dashboard for tracking baby care in real time: start/finish feedings, log diaper changes, view history/analysis, and keep multiple caregivers in sync via CloudKit sharing, widgets, App Intents, and nearby peer pings.

## Architecture at a Glance
- Core UI: `BabyDashboard/MainView/MainView.swift` renders one or two baby tiles, drives sheets for editing feeds/diapers/profiles, surfaces history/analysis/settings, and shows toast/highlight feedback when babies are added or removed (including from sharing).
- Business logic: `BabyDashboard/MainView/MainViewModel.swift` owns clock state, feed/diaper mutations, lightweight animations, persistence saves, widget refreshes, and nearby sync pings.
- System hooks: `BabyDashboard/SystemFeatures/AppIntents.swift` exposes App Intents (Start/Finish Feeding, Update Diaper Time, Undo) for Siri/Shortcuts, reusing `MainViewModel.shared` and Core Data lookups.
- Persistence: `Model/PersistenceController.swift` sets up the NSPersistentCloudKitContainer (private + shared stores, App Group paths, history tracking, undo manager) and seeds in-memory stores for previews/tests.
- Sync/sharing: `SystemFeatures/ShareController.swift` manages CloudKit shares per baby; `SystemFeatures/NearbySyncManager.swift` keeps peers warm with MultipeerConnectivity pings; `SystemFeatures/WidgetSnapshotRefresher.swift` updates widget timelines.
- Data model: `Model/Models.swift` defines Core Data entities (BabyProfile, FeedSession, DiaperChange) plus helpers like `inProgressFeedSession`, `lastFinishedFeedSession`, and unit-safe feed amounts.

## Running the App
1) Open `BabyDashboard.xcodeproj` in Xcode (targets: BabyDashboard, DashboardWidget).  
2) Select the `BabyDashboard` scheme and run on an iOS simulator/device.  
3) App Group/CloudKit IDs are set for dev vs prod in `PersistenceController`; no third-party dependencies are required.

## Key Behaviors
- Feeding: taps on a baby start or finish a feed, prompting for amount (uses locale-aware volume units). Long-press cancels an in-progress feed.
- Diaper changes: quick log via confirmation dialog; time can be edited through the diaper sheet.
- History/analysis/settings: exposed via the toolbar; history edit sheets allow adjusting past feeds/diapers.
- Toasts/highlights: new/removed babies trigger UI feedback and share cache refreshes; animations respect Reduce Motion.
- Sharing/sync: Core Data + CloudKit mirroring for shared babies; nearby peers get `syncPing` messages to encourage timely saves; widget snapshots are refreshed on changes and foregrounding.
- Shortcuts: App Shortcuts map to intents for voice/automation; Finish Feeding can disambiguate babies with active sessions.

## Testing Notes
- XCTest plans live in the repo (`BabyDashboard.xctestplan`, `BabyDashboardTestsOnCI.xctestplan`); run via Xcode or `xcodebuild test` against the `BabyDashboard` scheme.
- UI tests can seed Core Data using launch arguments defined in `PersistenceController.seedDataForUITests()` (e.g., `-UITest -Seed:babiesWithSomeLogs -FeedTerm:7200`).

## Tips for Contributors/AI Agents
- Use `MainViewModel.shared` for actions so App Intents and UI stay consistent.
- Persist changes with the provided Core Data context and call `refreshBabyWidgetSnapshots(using:)` if you add new write paths that affect widgets.
- Respect CloudKit sharing roles: edits to baby profiles should check `ShareController.canEditProfile`.
- Locale/unit handling matters for feed amounts; rely on `Measurement<UnitVolume>` helpers in the model.

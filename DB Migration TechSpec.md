# DB Migration TechSpec

## Summary
Move the BabyMonitor persistence stack from SwiftData to Core Data so we can opt into CloudKit sharing. The migration replaces the `SharedModelContainer` `ModelContainer` with an `NSPersistentCloudKitContainer` configured for the existing App Group location and CloudKit containers, rewrites model types as `NSManagedObject` subclasses, and updates all UI, intents, services, and widgets to use Core Data APIs. Because the app has not shipped, we can drop the existing SQLite file and do not need to backfill user data.

## Current State

- **Persistence stack**
  - Defined in `Model/SharedModelContainer.swift`. Builds a SwiftData `ModelContainer` with schema `[BabyProfile, FeedSession, DiaperChange]`.
  - Store URL: `BabyDashboard.sqlite` inside the App Group container resolved at runtime.
  - Cloud sync: `ModelConfiguration` mirrors to the private database of the CloudKit container (`.private(containerID)`).
  - Debug vs Release IDs (wired via `#if DEBUG` in `SharedModelContainer` and `AppGroupDefaults`, and surfaced to Info.plist via `Config/*.xcconfig`):
    - Debug: `APP_GROUP_ID = group.sungdoo.babyDashboard.dev`, `ICLOUD_CONTAINER_ID = iCloud.sungdoo.babyDashboard.dev`.
    - Release: `APP_GROUP_ID = group.sungdoo.babyDashboard`, `ICLOUD_CONTAINER_ID = iCloud.sungdoo.babyDashboard`.
  - `WidgetCache` persists JSON snapshots to the same App Group directory (`WidgetCache` folder).
  - `appGroupUserDefaults()` returns the App Group user defaults suite using the same identifiers.

- **Model layer**
  - `Model/Models.swift` declares SwiftData `@Model` classes (`BabyProfile`, `FeedSession`, `DiaperChange`) with relationships, computed helpers, and transient properties (`amount`, `isInProgress`, `hashtags`).
  - `DiaperType` is a `Codable` `enum` stored via SwiftData.

- **UI bindings**
  - `FullScreenClockApp.swift` injects `.modelContainer(SharedModelContainer.container)` into the scene.
  - Most views pull `@Environment(\.modelContext)` and use `@Query` to populate data (e.g., `ContentView`, `HistoryView`, `HistoryEditView`, `FeedSessionEditView`, `ProfileEditView`, `SettingsView`).
  - `ContentView` drives the dashboard with `@Query` sorted `BabyProfile` records; modals mutate models directly and rely on SwiftData observation.
  - `HistoryView` merges multiple `@Query` collections and filters using `persistentModelID` identifiers.
  - `FeedSessionEditView` uses `@Bindable` to edit a SwiftData model instance in place.
  - `ContentViewModel` (singleton) caches the shared `ModelContext` via `SharedModelContainer.container.mainContext` and performs writes on the main actor for feed/diaper actions.

- **Non-UI consumers**
  - `NearbySyncManager`, `AppDelegate`, and `FullScreenClockApp` manually grab `SharedModelContainer.container.mainContext` to force saves and refresh widget snapshots.
  - `HistoryCSVService` performs CSV import/export using a passed `ModelContext`.
  - `WidgetSnapshotRefresher` takes a `ModelContext` to fetch `BabyProfile` records before writing widget snapshots.
  - `Model/AppEntity.swift` exposes `BabyProfileEntity` to App Intents by querying the shared `ModelContext`.
  - `SiriIntents.swift` executes against `ContentViewModel.shared`, which internally touches SwiftData.

- **Tests & previews**
  - SwiftUI previews (e.g., `ContentView`, widget previews) spin up in-memory `ModelContainer`s seeded with sample data.
  - Unit/UI tests use SwiftData helpers wherever the production code expects `ModelContext`.

## Migration Plan

1. **Establish Core Data stack**
   - Add an `.xcdatamodeld` that mirrors the SwiftData schema (entities: `BabyProfile`, `FeedSession`, `DiaperChange`; relationships and delete rules preserved).
   - Create a `PersistenceController` (or rename `SharedModelContainer`) that wraps `NSPersistentCloudKitContainer`.
     - Configure the persistent store URL to `BabyDashboard.sqlite` inside the App Group directory (reuse runtime lookup logic).
     - Set `options.cloudKitContainerOptions` to the same `ICLOUD_CONTAINER_ID` (Debug/Release aware).
     - Enable `NSPersistentStoreRemoteChangeNotificationPostOptionKey`, persistent history tracking, and `automaticallyMergesChangesFromParent` on the view context.
     - Provide background context creation helpers for long-running work (`HistoryCSVService`, imports, Siri intents when off-main).
   - Remove the SwiftData dependency from the Model module and the app target.

2. **Port model definitions**
   - Replace `@Model` classes with `NSManagedObject` subclasses (manual classes or code generation).
   - Mirror transient helpers as computed properties/extensions, ensuring key paths use `@NSManaged` storage (`amountValue`, `amountUnitSymbol`, etc.).
   - Persist `DiaperType` as a string attribute and expose typed wrappers via computed properties.
   - Audit any SwiftData-specific conveniences (`persistentModelID`, `@Bindable`) and provide Core Data equivalents (e.g., store `objectID` or wrap with `Identifiable` conformances using `objectID.uriRepresentation()`).

3. **Update dependency injection**
   - In `FullScreenClockApp`, inject the Core Data `viewContext` using `.environment(\.managedObjectContext, controller.viewContext)` and remove `.modelContainer`.
   - Replace the singleton `ContentViewModel.shared` with an instance that accepts an `NSPersistentContainer` or `NSManagedObjectContext`. For global access (Siri, app intents, nearby sync), expose a shared controller that hands out contexts safely.
   - Update `NearbySyncManager`, `AppDelegate`, and widget refresher hooks to use the Core Data controller instead of `SharedModelContainer`.

4. **Rewrite SwiftUI bindings**
   - Convert `@Query` usage to `@FetchRequest` or fetch-controller-backed `ObservableObject`s.
     - `ContentView`: `@FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])`.
     - `HistoryView`: multiple fetch requests for feeds/diapers/babies, or consolidate with view models.
   - Swap `@Environment(\.modelContext)` with `@Environment(\.managedObjectContext)`.
   - Replace `@Bindable` edits with explicit `NSManagedObjectContext` mutations (possibly by duplicating values into local state and saving via context).
   - Update filtering logic that relied on `persistentModelID` to use `NSManagedObjectID`.

5. **Refactor services & utilities**
   - `HistoryCSVService`: switch function signatures to take `NSManagedObjectContext`, wrapping fetches in `perform` or `performAndWait`.
   - `WidgetSnapshotRefresher`: accept `NSManagedObjectContext` and execute fetch requests via Core Data APIs.
   - `Model/AppEntity.swift` & `SiriIntents.swift`: query via Core Data contexts; ensure App Intent isolation by using `NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)` with `perform`.
   - `WidgetCache` remains unchanged apart from removing SwiftData imports.

6. **Ensure CloudKit compatibility & sharing readiness**
   - Verify the container loads with `NSPersistentCloudKitContainer` and that schema matches the SwiftData version (start with empty store).
   - Enable `iCloud` capabilities for Core Data + CloudKit in the project once the stack exists (necessary when we later add sharing support).

7. **Remove SwiftData references**
   - Delete `import SwiftData`, `Schema`, and `ModelConfiguration` usage across modules.
   - Update build settings to drop SwiftData frameworks from linked libraries.

## Preview Updates

- Replace in-memory `ModelContainer` previews with a Core Data preview stack:
  - Introduce `PersistenceController.preview` that creates an `NSPersistentCloudKitContainer(name: ..., managedObjectModel: ...)` pointing to an in-memory store (`NSInMemoryStoreType`).
  - Seed sample data by creating managed objects inside `preview.viewContext` and saving.
  - Update `ContentView` preview to call:

    ```swift
    let controller = PersistenceController.preview
    return ContentView(viewModel: ContentViewModel(container: controller))
        .environment(\.managedObjectContext, controller.viewContext)
    ```

- Widget previews stay the same because they operate on `WidgetBabySnapshot` data. Ensure any preview helpers that referenced SwiftData types are removed or replaced with plain structs.

## Implementation Checklist

- [ ] Add Core Data model (`BabyMonitor.xcdatamodeld`) mirroring current entities/relationships/attributes.
- [ ] Implement `PersistenceController` wrapping `NSPersistentCloudKitContainer` (App Group URL + CloudKit IDs).
- [ ] Generate or hand-write `NSManagedObject` subclasses with helper extensions for computed properties.
- [ ] Replace `SharedModelContainer` usage with the new controller throughout app, intents, and services.
- [ ] Update SwiftUI views to use `@FetchRequest`, `@Environment(\.managedObjectContext)`, and Core Data editing patterns.
- [ ] Refactor `ContentViewModel` and other business logic classes to operate on `NSManagedObjectContext`.
- [ ] Migrate `HistoryCSVService`, `WidgetSnapshotRefresher`, App Intents, and Siri intents to Core Data APIs.
- [ ] Update previews and test utilities to use an in-memory Core Data stack.
- [ ] Remove SwiftData imports, build settings, and assets; verify the project compiles without the SwiftData framework.
- [ ] Smoke-test: launch app, add/edit feeds and diapers, check widgets refresh, run CSV import/export, and invoke Siri intents.
- [ ] Prepare follow-up work for CloudKit sharing enablement (capabilities, sharing UI) once Core Data migration is stable.

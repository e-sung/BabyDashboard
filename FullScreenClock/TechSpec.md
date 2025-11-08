# Tech Spec: Migration from SwiftData to Core Data (CloudKit mirroring maintained, no Sharing)

## Summary
Migrate persistence from SwiftData to Core Data to preserve existing functionality and CloudKit private-database sync. Adopt NSPersistentCloudKitContainer with the same App Group store location to maintain extension access and parity with current SwiftData mirroring. Perform an in-app, idempotent migration from existing SwiftData objects (BabyProfile, FeedSession, DiaperChange). Replace SwiftData-dependent UI with Core Data equivalents. Maintain current widget refresh behavior on CloudKit imports. CloudKit Sharing (CKShare) is explicitly out of scope for this phase.

Change: Remove BabyProfile’s lastFeedAmountValue and lastFeedAmountUnitSymbol from the data model. Treat “last feed amount” as a non-critical convenience cache stored in UserDefaults, keyed by the baby’s name (per request). During migration, backfill this cache from the most recent FeedSession for each baby when possible.

Important: The UserDefaults migration for “last feed amount” is a separate rollout (Phase A), completed before introducing any Core Data changes (Phase B/C).

## Goals
- Replace SwiftData with Core Data across app and extensions.
- Preserve all existing user data via an in-app migration.
- Maintain current UI behavior and performance characteristics.
- Keep CloudKit private-database mirroring (equivalent to current SwiftData setup).
- Keep widget functionality working (including snapshot refresh after pushes).
- Provide a maintainable, concurrency-safe Core Data stack.
- Maintain fast, deterministic SwiftUI Previews with easy data seeding.
- Move “last feed amount” cache out of the database and into UserDefaults as a separate phase before Core Data work.

## Non-Goals
- Implementing CloudKit Sharing (CKShare) or shared database flows.
- Rewriting unrelated business logic or changing UX.
- Changing CloudKit schema beyond what’s required to mirror the current model to the private database.
- Supporting OS versions older than the current minimum.

## Current State
- Persistence:
  - SwiftData ModelContainer factory: SharedModelContainer.
  - Schema entities: BabyProfile, FeedSession, DiaperChange; enum DiaperType (String, Codable).
  - Store location: App Group SQLite at BabyDashboard.sqlite.
  - CloudKit mirroring: cloudKitDatabase .private(containerID) with iCloud.sungdoo.babyDashboard(.dev in DEBUG).
- App:
  - FullScreenClockApp attaches .modelContainer(SharedModelContainer.container).
  - Observes .NSPersistentStoreRemoteChange to refresh widget cache.
  - AppDelegate handles remote notifications and calls refreshBabyWidgetSnapshots.
- UI access patterns:
  - HistoryView uses @Query on entities and @Environment(\.modelContext) for inserts/deletes.
  - HistoryEditView binds directly to SwiftData models; uses amountValue/amountUnitSymbol and memoText; saves via modelContext.
  - HistoryEvent wraps models for display; uses PersistentIdentifier to locate objects for editing/deleting.
- Extensions/Widgets:
  - Widget uses a cache (WidgetCache) and snapshots built via refreshBabyWidgetSnapshots(using:).
  - No direct store access shown, but App Group location supports future read access.

## Target Architecture
- Core Data stack
  - NSPersistentCloudKitContainer with a single store in the App Group directory (BabyDashboard.sqlite).
  - CloudKit container IDs: iCloud.sungdoo.babyDashboard(.dev in DEBUG).
  - Enable persistent history tracking and remote change notifications.
  - viewContext on main queue with automaticallyMergesChangesFromParent = true.
  - Background contexts for imports/writes.
- Data model (Core Data)
  - Entities mirror SwiftData models 1:1 (see mapping below), except BabyProfile no longer stores lastFeedAmountValue or lastFeedAmountUnitSymbol.
  - Delete rules:
    - BabyProfile → feedSessions: Nullify
    - BabyProfile → diaperChanges: Nullify
    - FeedSession.profile, DiaperChange.profile: Nullify
  - Indexes for sort-heavy attributes.
  - Uniqueness constraints to support idempotent migration.
  - Value representation:
    - Measurement<UnitVolume> remains represented in FeedSession as amountValue (Double?) + amountUnitSymbol (String?).
    - DiaperType: String attribute with values "pee"/"poo".
- Last Feed Amount Cache (UserDefaults)
  - Storage: UserDefaults (standard), optionally within App Group suite if needed cross-process.
  - Keying: BabyProfile.name (per request).
  - Value: Encoded as a small struct { amountValue: Double, amountUnitSymbol: String }, serialized as JSON or a dictionary.
  - Behavior:
    - Read: Display last feed amount from cache when available.
    - Write: Update cache on feed save/edit that includes an amount for the selected baby.
    - Migration: Backfill by computing the most recent FeedSession with amount for each baby and writing to cache.

## Data Model Mapping (SwiftData → Core Data)

Entity: BabyProfile
- Attributes:
  - id: UUID (required) — Core Data type UUID, indexed, unique.
  - name: String (required).
  - feedTerm: Double (TimeInterval seconds, required, default 10800).
  - createdAt: Date (required) — NEW; used for ordering in UI. Default to now for new inserts; backfilled during migration (see Migration Strategy).
- Relationships:
  - feedSessions: To-Many FeedSession (inverse: profile, delete rule: Nullify).
  - diaperChanges: To-Many DiaperChange (inverse: profile, delete rule: Nullify).
- Constraints/Indexes:
  - Uniqueness: id.
  - Indexes: createdAt (for UI sorting), name (optional, for lookups).

Entity: FeedSession
- Attributes:
  - startTime: Date (required).
  - endTime: Date? (optional).
  - amountValue: Double? (optional).
  - amountUnitSymbol: String? (optional).
  - memoText: String? (optional).
  - [New for Core Data] uuid: UUID (required) — generated during migration for stable identity.
- Relationships:
  - profile: To-One BabyProfile (inverse: feedSessions, delete rule: Nullify).
- Constraints/Indexes:
  - Uniqueness: (profile.id, startTime) — supports idempotent migration if uuid absent.
  - Index: startTime.

Entity: DiaperChange
- Attributes:
  - timestamp: Date (required).
  - type: String (required) — values: "pee", "poo".
  - [New for Core Data] uuid: UUID (required) — generated during migration for stable identity.
- Relationships:
  - profile: To-One BabyProfile (inverse: diaperChanges, delete rule: Nullify).
- Constraints/Indexes:
  - Uniqueness: (profile.id, timestamp, type).
  - Index: timestamp.

Notes
- SwiftData transient properties (isInProgress, hashtags, amount computed) remain computed in app code; they do not need Core Data storage.
- BabyProfile.lastFeedAmountValue and BabyProfile.lastFeedAmountUnitSymbol are removed from the Core Data model; handled by UserDefaults cache.

## Store Configuration
- File URL
  - App Group identifier (DEBUG/RELEASE):
    - DEBUG: group.sungdoo.babyDashboard.dev
    - RELEASE: group.sungdoo.babyDashboard
  - Store filename: BabyDashboard.sqlite (same as SwiftData).
- CloudKit
  - Container IDs:
    - DEBUG: iCloud.sungdoo.babyDashboard.dev
    - RELEASE: iCloud.sungdoo.babyDashboard
  - Assign NSPersistentCloudKitContainerOptions(containerIdentifier:) to the store description.
- Options
  - viewContext.automaticallyMergesChangesFromParent = true
  - viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
  - storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
  - storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

## Migration Strategy

Phase A: UserDefaults migration for “last feed amount” (separate rollout, before Core Data)
- Introduce LastFeedAmountCache (UserDefaults-backed):
  - Key format: "lastFeedAmount.<babyName>" in standard defaults; consider App Group suite if widgets/extensions need the value.
  - API: get(forBabyName:), set(value:unitSymbol:forBabyName:), remove(forBabyName:).
- Replace reads/writes in current SwiftData code:
  - ContentView.finishFeeding: write to cache after saving a feed with amount.
  - ContentView.finishFeedSheet.onAppear: read from cache to prefill the amount field.
  - Previews: seed cache instead of writing BabyProfile.lastFeedAmount*.
- Optional one-time backfill on first launch after enabling Phase A:
  - For each baby, locate the most recent FeedSession with amount and write to the cache if absent.
- Name-change behavior:
  - If the app supports renaming, optionally move the cache value from oldName to newName during rename (best-effort).
- Telemetry:
  - Track how many babies received a backfilled cache value and errors.

Phase B: Dual-Stack Introduction (Core Data alongside SwiftData)
- Create .xcdatamodeld with entities/attributes exactly as mapped above (including NEW BabyProfile.createdAt and excluding BabyProfile.lastFeedAmount*).
- Ship Core Data stack behind a feature flag.
- On first launch after enabling Phase B:
  - Detect SwiftData store presence and whether Core Data store has any objects.
  - Import/migrate in a background task:
    - Open SwiftData ModelContainer; fetch BabyProfile, FeedSession, DiaperChange.
    - Insert into Core Data using a background context:
      - BabyProfile: copy id, name, feedTerm; compute createdAt:
        - min(earliest FeedSession.startTime, earliest DiaperChange.timestamp) if any exist; else migrationStartDate (now).
      - FeedSession: copy startTime, endTime, amountValue, amountUnitSymbol, memoText; link profile by id; generate uuid if absent.
      - DiaperChange: copy timestamp, type.rawValue; link profile; generate uuid if absent.
    - Idempotency: match via uniqueness constraints before insert (e.g., profile.id + startTime).
  - UserDefaults backfill (safety net):
    - For each BabyProfile, compute most recent FeedSession with amount and write to cache if absent (Phase A should have already populated, but this covers late adopters).
  - Persist migrationCompleted flag with schema version in UserDefaults.
  - Validate counts/relationships; log metrics.

Phase C: Cutover to Core Data
- Replace SwiftData with Core Data in UI:
  - HistoryView: @Query arrays → @FetchRequest (or NSFetchedResultsController) with equivalent sort orders; BabyProfile sorted by createdAt ascending.
  - HistoryEditView: Bind to NSManagedObject properties; keep amount/memo logic.
  - ContentView: Keep using LastFeedAmountCache for defaults when finishing feeds.
- FullScreenClockApp:
  - Remove .modelContainer(SharedModelContainer.container).
  - Inject Core Data viewContext via .environment(\.managedObjectContext, container.viewContext).
  - Keep observing .NSPersistentStoreRemoteChange to refresh widget snapshots.
- AppDelegate & NearbySyncManager:
  - Replace SharedModelContainer references with Core Data stack.
- Keep SwiftData stack present but unused (or read-only) briefly for safety.

Phase D: Cleanup
- Remove SwiftData dependencies (SharedModelContainer, @Model usages).
- Ensure BabyProfile.lastFeedAmount* are removed from any remaining code and previews.
- Optionally delete SwiftData files after a safe period.
- Remove feature flags.

Edge Cases
- Partial migration: Importer is idempotent using uniqueness constraints; safe to re-run.
- Relationship gaps: If a FeedSession/DiaperChange has a missing profile, import as orphan with profile = nil (matching current delete rules).
- CloudKit sync races: Merge policies favor local changes during migration; let CloudKit reconcile post-import.
- Name-based cache:
  - If multiple babies share a name, cache may collide; last write wins.
  - If a baby’s name changes, the old cache key persists unless rename flow moves/deletes it.

## UI/UX Changes
- HistoryView:
  - Replace @Query with Core Data fetches; preserve sorting/filtering logic.
  - Use NSManagedObject instances or managedObjectID for edit/delete operations.
- HistoryEditView:
  - Bind to NSManagedObject properties; maintain amount/memo logic and hashtag extraction in app code.
- ContentView:
  - Replace any usage of BabyProfile.lastFeedAmount* with LastFeedAmountCache (Phase A).
  - On finishing a feed with an amount, write to cache for that baby’s name; read cache to prefill the finish amount sheet.
- Baby ordering change:
  - Replace any sorting by BabyProfile.name with sorting by BabyProfile.createdAt (ascending).
  - Update any UI copy or tests that assumed alphabetical ordering.
- Error Handling:
  - Graceful messages for iCloud unavailable, network errors.

## Widgets and Extensions
- Persistence:
  - Keep using snapshot cache; if reading Core Data becomes necessary, configure a read-only NSPersistentContainer pointing to the App Group store URL (no CloudKit options in the widget).
- Data Freshness:
  - Maintain current behavior: refreshBabyWidgetSnapshots on .NSPersistentStoreRemoteChange, on app launch, and when entering foreground.
- Performance:
  - Keep fetches minimal; avoid heavy graph traversals in extensions.
- Last Feed Amount for Widgets:
  - If widgets need this value, read from the same UserDefaults cache (App Group suite recommended for cross-process access).

## Previews and Developer Experience
- Goals
  - Preserve fast, deterministic SwiftUI Previews that rely on seeding data.
  - Avoid CloudKit in previews; use an in-memory Core Data store.
  - Make porting from SwiftData’s in-memory previews straightforward.
  - Allow seeding of the UserDefaults last feed amount cache for previews.

- Preview container
  - Provide a PreviewPersistentContainer that:
    - Uses NSInMemoryStoreType (no file IO).
    - Does not assign NSPersistentCloudKitContainerOptions (CloudKit disabled).
    - Configures viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy and automaticallyMergesChangesFromParent = true.
  - Factory API:
    - PreviewContainers.default(seed:) builds an in-memory container and executes a seed closure on a background context, saving before returning the container.

- Seeding utilities
  - Create lightweight fixtures/builders per entity:
    - makeBabyProfile(id:name:feedTerm:createdAt:)
    - makeFeedSession(profile:start:end:amountValue:amountUnitSymbol:memoText:)
    - makeDiaperChange(profile:timestamp:type:)
  - Last feed amount cache seeding:
    - seedLastFeedAmount(forBabyName:amountValue:amountUnitSymbol:) writes to UserDefaults for previews.
  - Determinism:
    - Use fixed UUIDs and fixed dates (relative to a provided “now”) for stable previews.
    - Normalize amountUnitSymbol to canonical symbols used by the app.

- Using in SwiftUI previews
  - Replace .modelContainer(container) with:
    - .environment(\.managedObjectContext, previewContainer.viewContext)
  - @FetchRequest support:
    - Works automatically against the injected preview context; ensure sort descriptors match runtime usage:
      - FeedSession: startTime desc
      - DiaperChange: timestamp desc
      - BabyProfile: createdAt asc (replaces name sort)
  - If wrapping NSFetchedResultsController in ObservableObjects:
    - Add a preview initializer that accepts a context.

- Example conversions
  - HistoryView preview:
    - Seed multiple months of FeedSession/DiaperChange across two BabyProfile fixtures to exercise day/month grouping and hashtag UI.
    - Optionally seed last feed amount cache for one or both babies to exercise UI that reads it.
  - ContentView preview:
    - Seed two babies; one with an in-progress feed, the other with a recent finished feed and diaper changes; set createdAt to control tile order.

- Widget previews
  - Continue using WidgetCache JSON snapshots in App Group for timeline previews as today.
  - If future widget previews read Core Data, create a separate in-memory preview container in the widget target (no CloudKit).

- Tests alignment
  - Reuse Fixtures for unit/integration tests to avoid duplication.
  - Provide a TestPersistentContainer similar to the preview container, with explicit teardown between tests.
  - Add tests for the last feed amount cache read/write and migration backfill.

## SwiftUI Property Wrappers Mapping (SwiftData → Core Data)
- Container/Context injection
  - SwiftData: .modelContainer(SharedModelContainer.container) and @Environment(\.modelContext)
  - Core Data: inject .environment(\.managedObjectContext, persistentContainer.viewContext) at the app root; use:
    - @Environment(\.managedObjectContext) private var viewContext for reads/writes.
- Querying collections in views
  - SwiftData: @Query(sort:)
  - Core Data: @FetchRequest with matching predicates and sort descriptors.
    - Example mappings in this project:
      - HistoryView
        - @Query(sort: [SortDescriptor(\FeedSession.startTime, order: .reverse)])
          → @FetchRequest(sortDescriptors: [SortDescriptor(\FeedSessionMO.startTime, order: .reverse)], predicate: nil)
        - @Query(sort: [SortDescriptor(\DiaperChange.timestamp, order: .reverse)])
          → @FetchRequest(sortDescriptors: [SortDescriptor(\DiaperChangeMO.timestamp, order: .reverse)], predicate: nil)
        - @Query(sort: [SortDescriptor(\BabyProfile.name, order: .forward)]) [REPLACED]
          → @FetchRequest(sortDescriptors: [SortDescriptor(\BabyProfileMO.createdAt, order: .forward)], predicate: nil)
      - ContentView
        - @Query(sort: [SortDescriptor(\BabyProfile.name)]) [REPLACED]
          → @FetchRequest(sortDescriptors: [SortDescriptor(\BabyProfileMO.createdAt, order: .forward)], predicate: nil)
    - Use @SectionedFetchRequest only if you introduce a stored, KVC-compliant sectioning key (e.g., monthKey). Current grouping by logical day/month is computed in Swift; keep that approach unless you add a persisted section key.
- Editing a single object
  - SwiftData: pass a model (any PersistentModel) to sheets; bind to properties directly; save via modelContext.
  - Core Data:
    - Pass the NSManagedObject (e.g., FeedSessionMO) into the sheet and bind via @ObservedObject var session: FeedSessionMO.
    - Or pass NSManagedObjectID and fetch it in the destination view’s context.
    - Enable Identifiable on NSManagedObject (extension NSManagedObject: Identifiable) to use .sheet(item:) with managed objects.
- Inserts/Deletes/Saves
  - SwiftData: modelContext.insert/delete/save()
  - Core Data: viewContext.insert(object), viewContext.delete(object), try viewContext.save()
    - For background operations, use a background context and rely on viewContext.automaticallyMergesChangesFromParent = true so @FetchRequest updates.
- Filtering
  - Prefer predicates in @FetchRequest when the filter is stable (e.g., selectedBabyID known).
  - For dynamic, cross-entity composite views (like HistoryView merging two queries), keep current approach: fetch lists separately, merge and filter in Swift code.
- Identity and lookups
  - SwiftData: PersistentIdentifier
  - Core Data: NSManagedObjectID or stable UUID attributes.
    - For lookups across lists (e.g., finding the underlying model to edit), pass the NSManagedObject or objectID directly to avoid refetch by UUID where possible.
- Change propagation
  - Ensure persistentContainer.viewContext.automaticallyMergesChangesFromParent = true so background/CloudKit changes are merged and @FetchRequest updates automatically.

## Telemetry and Observability
- Migration logs:
  - Start/end, duration, per-entity counts, errors.
- Last feed cache:
  - Log backfill coverage rate (how many babies got a cache value from history).

## Rollout Plan
- Stage with feature flags:
  1) Phase A: Ship LastFeedAmountCache disabled; enable for a small cohort; then roll out to all users. Validate backfill coverage and UI parity.
  2) Phase B: Ship Core Data stack + importer disabled.
  3) Enable Core Data migration (Phase B) for a small cohort; validate.
  4) Phase C: Cut over UI to Core Data; roll out gradually.
  5) Phase D: Remove SwiftData and feature flags after full adoption.

- Backout:
  - Phase A: Disable cache usage and revert to current behavior (still reading from SwiftData models).
  - Phase B/C: Disable Core Data feature flag to continue on SwiftData without data loss.

## Risks and Mitigations
- Data loss:
  - Idempotent importer, uniqueness constraints, validation counts, keep SwiftData store until confirmed.
- Performance regressions:
  - Index sort attributes, batch inserts, prefetch relationships, keep work off main thread.
- Widget breakage:
  - Keep store path identical; test fresh installs and upgrades.
- Name-keyed cache risks (Phase A):
  - Collisions if multiple babies share a name.
  - Stale entries if a baby is renamed (unless rename flow moves/deletes the old key).
  - Mitigation options (future):
    - Prefer BabyProfile.id as the cache key; maintain a small name→id mapping for UI lookup.
    - Handle rename by migrating cache from old name key to new name key.

## Testing Strategy
- Unit tests:
  - Mapping correctness per entity; enum mapping; amount conversions.
  - Last feed cache helper: read/write round-trips, migration backfill logic, behavior on missing values.
- Integration tests:
  - Populate SwiftData fixtures; run importer; verify counts, attributes, relationships; re-run to verify idempotency.
  - Verify last feed cache backfills from most recent FeedSession with amount.
  - Simulate CloudKit imports and verify widget refresh triggers.
- UI tests:
  - History listing, add/edit/delete; permission enforcement.
  - Verify that saving a FeedSession with an amount updates the displayed last feed amount.

## Implementation Tasks (Checklist)
- Phase A: UserDefaults cache migration (separate rollout)
  - Add LastFeedAmountCache using UserDefaults (name-keyed; App Group suite if needed).
  - Replace reads/writes of BabyProfile.lastFeedAmount* in:
    - ContentView.finishFeeding (write)
    - ContentView.finishFeedSheet.onAppear (read)
    - Previews that seed last amount (write to cache instead)
  - Optional one-time backfill from most recent FeedSession per baby on first launch.
  - Add telemetry for backfill coverage and cache hits.
- Create .xcdatamodeld:
  - Entities BabyProfile, FeedSession, DiaperChange with attributes/relationships above.
  - Remove BabyProfile.lastFeedAmountValue and BabyProfile.lastFeedAmountUnitSymbol.
  - Add indexes and uniqueness constraints (include BabyProfile.createdAt index).
- Phase B: Core Data stack
  - NSPersistentCloudKitContainer with App Group store URL and container IDs per build config.
  - Enable history tracking and remote change notifications.
  - Implement importer (SwiftData → Core Data):
    - Background context; idempotent matching via constraints; generate uuid for FeedSession/DiaperChange.
    - Backfill BabyProfile.createdAt as specified.
    - Backfill UserDefaults last feed amount cache if absent (safety net).
    - Verification and logging.
- Phase C: Replace SwiftData in app
  - FullScreenClockApp: inject Core Data viewContext; keep remote change observer.
  - AppDelegate/NearbySyncManager: switch to Core Data stack.
  - HistoryView/HistoryEditView/ContentView: replace @Query/modelContext with Core Data equivalents using @FetchRequest and @Environment(\.managedObjectContext); update baby sort to createdAt asc.
  - Ensure all references to BabyProfile.lastFeedAmount* are removed and replaced with the cache.
- Phase D: Cleanup and stabilization
  - Remove SwiftData code once complete.
  - Remove feature flags.
  - QA and stabilization.


import SwiftUI
import SwiftData

private let pageSize = 30

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings

    // Remove eager @Query to avoid loading everything at once.
    // We'll load pages manually.
    @State private var loadedFeedSessions: [FeedSession] = []
    @State private var loadedDiaperChanges: [DiaperChange] = []

    // Cursors track the oldest loaded date per model type.
    @State private var oldestFeedDate: Date? = nil
    @State private var oldestDiaperDate: Date? = nil

    // Loading state
    @State private var isInitialLoad = true
    @State private var isLoadingMore = false
    @State private var hasMoreFeed = true
    @State private var hasMoreDiaper = true

    // Editing
    @State private var eventToEdit: HistoryEvent?

    // Filters: make this enum internal (remove private) so nested views can see it.
    enum EventFilter: String, CaseIterable, Identifiable {
        case all
        case feed
        case pee
        case poo

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return String(localized: "All")
            case .feed: return String(localized: "Feed")
            case .pee: return String(localized: "Pee")
            case .poo: return String(localized: "Poo")
            }
        }
    }

    @State private var selectedBabyID: UUID? = nil // nil == All babies
    @State private var selectedEventFilter: EventFilter = .all
    @State private var isShowingFilters = false
    @State private var availableBabies: [BabyProfile] = []
    @State private var isShowingAddSheet = false

    // Merge and sort for display (raw, unfiltered)
    private var historyEvents: [HistoryEvent] {
        let feeds = loadedFeedSessions.map { HistoryEvent(from: $0) }
        let diapers = loadedDiaperChanges.map { HistoryEvent(from: $0) }
        return (feeds + diapers).sorted(by: { $0.date > $1.date })
    }
    
    // Apply filters to historyEvents
    private var filteredEvents: [HistoryEvent] {
        historyEvents.filter { event in
            // Baby filter
            let babyMatches: Bool = {
                guard let selectedBabyID else { return true }
                switch event.type {
                case .feed:
                    if let model = loadedFeedSessions.first(where: { $0.persistentModelID == event.underlyingObjectId }) {
                        return model.profile?.id == selectedBabyID
                    }
                    return false
                case .diaper:
                    if let model = loadedDiaperChanges.first(where: { $0.persistentModelID == event.underlyingObjectId }) {
                        return model.profile?.id == selectedBabyID
                    }
                    return false
                }
            }()
            guard babyMatches else { return false }

            // Event filter
            switch selectedEventFilter {
            case .all:
                return true
            case .feed:
                return event.type == .feed
            case .pee:
                return event.type == .diaper && event.diaperType == .pee
            case .poo:
                return event.type == .diaper && event.diaperType == .poo
            }
        }
    }

    // Section model
    private struct DaySection: Identifiable {
        let id: Date // startOfDay
        let date: Date
        let events: [HistoryEvent]
        
        // Aggregates per baby
        let feedTotalsByBaby: [String: Measurement<UnitVolume>]
        let diaperCountsByBaby: [String: Int]
    }
    
    // Build sections grouped by day using currently loaded models for accurate aggregates.
    private var daySections: [DaySection] {
        let summaries = makeDaySummaries(
            events: filteredEvents,
            feedSessions: loadedFeedSessions,
            diaperChanges: loadedDiaperChanges,
            targetUnit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters,
            calendar: Calendar.current,
            startOfDayHour: settings.startOfDayHour,
            startOfDayMinute: settings.startOfDayMinute
        )
        return summaries.map { s in
            DaySection(
                id: s.id,
                date: s.date,
                events: s.events,
                feedTotalsByBaby: s.feedTotalsByBaby,
                diaperCountsByBaby: s.diaperCountsByBaby
            )
        }
    }
    
    // MARK: - Month grouping
    
    private struct MonthSection: Identifiable {
        let id: Date // month start
        let monthStart: Date
        let daySections: [DaySection]
    }
    
    private var monthSections: [MonthSection] {
        let calendar = Calendar.current
        // Group daySections by month
        let groupedByMonth = Dictionary(grouping: daySections) { (day: DaySection) -> Date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: day.date)) ?? calendar.startOfDay(for: day.date)
        }
        // Build MonthSection array
        let sections = groupedByMonth.map { (monthStart, days) -> MonthSection in
            // Sort days within the month descending by date
            let sortedDays = days.sorted(by: { $0.date > $1.date })
            return MonthSection(id: monthStart, monthStart: monthStart, daySections: sortedDays)
        }
        // Sort months descending (newest month first)
        return sections.sorted(by: { $0.monthStart > $1.monthStart })
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(monthSections) { month in
                    // Month header (for now just title; later can navigate)
                    Section {
                        // Within the month, render each day section
                        ForEach(month.daySections) { section in
                            Section {
                                ForEach(section.events) { event in
                                    HistoryRowView(event: event)
                                        .onTapGesture { eventToEdit = event }
                                        .onAppear {
                                            // If this is the last row overall, try to load more
                                            if event.id == filteredEvents.last?.id {
                                                loadMoreIfNeeded()
                                            }
                                        }
                                }
                                .onDelete(perform: deleteEvent)
                            } header: {
                                dayHeaderView(for: section)
                            }
                        }
                    } header: {
                        monthHeaderView(for: month)
                    }
                }
                
                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if !(hasMoreFeed || hasMoreDiaper) && !filteredEvents.isEmpty {
                    HStack {
                        Spacer()
                        Text("No more history")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .overlay {
                if isInitialLoad && filteredEvents.isEmpty {
                    ProgressView()
                } else if !isInitialLoad && filteredEvents.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock", description: Text("Events will appear here."))
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(Text("Filters"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add Event"))
                }
            }
            .refreshable { await refresh() }
            .onAppear {
                if isInitialLoad {
                    Task { await loadInitial() }
                }
                loadAvailableBabies()
            }
            .sheet(isPresented: $isShowingFilters) {
                FilterSheet(
                    babies: availableBabies,
                    selectedBabyID: $selectedBabyID,
                    selectedEventFilter: $selectedEventFilter
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $eventToEdit) { event in
                if let model = findModel(for: event) {
                    HistoryEditView(model: model)
                } else {
                    Text("Could not find event to edit.")
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddHistorySheet(
                    babies: availableBabies,
                    defaultSelectedBabyID: selectedBabyID
                ) { result in
                    // Insert into SwiftData and update in-memory arrays
                    switch result {
                    case .feed(let session):
                        modelContext.insert(session)
                        loadedFeedSessions.insert(session, at: 0) // newest likely at top
                    case .diaper(let change):
                        modelContext.insert(change)
                        loadedDiaperChanges.insert(change, at: 0)
                    }
                    try? modelContext.save()
                    NearbySyncManager.shared.sendPing()
                    isShowingAddSheet = false
                } onCancel: {
                    isShowingAddSheet = false
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Month Header View
    
    private func monthHeaderView(for month: MonthSection) -> some View {
        // Display the month name; include year only for December and January
        let monthNumber = Calendar.current.component(.month, from: month.monthStart)
        let title: String = {
            if monthNumber == 12 || monthNumber == 1 {
                return month.monthStart.formatted(.dateTime.year().month(.wide))
            } else {
                return month.monthStart.formatted(.dateTime.month(.wide))
            }
        }()
        
        return HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .imageScale(.small)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Placeholder for future navigation to monthly analysis page
            // e.g., navigate to MonthlyAnalysisView(monthStart: month.monthStart)
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Day Header View
    
    @ViewBuilder
    private func dayHeaderView(for section: DaySection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Logical-day span title, e.g., "10월 3일 ~ 4일" or "10월 31일 ~ 11월 1일"
            Text(logicalDaySpanTitle(start: section.date))
                .font(.headline)
            
            // For each baby that has any activity that day, show totals.
            // Build a union of baby names from both dictionaries.
            let babyNames = Set(section.feedTotalsByBaby.keys).union(section.diaperCountsByBaby.keys)
            ForEach(Array(babyNames).sorted(), id: \.self) { name in
                HStack(spacing: 10) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    if let total = section.feedTotalsByBaby[name] {
                        Text(total.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))))
                            .font(.subheadline)
                    }
                    let diaperCount = section.diaperCountsByBaby[name, default: 0]
                    if diaperCount > 0 {
                        Text("\(diaperCount) diapers")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Build a localized, compact title for a logical-day span starting at `start` and ending at `start + 1 day`.
    // - If startOfDay is midnight (00:00), show just "M월 d일" (logical day == calendar day).
    // - If start and end share the same month: "M월 d일 ~ d일"
    // - If months differ: "M월 d일 ~ M월 d일"
    private func logicalDaySpanTitle(start: Date, calendar: Calendar = .current) -> String {
        // Midnight start: show single date for classic calendar-day UX
        if settings.startOfDayHour == 0 && settings.startOfDayMinute == 0 {
            return start.formatted(.dateTime.month(.abbreviated).day())
        }
        
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            // Fallback to single-day format
            return start.formatted(.dateTime.month(.abbreviated).day())
        }
        
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let endDay = calendar.component(.day, from: end)
        let sameMonth = (startMonth == endMonth)
        
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        if sameMonth {
            // "10월 3일 ~ 4일"
            return "\(startText) ~ \(endDay)일"
        } else {
            let endText = end.formatted(.dateTime.month(.abbreviated).day())
            // "10월 31일 ~ 11월 1일"
            return "\(startText) ~ \(endText)"
        }
    }

    // MARK: - Model lookup for editing

    private func findModel(for event: HistoryEvent) -> (any PersistentModel)? {
        switch event.type {
        case .feed:
            return loadedFeedSessions.first { $0.persistentModelID == event.underlyingObjectId }
        case .diaper:
            return loadedDiaperChanges.first { $0.persistentModelID == event.underlyingObjectId }
        }
    }

    // MARK: - Delete

    private func deleteEvent(at offsets: IndexSet) {
        // Map offsets from the flattened filteredEvents (current visible order).
        let current = filteredEvents
        for index in offsets {
            let event = current[index]
            if event.type == .feed,
               let session = loadedFeedSessions.first(where: { $0.persistentModelID == event.underlyingObjectId }) {
                modelContext.delete(session)
                if let idx = loadedFeedSessions.firstIndex(where: { $0.persistentModelID == session.persistentModelID }) {
                    loadedFeedSessions.remove(at: idx)
                }
            } else if event.type == .diaper,
                      let diaper = loadedDiaperChanges.first(where: { $0.persistentModelID == event.underlyingObjectId }) {
                modelContext.delete(diaper)
                if let idx = loadedDiaperChanges.firstIndex(where: { $0.persistentModelID == diaper.persistentModelID }) {
                    loadedDiaperChanges.remove(at: idx)
                }
            }
        }
        try? modelContext.save()
        NearbySyncManager.shared.sendPing()
    }

    // MARK: - Paging

    @MainActor
    private func loadInitial() async {
        isInitialLoad = true
        defer { isInitialLoad = false }

        // Reset state
        loadedFeedSessions.removeAll()
        loadedDiaperChanges.removeAll()
        oldestFeedDate = nil
        oldestDiaperDate = nil
        hasMoreFeed = true
        hasMoreDiaper = true

        // Load first pages (newest items) for both types
        async let feeds = fetchFeedSessions(before: nil, limit: pageSize)
        async let diapers = fetchDiaperChanges(before: nil, limit: pageSize)
        let (feedResult, diaperResult) = await (feeds, diapers)

        loadedFeedSessions = feedResult
        loadedDiaperChanges = diaperResult
        oldestFeedDate = feedResult.last?.startTime
        oldestDiaperDate = diaperResult.last?.timestamp

        // Determine if there might be more
        hasMoreFeed = feedResult.count == pageSize
        hasMoreDiaper = diaperResult.count == pageSize
    }

    @MainActor
    private func refresh() async {
        await loadInitial()
    }

    private func loadMoreIfNeeded() {
        guard !isLoadingMore else { return }
        guard hasMoreFeed || hasMoreDiaper else { return }

        isLoadingMore = true
        Task {
            // Fetch next page for each type if needed
            async let moreFeedsTask: [FeedSession] = hasMoreFeed ? fetchFeedSessions(before: oldestFeedDate, limit: pageSize) : []
            async let moreDiapersTask: [DiaperChange] = hasMoreDiaper ? fetchDiaperChanges(before: oldestDiaperDate, limit: pageSize) : []

            let (moreFeeds, moreDiapers) = await (moreFeedsTask, moreDiapersTask)

            if !moreFeeds.isEmpty {
                loadedFeedSessions.append(contentsOf: moreFeeds)
                oldestFeedDate = moreFeeds.last?.startTime
            }
            if !moreDiapers.isEmpty {
                loadedDiaperChanges.append(contentsOf: moreDiapers)
                oldestDiaperDate = moreDiapers.last?.timestamp
            }

            hasMoreFeed = hasMoreFeed && moreFeeds.count == pageSize
            hasMoreDiaper = hasMoreDiaper && moreDiapers.count == pageSize

            isLoadingMore = false
        }
    }

    // MARK: - Fetch helpers

    @MainActor
    private func fetchFeedSessions(before date: Date?, limit: Int) async -> [FeedSession] {
        // If no cursor, don’t create a predicate; just sort and limit.
        let predicate: Predicate<FeedSession>? = {
            if let cursor = date {
                return #Predicate { session in
                    session.startTime < cursor
                }
            } else {
                return nil
            }
        }()

        var descriptor = FetchDescriptor<FeedSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\FeedSession.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @MainActor
    private func fetchDiaperChanges(before date: Date?, limit: Int) async -> [DiaperChange] {
        // If no cursor, don’t create a predicate; just sort and limit.
        let predicate: Predicate<DiaperChange>? = {
            if let cursor = date {
                return #Predicate { change in
                    change.timestamp < cursor
                }
            } else {
                return nil
            }
        }()

        var descriptor = FetchDescriptor<DiaperChange>(
            predicate: predicate,
            sortBy: [SortDescriptor(\DiaperChange.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Filter helpers

    private func loadAvailableBabies() {
        let descriptor = FetchDescriptor<BabyProfile>(
            sortBy: [SortDescriptor(\BabyProfile.name, order: .forward)]
        )
        if let babies = try? modelContext.fetch(descriptor) {
            availableBabies = babies
            // If the currently selected baby no longer exists, reset to All.
            if let selected = selectedBabyID, babies.first(where: { $0.id == selected }) == nil {
                selectedBabyID = nil
            }
        }
    }
}

// Make PersistentModel Identifiable for use in .sheet(item:)
extension PersistentModel {
    public var id: PersistentIdentifier { self.persistentModelID }
}

// MARK: - Filter Sheet

private struct FilterSheet: View {
    let babies: [BabyProfile]
    @Binding var selectedBabyID: UUID?
    @Binding var selectedEventFilter: HistoryView.EventFilter

    var body: some View {
        NavigationView {
            Form {
                Section(String(localized: "Baby")) {
                    Picker(String(localized: "Baby"), selection: Binding<UUID?>(
                        get: { selectedBabyID },
                        set: { selectedBabyID = $0 }
                    )) {
                        Text(String(localized: "All")).tag(UUID?.none)
                        ForEach(babies, id: \.id) { baby in
                            Text(baby.name).tag(UUID?.some(baby.id))
                        }
                    }
                }

                Section(String(localized: "Event Type")) {
                    Picker(String(localized: "Event Type"), selection: $selectedEventFilter) {
                        ForEach(HistoryView.EventFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(String(localized: "Filters"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Add History Sheet

private struct AddHistorySheet: View {
    enum AddType: String, CaseIterable, Identifiable {
        case feed, diaper
        var id: String { rawValue }
        var title: String {
            switch self {
            case .feed: return String(localized: "Feed")
            case .diaper: return String(localized: "Diaper")
            }
        }
    }

    enum Result {
        case feed(FeedSession)
        case diaper(DiaperChange)
    }

    let babies: [BabyProfile]
    let defaultSelectedBabyID: UUID?
    let onSave: (Result) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var addType: AddType = .feed
    @State private var selectedBabyID: UUID?
    // Feed fields (finished session only; unit inferred from locale)
    @State private var feedStart: Date = Date()
    @State private var feedEnd: Date = Date().addingTimeInterval(15 * 60)
    @State private var amountString: String = ""
    // Diaper fields
    @State private var diaperTime: Date = Date()
    @State private var diaperType: DiaperType = .pee

    private var localeUnit: UnitVolume {
        (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
    }

    var body: some View {
        NavigationView {
            Form {
                Section(String(localized: "Event")) {
                    Picker(String(localized: "Type"), selection: $addType) {
                        ForEach(AddType.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "Baby")) {
                    Picker(String(localized: "Baby"), selection: Binding<UUID?>(
                        get: { selectedBabyID },
                        set: { selectedBabyID = $0 }
                    )) {
                        ForEach(babies, id: \.id) { baby in
                            Text(baby.name).tag(UUID?.some(baby.id))
                        }
                    }
                }

                if addType == .feed {
                    Section(String(localized: "Time")) {
                        DatePicker(String(localized: "Start"), selection: $feedStart)
                        DatePicker(String(localized: "End"), selection: $feedEnd, in: feedStart...Date.distantFuture)
                    }
                    Section(String(localized: "Amount")) {
                        HStack {
                            TextField(String(localized: "Amount"), text: $amountString)
                                .keyboardType(.decimalPad)
                            Text(localeUnit.symbol)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } else {
                    Section(String(localized: "Time")) {
                        DatePicker(String(localized: "Time"), selection: $diaperTime)
                    }
                    Section(String(localized: "Type")) {
                        Picker(String(localized: "Type"), selection: $diaperType) {
                            Text(String(localized: "Pee")).tag(DiaperType.pee)
                            Text(String(localized: "Poo")).tag(DiaperType.poo)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle(String(localized: "Add Event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                // Preselect baby if provided; else default to first
                selectedBabyID = defaultSelectedBabyID ?? babies.first?.id
                // Ensure end defaults after start
                if feedEnd < feedStart {
                    feedEnd = feedStart.addingTimeInterval(15 * 60)
                }
            }
            .onChange(of: feedStart) { _, newStart in
                if feedEnd < newStart {
                    feedEnd = newStart
                }
            }
        }
    }

    private var canSave: Bool {
        guard let _ = babies.first(where: { $0.id == selectedBabyID }) else { return false }
        switch addType {
        case .feed:
            guard feedEnd >= feedStart else { return false }
            guard let v = Double(amountString), v >= 0 else { return false }
            return true
        case .diaper:
            return true
        }
    }

    private func save() {
        guard let baby = babies.first(where: { $0.id == selectedBabyID }) else { return }
        switch addType {
        case .feed:
            let session = FeedSession(startTime: feedStart)
            session.endTime = feedEnd
            if let v = Double(amountString) {
                session.amount = Measurement(value: v, unit: localeUnit)
            }
            session.profile = baby
            onSave(.feed(session))
            dismiss()
        case .diaper:
            let change = DiaperChange(timestamp: diaperTime, type: diaperType)
            change.profile = baby
            onSave(.diaper(change))
            dismiss()
        }
    }
}

#Preview("HistoryView Pagination Demo") {
    // Build an in-memory container and seed many items across November to February
    let schema = Schema([BabyProfile.self, FeedSession.self, DiaperChange.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext

    // Seed two babies
    let baby1 = BabyProfile(id: UUID(), name: "연두")
    let baby2 = BabyProfile(id: UUID(), name: "초원")
    context.insert(baby1)
    context.insert(baby2)

    let calendar = Calendar.current
    let now = Date()
    let currentYear = calendar.component(.year, from: now)
    let prevYear = currentYear - 1
    
    // Helper to make a date at a specific Y/M/D hour/minute
    func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps) ?? now
    }
    
    // Unit per locale (use canonical unit to match feedTotals conversion)
    let unit: UnitVolume = (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
    
    // Months: November (previous year), December (previous year), January (current year), February (current year)
    // NOVEMBER (prevYear)
    do {
        let day1 = date(year: prevYear, month: 11, day: 10, hour: 8, minute: 0)
        let day2 = date(year: prevYear, month: 11, day: 21, hour: 14, minute: 0)
        
        let s1 = FeedSession(startTime: day1)
        s1.endTime = calendar.date(byAdding: .minute, value: 20, to: day1)
        s1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 3.0 : 90.0, unit: unit)
        s1.profile = baby1
        context.insert(s1)
        
        let d1 = DiaperChange(timestamp: calendar.date(byAdding: .hour, value: 2, to: day1)!, type: .pee)
        d1.profile = baby1
        context.insert(d1)
        
        let s2 = FeedSession(startTime: day2)
        s2.endTime = calendar.date(byAdding: .minute, value: 15, to: day2)
        s2.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.0 : 120.0, unit: unit)
        s2.profile = baby2
        context.insert(s2)
        
        let d2 = DiaperChange(timestamp: calendar.date(byAdding: .hour, value: 1, to: day2)!, type: .poo)
        d2.profile = baby2
        context.insert(d2)
    }
    
    // DECEMBER (prevYear)
    do {
        let day1 = date(year: prevYear, month: 12, day: 5, hour: 9, minute: 30)
        let day2 = date(year: prevYear, month: 12, day: 28, hour: 18, minute: 10)
        
        let s1 = FeedSession(startTime: day1)
        s1.endTime = calendar.date(byAdding: .minute, value: 25, to: day1)
        s1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 5.0 : 150.0, unit: unit)
        s1.profile = baby1
        context.insert(s1)
        
        let d1 = DiaperChange(timestamp: calendar.date(byAdding: .hour, value: 3, to: day1)!, type: .pee)
        d1.profile = baby1
        context.insert(d1)
        
        let s2 = FeedSession(startTime: day2)
        s2.endTime = calendar.date(byAdding: .minute, value: 20, to: day2)
        s2.amount = Measurement(value: Locale.current.measurementSystem == .us ? 2.5 : 75.0, unit: unit)
        s2.profile = baby2
        context.insert(s2)
        
        let d2 = DiaperChange(timestamp: calendar.date(byAdding: .minute, value: 90, to: day2)!, type: .poo)
        d2.profile = baby2
        context.insert(d2)
    }
    
    // JANUARY (currentYear)
    do {
        let day1 = date(year: currentYear, month: 1, day: 3, hour: 7, minute: 45)
        let day2 = date(year: currentYear, month: 1, day: 17, hour: 12, minute: 5)
        
        let s1 = FeedSession(startTime: day1)
        s1.endTime = calendar.date(byAdding: .minute, value: 18, to: day1)
        s1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.5 : 130.0, unit: unit)
        s1.profile = baby1
        context.insert(s1)
        
        let d1 = DiaperChange(timestamp: calendar.date(byAdding: .hour, value: 2, to: day1)!, type: .pee)
        d1.profile = baby1
        context.insert(d1)
        
        let s2 = FeedSession(startTime: day2)
        s2.endTime = calendar.date(byAdding: .minute, value: 22, to: day2)
        s2.amount = Measurement(value: Locale.current.measurementSystem == .us ? 3.5 : 100.0, unit: unit)
        s2.profile = baby2
        context.insert(s2)
        
        let d2 = DiaperChange(timestamp: calendar.date(byAdding: .minute, value: 70, to: day2)!, type: .pee)
        d2.profile = baby2
        context.insert(d2)
    }
    
    // FEBRUARY (currentYear) — ensure both babies have both a feed and a diaper on each day
    do {
        let day1 = date(year: currentYear, month: 2, day: 2, hour: 6, minute: 50)
        let day2 = date(year: currentYear, month: 2, day: 14, hour: 15, minute: 40)
        
        // Day 1 (Feb 2): baby1 feed + diaper, baby2 feed + diaper
        let b1s1 = FeedSession(startTime: day1)
        b1s1.endTime = calendar.date(byAdding: .minute, value: 20, to: day1)
        b1s1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 3.0 : 90.0, unit: unit)
        b1s1.profile = baby1
        context.insert(b1s1)
        
        let b1d1 = DiaperChange(timestamp: calendar.date(byAdding: .hour, value: 1, to: day1)!, type: .pee)
        b1d1.profile = baby1
        context.insert(b1d1)
        let b1d3 = DiaperChange(timestamp: calendar.date(byAdding: .hour, value: 2, to: day1)!, type: .pee)
        b1d3.profile = baby1
        context.insert(b1d3)

        let b2s1 = FeedSession(startTime: calendar.date(byAdding: .minute, value: 45, to: day1)!)
        b2s1.endTime = calendar.date(byAdding: .minute, value: 65, to: day1) // 20 min later
        b2s1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.0 : 120.0, unit: unit)
        b2s1.profile = baby2
        context.insert(b2s1)
        
        let b2d1 = DiaperChange(timestamp: calendar.date(byAdding: .hour, value: 2, to: day1)!, type: .poo)
        b2d1.profile = baby2
        context.insert(b2d1)
        
        // Day 2 (Feb 14): baby1 feed + diaper, baby2 feed + diaper
        let b1s2 = FeedSession(startTime: day2)
        b1s2.endTime = calendar.date(byAdding: .minute, value: 15, to: day2)
        b1s2.amount = Measurement(value: Locale.current.measurementSystem == .us ? 3.5 : 105.0, unit: unit)
        b1s2.profile = baby1
        context.insert(b1s2)
        
        let b1d2 = DiaperChange(timestamp: calendar.date(byAdding: .minute, value: 80, to: day2)!, type: .pee)
        b1d2.profile = baby1
        context.insert(b1d2)
        
        let b2s2 = FeedSession(startTime: calendar.date(byAdding: .minute, value: 30, to: day2)!)
        b2s2.endTime = calendar.date(byAdding: .minute, value: 50, to: day2)
        b2s2.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.5 : 135.0, unit: unit)
        b2s2.profile = baby2
        context.insert(b2s2)
        
        let b2d2 = DiaperChange(timestamp: calendar.date(byAdding: .minute, value: 95, to: day2)!, type: .poo)
        b2d2.profile = baby2
        context.insert(b2d2)
    }

    return HistoryView()
        .modelContainer(container)
        .environmentObject(AppSettings())
}

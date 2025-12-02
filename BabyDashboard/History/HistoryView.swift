import SwiftUI
import CoreData
import Model

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: AppSettings

    @FetchRequest(
        fetchRequest: HistoryView.makeFeedRequest(),
        animation: .default
    ) private var feedSessions: FetchedResults<FeedSession>

    @FetchRequest(
        fetchRequest: HistoryView.makeDiaperRequest(),
        animation: .default
    ) private var diaperChanges: FetchedResults<DiaperChange>

    @FetchRequest(
        fetchRequest: HistoryView.makeBabyRequest(),
        animation: .default
    ) private var babies: FetchedResults<BabyProfile>

    @State private var eventToEdit: HistoryEvent?
    @State private var selectedBabyID: UUID? = nil
    @State private var selectedEventFilter: EventFilter = .all
    @AppStorage("HistoryView.selectedEventFilter") private var storedEventFilterRaw: String = EventFilter.all.rawValue
    @State private var isShowingFilters = false
    @State private var isShowingAddSheet = false

    private var hasActiveFilters: Bool {
        selectedEventFilter != .all || selectedBabyID != nil
    }

    private var selectedBabyName: String? {
        guard let id = selectedBabyID else { return nil }
        return babies.first(where: { $0.id == id })?.name
    }

    private var eventFilterTitle: String? {
        selectedEventFilter == .all ? nil : selectedEventFilter.title
    }

    private var filtersAccessibilityValue: String {
        var parts: [String] = []
        if let name = selectedBabyName { parts.append(name) }
        if let title = eventFilterTitle { parts.append(title) }
        return parts.isEmpty ? String(localized: "Not applied") : parts.joined(separator: ", ")
    }

    enum EventFilter: String, CaseIterable, Identifiable {
        case all, feed, pee, poo
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

    private var historyEvents: [HistoryEvent] {
        let feedEvents = feedSessions.map { HistoryEvent(from: $0) }
        let diaperEvents = diaperChanges.map { HistoryEvent(from: $0) }
        return (feedEvents + diaperEvents).sorted(by: { $0.date > $1.date })
    }

    private var filteredEvents: [HistoryEvent] {
        historyEvents.filter { event in
            let babyMatches: Bool = {
                guard let selectedBabyID else { return true }
                switch event.type {
                case .feed:
                    if let session = feedSessions.first(where: { $0.objectID == event.underlyingObjectId }) {
                        return session.profile?.id == selectedBabyID
                    }
                    return false
                case .diaper:
                    if let change = diaperChanges.first(where: { $0.objectID == event.underlyingObjectId }) {
                        return change.profile?.id == selectedBabyID
                    }
                    return false
                @unknown default:
                    return false
                }
            }()
            guard babyMatches else { return false }

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

    private struct DaySection: Identifiable {
        let id: Date
        let date: Date
        let events: [HistoryEvent]
        let feedTotalsByBaby: [String: Measurement<UnitVolume>]
        let diaperCountsByBaby: [String: Int]
    }

    private var daySections: [DaySection] {
        let summaries = makeDaySummaries(
            events: filteredEvents,
            feedSessions: Array(feedSessions),
            diaperChanges: Array(diaperChanges),
            calendar: Calendar.current,
            startOfDayHour: settings.startOfDayHour,
            startOfDayMinute: settings.startOfDayMinute
        )
        return summaries.map { summary in
            DaySection(
                id: summary.id,
                date: summary.date,
                events: summary.events,
                feedTotalsByBaby: summary.feedTotalsByBaby,
                diaperCountsByBaby: summary.diaperCountsByBaby
            )
        }
    }

    private struct MonthSection: Identifiable {
        let id: Date
        let monthStart: Date
        let daySections: [DaySection]
    }

    private var monthSections: [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: daySections) { day -> Date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: day.date)) ?? calendar.startOfDay(for: day.date)
        }
        return grouped
            .map { MonthSection(id: $0.key, monthStart: $0.key, daySections: $0.value.sorted(by: { $0.date > $1.date })) }
            .sorted(by: { $0.monthStart > $1.monthStart })
    }

    var body: some View {
        NavigationView {
            List {
                if hasActiveFilters {
                    Section {
                        FilterChipsRow(
                            babyName: selectedBabyName,
                            eventFilterTitle: eventFilterTitle,
                            onClearBaby: { selectedBabyID = nil },
                            onClearEvent: { selectedEventFilter = .all },
                            onClearAll: {
                                selectedBabyID = nil
                                selectedEventFilter = .all
                            }
                        )
                        .listRowInsets(EdgeInsets())
                    }
                }
                ForEach(monthSections) { month in
                    Section {
                        ForEach(month.daySections) { section in
                            Section {
                                ForEach(section.events) { event in
                                    HistoryRowView(event: event)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture { eventToEdit = event }
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
            }
            .overlay {
                if filteredEvents.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock", description: Text("Events will appear here."))
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isShowingFilters = true } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .symbolRenderingMode(.hierarchical)
                            .font(.headline.weight(hasActiveFilters ? .bold : .regular))
                            .foregroundStyle(hasActiveFilters ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                    .accessibilityLabel(Text("Filters"))
//                    .accessibilityValue(Text(filtersAccessibilityValue))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isShowingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add Event"))
                }
            }
            .sheet(isPresented: $isShowingFilters) {
                FilterSheet(
                    babies: Array(babies),
                    selectedBabyID: $selectedBabyID,
                    selectedEventFilter: $selectedEventFilter
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $eventToEdit) { event in
                if let model = findModel(for: event) {
                    HistoryEditView(model: model)
                        .environment(\.managedObjectContext, viewContext)
                        .environmentObject(settings)
                } else {
                    Text("Could not find event to edit.")
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddHistorySheet(
                    context: viewContext,
                    babies: Array(babies),
                    defaultSelectedBabyID: selectedBabyID
                ) {
                    do {
                        try viewContext.save()
                        NearbySyncManager.shared.sendPing()
                    } catch {
                        // Ignore save error for now.
                    }
                    isShowingAddSheet = false
                } onCancel: {
                    isShowingAddSheet = false
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                // Initialize the selected filter from stored value
                selectedEventFilter = EventFilter(rawValue: storedEventFilterRaw) ?? .all
            }
            .onChange(of: selectedEventFilter) { _, newValue in
                // Persist the selected filter whenever it changes
                storedEventFilterRaw = newValue.rawValue
            }
        }
    }

    private func monthHeaderView(for month: MonthSection) -> some View {
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
        .onTapGesture { }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func dayHeaderView(for section: DaySection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(logicalDaySpanTitle(start: section.date))
                .font(.headline)

            let names = Set(section.feedTotalsByBaby.keys).union(section.diaperCountsByBaby.keys)
            ForEach(Array(names).sorted(), id: \.self) { name in
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
        .accessibilityAddTraits(.isHeader)
    }

    private func logicalDaySpanTitle(start: Date, calendar: Calendar = .current) -> String {
        if settings.startOfDayHour == 0 && settings.startOfDayMinute == 0 {
            return start.formatted(.dateTime.month(.abbreviated).day())
        }

        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return start.formatted(.dateTime.month(.abbreviated).day())
        }

        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)
        let endDay = calendar.component(.day, from: end)
        let sameMonth = startMonth == endMonth

        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        if sameMonth {
            return "\(startText) ~ \(endDay)일"
        } else {
            let endText = end.formatted(.dateTime.month(.abbreviated).day())
            return "\(startText) ~ \(endText)"
        }
    }

    private func findModel(for event: HistoryEvent) -> HistoryEditModel? {
        switch event.type {
        case .feed:
            if let session = feedSessions.first(where: { $0.objectID == event.underlyingObjectId }) {
                return .feed(session)
            }
        case .diaper:
            if let change = diaperChanges.first(where: { $0.objectID == event.underlyingObjectId }) {
                return .diaper(change)
            }
        @unknown default:
            return nil
        }
        return nil
    }

    private func deleteEvent(at offsets: IndexSet) {
        let current = filteredEvents
        for index in offsets {
            let event = current[index]
            switch event.type {
            case .feed:
                if let session = feedSessions.first(where: { $0.objectID == event.underlyingObjectId }) {
                    viewContext.delete(session)
                }
            case .diaper:
                if let change = diaperChanges.first(where: { $0.objectID == event.underlyingObjectId }) {
                    viewContext.delete(change)
                }
            @unknown default:
                break
            }
        }
        do {
            try viewContext.save()
            NearbySyncManager.shared.sendPing()
        } catch {
            // ignore for now
        }
    }
}

private struct FilterChipsRow: View {
    let babyName: String?
    let eventFilterTitle: String?
    let onClearBaby: () -> Void
    let onClearEvent: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let babyName {
                    chip(title: babyName, action: onClearBaby)
                }
                if let eventFilterTitle {
                    chip(title: eventFilterTitle, action: onClearEvent)
                }
                Button(action: onClearAll) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                        Text(String(localized: "Clear"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                }
                .accessibilityLabel(Text(String(localized: "Clear all filters")))
            }
            .padding(.vertical, 4)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func chip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "xmark.circle.fill")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(format: String(localized: "Remove filter: %@"), title)))
    }
}

private extension HistoryView {
    static func makeFeedRequest() -> NSFetchRequest<FeedSession> {
        let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return request
    }

    static func makeDiaperRequest() -> NSFetchRequest<DiaperChange> {
        let request: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }

    static func makeBabyRequest() -> NSFetchRequest<BabyProfile> {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}

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
                        ForEach(babies.map { ($0.id, $0.name) }, id: \.0) { id, name in
                            Text(name).tag(UUID?.some(id))
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

    let context: NSManagedObjectContext
    let babies: [BabyProfile]
    let defaultSelectedBabyID: UUID?
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var addType: AddType = .feed
    @State private var selectedBabyID: UUID?
    @State private var feedStart: Date = Date.current
    @State private var feedEnd: Date = Date.current.addingTimeInterval(15 * 60)
    @State private var amountString: String = ""
    @State private var diaperTime: Date = Date.current
    @State private var diaperType: DiaperType = .pee

    private var localeUnit: UnitVolume {
        UnitUtils.preferredUnit
    }

    var body: some View {
        NavigationView {
            Form {
                Section(String(localized: "Event")) {
                    Picker(String(localized: "Type"), selection: $addType) {
                        ForEach(AddType.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "Baby")) {
                    Picker(String(localized: "Baby"), selection: Binding<UUID?>(
                        get: { selectedBabyID },
                        set: { selectedBabyID = $0 }
                    )) {
                        ForEach(babies.map { ($0.id, $0.name) }, id: \.0) { id, name in
                            Text(name).tag(UUID?.some(id))
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
                selectedBabyID = defaultSelectedBabyID ?? babies.first?.id
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
            guard let value = Double(amountString), value >= 0 else { return false }
            return true
        case .diaper:
            return true
        }
    }

    private func save() {
        guard let baby = babies.first(where: { $0.id == selectedBabyID }) else { return }
        switch addType {
        case .feed:
            let session = FeedSession(context: context, startTime: feedStart)
            session.endTime = feedEnd
            if let value = Double(amountString) {
                session.amount = Measurement(value: value, unit: localeUnit)
            }
            session.profile = baby
        case .diaper:
            let change = DiaperChange(context: context, timestamp: diaperTime, type: diaperType)
            change.profile = baby
        }
        onSave()
        dismiss()
    }
}

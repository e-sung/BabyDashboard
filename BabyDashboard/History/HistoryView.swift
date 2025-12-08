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

    @FetchRequest(
        fetchRequest: HistoryView.makeCustomEventRequest(),
        animation: .default
    ) private var customEvents: FetchedResults<CustomEvent>

    @FetchRequest(
        fetchRequest: HistoryView.makeCustomEventTypeRequest(),
        animation: .default
    ) private var customEventTypes: FetchedResults<CustomEventType>

    @State private var eventToEdit: HistoryEvent?
    
    // Search state
    @State private var searchText: String = ""
    @State private var searchTokens: [SearchToken] = []
    @State private var isShowingAddSheet = false
    @State private var isSearchActive: Bool = false
    
    /// Computed tokens for suggestions - shown when search field is active
    private var suggestedTokens: [SearchToken] {
        var tokens: [SearchToken] = []
        
        // Add baby tokens
        for baby in babies {
            tokens.append(.baby(id: baby.id, name: baby.name))
        }
        
        // Add event type tokens
        tokens.append(.feed)
        tokens.append(.pee)
        tokens.append(.poo)
        
        // Add custom event type tokens
        for eventType in customEventTypes {
            tokens.append(.customEvent(emoji: eventType.emoji, name: eventType.name))
        }
        
        // Filter out already selected tokens
        return tokens.filter { !searchTokens.contains($0) }
    }
    
    // MARK: - Search Token Model
    
    enum SearchToken: SearchableToken {
        case baby(id: UUID, name: String)
        case feed
        case pee
        case poo
        case customEvent(emoji: String, name: String)
        
        var id: String {
            switch self {
            case .baby(let id, _):
                return "baby-\(id.uuidString)"
            case .feed:
                return "feed"
            case .pee:
                return "pee"
            case .poo:
                return "poo"
            case .customEvent(let emoji, _):
                return "custom-\(emoji)"
            }
        }
        
        var displayText: String {
            switch self {
            case .baby(_, let name):
                return name
            case .feed:
                return "🍼 Feed"
            case .pee:
                return "💧 Pee"
            case .poo:
                return "💩 Poo"
            case .customEvent(let emoji, let name):
                return "\(emoji) \(name)"
            }
        }
    }
    

    private var historyEvents: [HistoryEvent] {
        let feedEvents = feedSessions.map { HistoryEvent(from: $0) }
        let diaperEvents = diaperChanges.map { HistoryEvent(from: $0) }
        let customEventsList = customEvents.map { HistoryEvent(from: $0) }
        return (feedEvents + diaperEvents + customEventsList).sorted(by: { $0.date > $1.date })
    }

    private var filteredEvents: [HistoryEvent] {
        historyEvents.filter { event in
            // Apply search token filters
            if !searchTokens.isEmpty {
                // Group tokens by category
                let babyTokens = searchTokens.compactMap { token -> UUID? in
                    if case .baby(let id, _) = token { return id }
                    return nil
                }
                let eventTypeTokens = searchTokens.filter { token in
                    switch token {
                    case .feed, .pee, .poo: return true
                    default: return false
                    }
                }
                let customEventTokens = searchTokens.compactMap { token -> String? in
                    if case .customEvent(let emoji, _) = token { return emoji }
                    return nil
                }
                
                // Check baby tokens (OR logic within category)
                if !babyTokens.isEmpty {
                    let eventBabyID: UUID? = {
                        switch event.type {
                        case .feed:
                            return feedSessions.first(where: { $0.objectID == event.underlyingObjectId })?.profile?.id
                        case .diaper:
                            return diaperChanges.first(where: { $0.objectID == event.underlyingObjectId })?.profile?.id
                        case .customEvent:
                            return customEvents.first(where: { $0.objectID == event.underlyingObjectId })?.profile?.id
                        @unknown default:
                            return nil
                        }
                    }()
                    
                    guard let eventBabyID = eventBabyID, babyTokens.contains(eventBabyID) else {
                        return false
                    }
                }
                
                // Check event type tokens (OR logic within category)
                if !eventTypeTokens.isEmpty {
                    let matchesEventType = eventTypeTokens.contains { token in
                        switch (token, event.type) {
                        case (.feed, .feed):
                            return true
                        case (.pee, .diaper):
                            return event.diaperType == .pee
                        case (.poo, .diaper):
                            return event.diaperType == .poo
                        default:
                            return false
                        }
                    }
                    guard matchesEventType else { return false }
                }
                
                // Check custom event tokens (OR logic within category)
                if !customEventTokens.isEmpty {
                    if event.type != .customEvent {
                        return false
                    }
                    let eventEmoji = customEvents.first(where: { $0.objectID == event.underlyingObjectId })?.eventTypeEmoji
                    guard let eventEmoji = eventEmoji, customEventTokens.contains(eventEmoji) else {
                        return false
                    }
                }
            }
            
            // Apply text search
            if !searchText.isEmpty {
                let lowercasedSearch = searchText.lowercased()
                
                // Search in event type name
                let matchesEventTypeName: Bool = {
                    switch event.type {
                    case .feed:
                        return "feed".contains(lowercasedSearch)
                    case .diaper:
                        if event.diaperType == .pee {
                            return "pee".contains(lowercasedSearch)
                        } else if event.diaperType == .poo {
                            return "poo".contains(lowercasedSearch)
                        }
                        return false
                    case .customEvent:
                        if let customEvent = customEvents.first(where: { $0.objectID == event.underlyingObjectId }) {
                            return customEvent.eventTypeName.lowercased().contains(lowercasedSearch)
                        }
                        return false
                    @unknown default:
                        return false
                    }
                }()
                
                // Search in memo text
                let matchesMemo: Bool = {
                    let memoText: String? = {
                        switch event.type {
                        case .feed:
                            return feedSessions.first(where: { $0.objectID == event.underlyingObjectId })?.memoText
                        case .diaper:
                            return diaperChanges.first(where: { $0.objectID == event.underlyingObjectId })?.memoText
                        case .customEvent:
                            return customEvents.first(where: { $0.objectID == event.underlyingObjectId })?.memoText
                        @unknown default:
                            return nil
                        }
                    }()
                    
                    return memoText?.lowercased().contains(lowercasedSearch) ?? false
                }()
                
                guard matchesEventTypeName || matchesMemo else { return false }
            }
            
            return true
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
            .searchable(
                text: $searchText,
                tokens: $searchTokens,
                isPresented: $isSearchActive,
                placement: .automatic,
                prompt: "Search events"
            ) { token in
                Text(token.displayText)
            }
            .tokenSuggestionsOverlay(
                suggestedTokens: suggestedTokens,
                selectedTokens: $searchTokens,
                isSearchActive: isSearchActive
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    // Add Event
                    Button { isShowingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add Event"))
                }
            }
            .sheet(item: $eventToEdit) { event in
                if let model = findModel(for: event) {
                    HistoryEditView(model: model, babies: Array(babies))
                        .environment(\.managedObjectContext, viewContext)
                        .environmentObject(settings)
                } else {
                    Text("Could not find event to edit.")
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                HistoryEditView(model: nil, babies: Array(babies))
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(settings)
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
                        Text(total.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(UnitUtils.baseFractionLength)))))
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
        case .customEvent:
            if let customEvent = customEvents.first(where: { $0.objectID == event.underlyingObjectId }) {
                return .customEvent(customEvent)
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
            case .customEvent:
                if let customEvent = customEvents.first(where: { $0.objectID == event.underlyingObjectId }) {
                    viewContext.delete(customEvent)
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

    static func makeCustomEventRequest() -> NSFetchRequest<CustomEvent> {
        let request: NSFetchRequest<CustomEvent> = CustomEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        return request
    }
    
    static func makeCustomEventTypeRequest() -> NSFetchRequest<CustomEventType> {
        let request: NSFetchRequest<CustomEventType> = CustomEventType.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}

// MARK: - Preview

#Preview {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext
    
    // Create sample baby
    let baby = BabyProfile(context: context, name: "Preview Baby")
    
    // Create sample feed session
    let feed = FeedSession(context: context, startTime: Date().addingTimeInterval(-3600))
    feed.endTime = Date().addingTimeInterval(-3000)
    feed.amount = Measurement(value: 120, unit: .milliliters)
    feed.memoText = "Good feeding #morning"
    feed.profile = baby
    
    // Create sample diaper changes
    let pee = DiaperChange(context: context, timestamp: Date().addingTimeInterval(-1800), type: .pee)
    pee.profile = baby
    
    let poo = DiaperChange(context: context, timestamp: Date().addingTimeInterval(-900), type: .poo)
    poo.memoText = "After meal"
    poo.profile = baby
    
    // Create custom event type and event
    let napType = CustomEventType(context: context, name: "Nap", emoji: "😴")
    let nap = CustomEvent(context: context, timestamp: Date().addingTimeInterval(-5400),
                         eventTypeName: napType.name, eventTypeEmoji: napType.emoji)
    nap.memoText = "Good nap"
    nap.profile = baby
    
    try? context.save()
    
    return HistoryView()
        .environment(\.managedObjectContext, context)
        .environmentObject(AppSettings())
}

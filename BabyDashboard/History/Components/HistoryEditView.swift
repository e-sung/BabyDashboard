import SwiftUI
import CoreData
import Model

enum HistoryEditModel {
    case feed(FeedSession)
    case diaper(DiaperChange)
    case customEvent(CustomEvent)
}

struct HistoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: AppSettings

    let model: HistoryEditModel?
    let babies: [BabyProfile]

    // MARK: - State for Editing & Adding
    @State private var amountString: String = ""
    @State private var memoText: String = ""
    @State private var pendingInsertion: String? = nil
    @State private var startTime: Date = Date.current
    @State private var endTime: Date = Date.current
    @State private var diaperTime: Date = Date.current
    @State private var diaperType: DiaperType = .pee
    @State private var customEventTime: Date = Date.current
    @State private var showingDeleteAlert: Bool = false
    
    // MARK: - State for Adding Only
    enum AddType: String, CaseIterable, Identifiable {
        case feed, diaper, customEvent
        var id: String { rawValue }
        var title: String {
            switch self {
            case .feed: return String(localized: "Feed")
            case .diaper: return String(localized: "Diaper")
            case .customEvent: return String(localized: "Custom Event")
            }
        }
    }
    
    @State private var addType: AddType = .feed
    @State private var selectedBabyID: UUID?
    @State private var selectedCustomEventType: CustomEventType?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CustomEventType.createdAt, ascending: true)],
        animation: .default
    )
    private var availableCustomEventTypes: FetchedResults<CustomEventType>
    @State private var isShowingAddEventType = false

    private let memoSectionID = "MemoSection"

    // MARK: - Computed Properties
    private var isEditing: Bool { model != nil }

    private var feedSession: FeedSession? {
        if case .feed(let session) = model { return session }
        return nil
    }

    private var diaperChange: DiaperChange? {
        if case .diaper(let change) = model { return change }
        return nil
    }

    private var customEvent: CustomEvent? {
        if case .customEvent(let event) = model { return event }
        return nil
    }

    private var hashtagAttributes: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.preferredFont(forTextStyle: .body).bold()
        ]
    }
    
    private var canSave: Bool {
        if isEditing {
            if feedSession != nil {
                return endTime >= startTime
            }
            return true
        } else {
            // Add Mode Validation
            guard let _ = babies.first(where: { $0.id == selectedBabyID }) else { return false }
            switch addType {
            case .feed:
                guard endTime >= startTime else { return false }
                guard let value = Double(amountString), value >= 0 else { return false }
                return true
            case .diaper:
                return true
            case .customEvent:
                return selectedCustomEventType != nil
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                Form {
                    if !isEditing {
                        addModeSections
                    }
                    
                    // Content Sections
                    if isEditing {
                        if let session = feedSession {
                            feedEditor(for: session)
                            memoEditor
                                .id(memoSectionID)
                        } else if let diaper = diaperChange {
                            diaperEditor(for: diaper)
                            memoEditor
                                .id(memoSectionID)
                        } else if let customEvent = customEvent {
                            customEventEditor(for: customEvent)
                            memoEditor
                                .id(memoSectionID)
                        }
                    } else {
                        // Add Mode Editors
                        switch addType {
                        case .feed:
                            feedEditorContent
                            memoEditor
                                .id(memoSectionID)
                        case .diaper:
                            diaperEditorContent
                            memoEditor
                                .id(memoSectionID)
                        case .customEvent:
                            customEventEditorContent
                            if !availableCustomEventTypes.isEmpty {
                                memoEditor
                                    .id(memoSectionID)
                            }
                        }
                    }
                    
                    if isEditing {
                        Section {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Text(String(localized: "Delete Event"))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
                .navigationTitle(isEditing ? "Edit Event" : "Add Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isEditing {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                saveAndDismiss()
                            }
                            .disabled(!canSave)
                            .keyboardShortcut(.defaultAction)
                        }
                    } else {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveAndDismiss()
                            }
                            .disabled(!canSave)
                        }
                    }
                }
                .onAppear(perform: setupInitialState)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    withAnimation {
                        proxy.scrollTo(memoSectionID, anchor: .bottom)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
                    withAnimation {
                        proxy.scrollTo(memoSectionID, anchor: .bottom)
                    }
                }
                .alert(String(localized: "Delete this event?"), isPresented: $showingDeleteAlert) {
                    Button(String(localized: "Delete"), role: .destructive) {
                        deleteAndDismiss()
                    }
                    Button(String(localized: "Cancel"), role: .cancel) { }
                } message: {
                    Text(String(localized: "This action cannot be undone."))
                }
                .sheet(isPresented: $isShowingAddEventType) {
                    if let babyID = selectedBabyID,
                       let baby = babies.first(where: { $0.id == babyID }) {
                        AddCustomEventTypeSheet() {
                            isShowingAddEventType = false
                            updateAvailableCustomEventTypes()
                        }
                        .environment(\.managedObjectContext, viewContext)
                    }
                }
                .onChange(of: selectedBabyID) { _, _ in
                    updateAvailableCustomEventTypes()
                }
            }
        }
    }

    // MARK: - Add Mode Sections
    @ViewBuilder
    private var addModeSections: some View {
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
    }

    // MARK: - Editor Content (Shared or Specific)
    
    // Feed Editor Content (Used for both Edit and Add)
    @ViewBuilder
    private var feedEditorContent: some View {
        Section("Time") {
            DatePicker(
                "Start Time",
                selection: $startTime,
                in: ...endTime,
                displayedComponents: [.hourAndMinute]
            )
            .accessibilityIdentifier("Start Time")
            DatePicker(
                "End Time",
                selection: $endTime,
                in: startTime...Date.distantFuture,
                displayedComponents: [.hourAndMinute]
            )
            .accessibilityIdentifier("End Time")
            if endTime < startTime {
                Text("End time must be after start time.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        Section("Amount") {
            HStack {
                TextField("Amount", text: $amountString)
                    .keyboardType(.decimalPad)
                Text(UnitUtils.preferredUnit.symbol)
            }
        }
    }
    
    // Diaper Editor Content
    @ViewBuilder
    private var diaperEditorContent: some View {
        Section("Time") {
            DatePicker("Time", selection: $diaperTime)
        }
        Section("Type") {
            Picker("Type", selection: $diaperType) {
                Text("Pee").tag(DiaperType.pee)
                Text("Poo").tag(DiaperType.poo)
            }
            .pickerStyle(.segmented)
        }
    }
    
    // Custom Event Editor Content
    @ViewBuilder
    private var customEventEditorContent: some View {
        if !isEditing {
            Section(String(localized: "Event Type")) {
                if availableCustomEventTypes.isEmpty {
                    Button {
                        isShowingAddEventType = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Create First Event Type")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                } else {
                    Picker(String(localized: "Event Type"), selection: $selectedCustomEventType) {
                        ForEach(availableCustomEventTypes) { eventType in
                            HStack {
                                Text(eventType.emoji)
                                Text(eventType.name)
                            }
                            .tag(Optional(eventType))
                        }
                        
                        // Add new event type option
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New EventType...")
                        }
                        .tag(Optional<CustomEventType>.none)
                    }
                    .onChange(of: selectedCustomEventType) { oldValue, newValue in
                        if newValue == nil && oldValue != nil {
                            isShowingAddEventType = true
                            selectedCustomEventType = oldValue
                        }
                    }
                }
            }
        }
        
        if isEditing || !availableCustomEventTypes.isEmpty {
            Section("Time") {
                DatePicker("Time", selection: $customEventTime)
            }
        }
    }

    // MARK: - Existing Editor Wrappers (For Edit Mode)
    @ViewBuilder
    private func feedEditor(for session: FeedSession) -> some View {
        feedEditorContent
        .onChange(of: amountString) { _, newValue in
            if let value = Double(newValue) {
                let unit = UnitUtils.preferredUnit
                session.amount = Measurement(value: value, unit: unit)
            }
        }
    }

    @ViewBuilder
    private func diaperEditor(for diaper: DiaperChange) -> some View {
        diaperEditorContent
    }

    @ViewBuilder
    private func customEventEditor(for event: CustomEvent) -> some View {
        Section("Event Type") {
            HStack {
                Text(event.eventTypeEmoji)
                    .font(.title2)
                Text(event.eventTypeName)
                    .font(.body)
                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        customEventEditorContent
    }

    // MARK: - Memo Editor (Shared)
    @ViewBuilder
    private var memoEditor: some View {
        Section("Memo") {
            HashtagTextView(
                text: $memoText,
                pendingInsertion: $pendingInsertion,
                hashtagAttributes: hashtagAttributes,
                recentHashtags: settings.recentHashtags
            )
            .frame(minHeight: 120)
            .accessibilityLabel(Text("Memo"))
            .onChange(of: memoText) { _, newText in
                if let session = feedSession {
                    session.memoText = newText
                } else if let diaper = diaperChange {
                    diaper.memoText = newText
                } else if let event = customEvent {
                    event.memoText = newText
                }
            }
        }
    }

    private func setupInitialState() {
        if let session = feedSession {
            let preferredUnit = UnitUtils.preferredUnit
            let amount = session.amount?.converted(to: preferredUnit).value ?? 0
            let format = "%.\(UnitUtils.baseFractionLength)f"
            amountString = String(format: format, amount)
            memoText = session.memoText ?? ""
            startTime = session.startTime
            endTime = session.endTime ?? Date.current
        } else if let diaper = diaperChange {
            diaperTime = diaper.timestamp
            diaperType = diaper.diaperType
            memoText = diaper.memoText ?? ""
        } else if let event = customEvent {
            customEventTime = event.timestamp
            memoText = event.memoText ?? ""
        } else {
            // Add Mode Defaults
            selectedBabyID = babies.first?.id
            // Default duration for new feed
            if addType == .feed && endTime <= startTime {
                endTime = startTime.addingTimeInterval(15 * 60)
            }
            updateAvailableCustomEventTypes()
        }
    }
    
    private func updateAvailableCustomEventTypes() {
        if selectedCustomEventType == nil {
            selectedCustomEventType = availableCustomEventTypes.first
        }
    }

    private func saveAndDismiss() {
        if isEditing {
            if let session = feedSession {
                session.startTime = startTime
                session.endTime = endTime
                session.memoText = memoText
                settings.addRecentHashtags(from: memoText)
            } else if let diaper = diaperChange {
                diaper.timestamp = diaperTime
                diaper.diaperType = diaperType
                diaper.memoText = memoText
                settings.addRecentHashtags(from: memoText)
            } else if let event = customEvent {
                event.timestamp = customEventTime
                event.memoText = memoText
                settings.addRecentHashtags(from: memoText)
            }
        } else {
            // Add Mode Save
            guard let baby = babies.first(where: { $0.id == selectedBabyID }) else { return }
            
            switch addType {
            case .feed:
                let session = FeedSession(context: viewContext, startTime: startTime)
                session.endTime = endTime
                if let value = Double(amountString) {
                    session.amount = Measurement(value: value, unit: UnitUtils.preferredUnit)
                }
                session.profile = baby
                session.memoText = memoText.isEmpty ? nil : memoText
                
            case .diaper:
                let change = DiaperChange(context: viewContext, timestamp: diaperTime, type: diaperType)
                change.profile = baby
                change.memoText = memoText.isEmpty ? nil : memoText
                
            case .customEvent:
                guard let eventType = selectedCustomEventType else { return }
                let event = CustomEvent(context: viewContext, timestamp: customEventTime,
                                       eventTypeName: eventType.name,
                                       eventTypeEmoji: eventType.emoji,
                                       eventTypeID: eventType.id)
                event.profile = baby
                event.memoText = memoText.isEmpty ? nil : memoText
            }
            
            if !memoText.isEmpty {
                settings.addRecentHashtags(from: memoText)
            }
        }

        do {
            try viewContext.save()
        } catch {
            assertionFailure(error.localizedDescription)
        }

        NearbySyncManager.shared.sendPing()
        dismiss()
    }

    private func deleteAndDismiss() {
        if let session = feedSession {
            viewContext.delete(session)
        } else if let diaper = diaperChange {
            viewContext.delete(diaper)
        } else if let event = customEvent {
            viewContext.delete(event)
        }
        do {
            try viewContext.save()
        } catch {
            assertionFailure(error.localizedDescription)
        }
        NearbySyncManager.shared.sendPing()
        dismiss()
    }
}

private func unitVolume(from symbolOrName: String) -> UnitVolume? {
    let trimmed = symbolOrName.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    switch lower {
    case "ml", "mL".lowercased(), "milliliter", "milliliters":
        return .milliliters
    case "fl oz", "fl oz", "fl. oz", "fluid ounce", "fluid ounces", "floz":
        return .fluidOunces
    case "l", "liter", "liters":
        return .liters
    case "cup", "cups":
        return .cups
    default:
        return nil
    }
}

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

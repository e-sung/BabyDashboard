import SwiftUI
import Combine
import CoreData
import Model
import WidgetKit
import CloudKit

// MARK: - ContentViewModel (Business Logic)

@MainActor
class ContentViewModel: ObservableObject {
    @Published var hour: String = "00"
    @Published var minute: String = "00"
    @Published var showColon: Bool = true
    @Published var date: String = ""

    private let viewContext: NSManagedObjectContext

    private var feedAnimationTimers: [UUID: Timer] = [:]
    private var diaperAnimationTimers: [UUID: Timer] = [:]
    @Published var feedAnimationStates: [UUID: Bool] = [:]
    @Published var diaperAnimationStates: [UUID: Bool] = [:]

    // Use ShareController directly for any share-related actions
    private let shareController: ShareController

    static var shared = ContentViewModel(context: PersistenceController.shared.viewContext)

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.shareController = .shared

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateClock()
            }
        })
    }

    private func updateClock() {
        let now = Date()
        let calendar = Calendar.current
        let second = calendar.component(.second, from: now)
        showColon = second % 2 == 0

        let components = calendar.dateComponents([.hour, .minute], from: now)
        hour = String(format: "%02d", components.hour ?? 0)
        minute = String(format: "%02d", components.minute ?? 0)
        date = now.formatted(Date.FormatStyle(locale: Locale.autoupdatingCurrent).year(.defaultDigits).month(.abbreviated).day(.defaultDigits).weekday(.wide))
    }
    
    // MARK: - Intents
    
    func startFeeding(for baby: BabyProfile) {
        if let ongoing = baby.inProgressFeedSession {
            viewContext.delete(ongoing)
        }
        let newSession = FeedSession(context: viewContext, startTime: Date())
        newSession.profile = baby
        saveAndPing()
        triggerAnimation(for: baby.id, type: .feed)
    }
    
    func finishFeeding(for baby: BabyProfile, amount: Measurement<UnitVolume>) {
        guard let session = baby.inProgressFeedSession else { return }
        session.endTime = Date()
        session.amount = amount

        saveAndPing()
    }
    
    func cancelFeeding(for baby: BabyProfile) {
        guard let session = baby.inProgressFeedSession else { return }
        viewContext.delete(session)
        saveAndPing()
        triggerAnimation(for: baby.id, type: .feed)
    }
    
    func logDiaperChange(for baby: BabyProfile, type: DiaperType) {
        let newDiaper = DiaperChange(context: viewContext, timestamp: Date(), type: type)
        newDiaper.profile = baby
        saveAndPing()
        triggerAnimation(for: baby.id, type: .diaper)
    }
    
    func setDiaperTime(for baby: BabyProfile, to date: Date) {
        if let lastChange = baby.lastDiaperChange {
            lastChange.timestamp = date
        } else {
            let newDiaper = DiaperChange(context: viewContext, timestamp: date, type: .pee)
            newDiaper.profile = baby
        }
        saveAndPing()
    }
    
    func updateProfileName(for baby: BabyProfile, to newName: String) {
        baby.name = newName
        // Update share title via ShareController
        shareController.updateShareTitleIfNeeded(for: baby, newName: newName)
        _ = shareController.refreshShareInfo(for: baby)
        saveAndPing()
    }
    
    // MARK: - Animation Helpers
    private enum AnimationType { case feed, diaper }
    
    private func triggerAnimation(for babyId: UUID, type: AnimationType) {
        if type == .feed {
            feedAnimationStates[babyId] = true
            feedAnimationTimers[babyId]?.invalidate()
            feedAnimationTimers[babyId] = Timer.scheduledTimer(withTimeInterval: 0.31, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.feedAnimationStates[babyId] = false
                }
            }
        } else {
            diaperAnimationStates[babyId] = true
            diaperAnimationTimers[babyId]?.invalidate()
            diaperAnimationTimers[babyId] = Timer.scheduledTimer(withTimeInterval: 0.31, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.diaperAnimationStates[babyId] = false
                }
            }
        }
    }

    // MARK: - Save + Nudge

    private func saveAndPing() {
        try? viewContext.save()
        NearbySyncManager.shared.sendPing()
        // Update widget cache and reload timelines (using shared helper)
        refreshBabyWidgetSnapshots(using: viewContext)
    }
}

// MARK: - ContentView (UI)

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    // Size class environment for conditional UI
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    @FetchRequest(
        fetchRequest: ContentView.makeBabiesRequest(),
        animation: .default
    ) private var babies: FetchedResults<BabyProfile>

    @State private var editingProfile: BabyProfile? = nil
    @State private var editingDiaperTimeFor: BabyProfile? = nil
    @State private var finishingFeedFor: BabyProfile? = nil
    @State private var changingDiaperFor: BabyProfile? = nil
    @State private var feedAmountString: String = ""
    @State private var showingHistory = false
    @State private var editingFeedSession: FeedSession? = nil

    @State private var highlightedBabyID: NSManagedObjectID? = nil
    @State private var knownBabyIDs: Set<NSManagedObjectID> = []
    @State private var knownBabyNames: [NSManagedObjectID: String] = [:]
    @State private var toastMessage: String? = nil
    @State private var toastDismissWorkItem: DispatchWorkItem? = nil
    @State private var highlightResetWorkItem: DispatchWorkItem? = nil

    // New: analysis navigation
    @State private var showingAnalysis = false
    @State private var showingSettings = false

    // Onboarding/add flow
    @State private var isShowingAddBaby = false

    private let maxBabySlots = 2

    // Detect iPhone to tailor safe area handling
    private var isIPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    var body: some View {
        NavigationView {
            ZStack {
                progressBarsView
                mainVStack
            }
            // Add Baby sheet to allow adding one or two babies
            .sheet(isPresented: $isShowingAddBaby) {
                addBabySheet()
            }
            .sheet(item: $editingProfile) { ProfileView(profile: $0, context: viewContext, shareController: .shared) }
            .sheet(item: $editingDiaperTimeFor, content: diaperEditSheet)
            .sheet(item: $finishingFeedFor, onDismiss: { feedAmountString = "" }) { baby in
                finishFeedSheet(baby: baby)
                    .presentationDetents([.medium, .large]) // allow half-height, expandable to full
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingHistory) { HistoryView() }
            .sheet(item: $editingFeedSession) { session in
                NavigationView {
                    FeedSessionEditView(session: session)
                        .navigationTitle("Edit Feed Session")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { editingFeedSession = nil }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    try? viewContext.save()
                                    NearbySyncManager.shared.sendPing()
                                    editingFeedSession = nil
                                }
                            }
                        }
                }
            }
            // New: present analysis
            .sheet(isPresented: $showingAnalysis) {
                NavigationView {
                    HistoryAnalysisView()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: settings, shareController: .shared)
            }
            .toolbar(content: toolbarContent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
        }
        .navigationViewStyle(.stack)
        .overlay(alignment: .top) {
            if let toastMessage {
                ToastView(message: toastMessage)
                    .padding(.top, isIPhone ? 40 : 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: toastMessage)
            }
        }
        .confirmationDialog("Diaper Change", isPresented: .init(get: { changingDiaperFor != nil }, set: { if !$0 { changingDiaperFor = nil } }), titleVisibility: .visible) {
            if let baby = changingDiaperFor {
                Button("Pee") { viewModel.logDiaperChange(for: baby, type: .pee) }
                Button("Poo") { viewModel.logDiaperChange(for: baby, type: .poo) }
            }
        }
        .onAppear {
            ShareController.shared.primeShareInfoCache()
            cacheKnownBabies()
        }
        .onChange(of: babyObjectIDs) { oldValue, newValue in
            guard oldValue != newValue else { return }
            handleBabyListChange(newValue)
        }
    }
}

private extension ContentView {
    static func makeBabiesRequest() -> NSFetchRequest<BabyProfile> {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}

// MARK: - ContentView Subviews & Logic

private extension ContentView {
    // Treat the UI as "compact" if either size class is compact.
    var isCompact: Bool {
        (hSizeClass == .compact) || (vSizeClass == .compact)
    }

    var progressBarsView: some View {
        HStack(spacing: 0) {
            // Draw progress bars only for existing babies
            ForEach(babies) { baby in
                BabyProgressView(baby: baby, timeScope: baby.feedTerm, feedingColor: .blue)
                    .frame(width: 20)
                    .padding(.leading, baby.id == babies.first?.id ? 10 : 0)
                    // On iPhone, let the trailing bar extend to/under the safe area by removing extra padding
                    .padding(.trailing, baby.id == babies.last?.id ? (isIPhone ? 0 : 10) : 0)
                if baby.id != babies.last?.id {
                    Spacer()
                }
            }
        }
        // Keep left margin the same; on iPhone, remove trailing margin and ignore trailing safe area.
        .padding(.leading, isIPhone ? -20 : 20)
        .padding(.trailing, isIPhone ? 0 : 20)
        .modifier(IgnoreTrailingSafeArea(isIPhone: isIPhone))
    }
    
    var mainVStack: some View {
        VStack {
            Spacer()
            VStack {
                if !isCompact {
                    clockView
                        .offset(x: 0, y: -70)
                }
                Spacer()
                // On iPhone, reduce horizontal padding so the trailing tile can reach the edge
                dashboardView
                    .padding(.horizontal, isIPhone ? 0 : 100)
            }
        }
        // Remove trailing padding on iPhone so trailing child can extend under the safe area
        .padding(.leading, 16)
        .padding(.trailing, isIPhone ? 0 : 16)
        .padding(.vertical, 16)
    }
    
    var clockView: some View {
        VStack {
            HStack(spacing: 16) {
                Text(viewModel.hour)
                Text(":").opacity(viewModel.showColon ? 1 : 0)
                Text(viewModel.minute)
            }
            .font(.system(size: 290))
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            .fontWeight(.bold)

            Text(viewModel.date)
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }

    // Show up to two slots: existing babies first, then "Add Baby" placeholders
    var dashboardView: some View {
        HStack {
            ForEach(0..<maxBabySlots, id: \.self) { index in
                if index < babies.count {
                    let baby = babies[index]
                    let isHighlighted = highlightedBabyID == baby.objectID
                    let tile = BabyStatusView(
                        baby: baby,
                        isFeedAnimating: Binding(
                            get: { viewModel.feedAnimationStates[baby.id, default: false] },
                            set: { viewModel.feedAnimationStates[baby.id] = $0 }
                        ),
                        isDiaperAnimating: Binding(
                            get: { viewModel.diaperAnimationStates[baby.id, default: false] },
                            set: { viewModel.diaperAnimationStates[baby.id] = $0 }
                        ),
                        onFeedTap: { handleFeedTap(for: baby) },
                        onFeedLongPress: { viewModel.cancelFeeding(for: baby) },
                        onDiaperUpdateTap: { changingDiaperFor = baby },
                        onDiaperEditTap: { editingDiaperTimeFor = baby },
                        onNameTap: { editingProfile = baby },
                        onLastFeedTap: { session in
                            editingFeedSession = session
                        }
                    )
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isHighlighted ? Color.accentColor : .clear, lineWidth: 3)
                            .shadow(color: isHighlighted ? Color.accentColor.opacity(0.3) : .clear, radius: 12)
                    )
                    .scaleEffect(isHighlighted && !reduceMotion ? 1.03 : 1)
                    .animation(reduceMotion ? .default : .spring(response: 0.5, dampingFraction: 0.75), value: isHighlighted)
                    // If this is the trailing baby tile, let it extend under the trailing safe area on iPhone
                    if index == min(babies.count, maxBabySlots) - 1 {
                        tile
                            .modifier(IgnoreTrailingSafeArea(isIPhone: isIPhone))
                    } else {
                        tile
                            .modifier(IgnoreTrailingSafeArea(isIPhone: isIPhone))
                    }
                } else {
                    addBabyPlaceholder()
                        .onTapGesture { isShowingAddBaby = true }
                }
                if index < maxBabySlots - 1 {
                    Spacer()
                }
            }
        }
        .font(.system(size: 60))
    }

    // A simple placeholder tile acting as an Add Baby button
    func addBabyPlaceholder() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(.secondary)
            Text(String(localized: "Add Baby"))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 100)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    func diaperEditSheet(baby: BabyProfile) -> some View {
        VStack {
            DatePicker("Select Time", selection: .init(
                get: { baby.lastDiaperChange?.timestamp ?? Date() },
                set: { viewModel.setDiaperTime(for: baby, to: $0) }
            ), displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.wheel)
            .labelsHidden()
            
            Button("Done") { editingDiaperTimeFor = nil }.padding()
        }
    }
    
    @ViewBuilder
    func finishFeedSheet(baby: BabyProfile) -> some View {
        // Bridge the string to a numeric binding for the Stepper
        let amountBinding = Binding<Double>(
            get: {
                Double(feedAmountString) ?? 0
            },
            set: { newValue in
                let clamped = max(0, newValue)
                // Format as integer string
                feedAmountString = clamped.formatted(.number.precision(.fractionLength(0)))
            }
        )

        VStack(spacing: 20) {
            Text(String(localized: "How much did \(baby.name) eat?")).font(.largeTitle)
            
            HStack {
                TextField("Amount", text: $feedAmountString)
                    .font(.system(size: 60))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                Text(currentVolumeUnitSymbol)
                    .font(.title)
            }
            .padding()
            
            // Stepper to increment/decrement by 10
            Stepper(value: amountBinding, in: 0...10_000, step: 10) {
                Text(String(localized: "Adjust by 10"))
            }

            Button("Done") {
                if let amountValue = Double(feedAmountString) {
                    let unit: UnitVolume = (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
                    let measurement = Measurement(value: amountValue, unit: unit)
                    viewModel.finishFeeding(for: baby, amount: measurement)
                    finishingFeedFor = nil
                }
            }
            .font(.title)
            .disabled(feedAmountString.isEmpty)
        }
        .padding()
        .onAppear {
            guard let latestFeedAmount = baby.lastFeedSession?.amountValue else { return }
            feedAmountString = latestFeedAmount.formatted(.number.precision(.fractionLength(0)))
        }
    }
    
    @ViewBuilder
    func confirmationDialogActions(baby: BabyProfile) -> some View {
        Button("Pee") { viewModel.logDiaperChange(for: baby, type: .pee) }
        Button("Poo") { viewModel.logDiaperChange(for: baby, type: .poo) }
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingHistory = true }) {
                Image(systemName: "list.bullet.clipboard")
                    .imageScale(.large)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
                    .imageScale(.large)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingAnalysis = true }) {
                Image(systemName: "chart.xyaxis.line")
                    .imageScale(.large)
            }
            .accessibilityLabel(Text("Analysis"))
        }
    }
    
    func handleFeedTap(for baby: BabyProfile) {
        if baby.inProgressFeedSession != nil {
            finishingFeedFor = baby
        } else {
            viewModel.startFeeding(for: baby)
        }
    }

    // MARK: - Add Baby Sheet

    @ViewBuilder
    func addBabySheet() -> some View {
        NavigationView {
            AddBabyForm { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let newBaby = BabyProfile(context: viewContext, name: trimmed)
                try? viewContext.save()
                _ = ShareController.shared.refreshShareInfo(for: newBaby)
                NearbySyncManager.shared.sendPing()
                isShowingAddBaby = false
            } onCancel: {
                isShowingAddBaby = false
            }
        }
    }
}

// Helper modifier to conditionally ignore only the trailing safe area
private struct IgnoreTrailingSafeArea: ViewModifier {
    let isIPhone: Bool
    func body(content: Content) -> some View {
        if isIPhone {
            content
                .ignoresSafeArea(.container, edges: [.trailing])
        } else {
            content
        }
    }
}

// MARK: - AddBabyForm (inline helper view)

private struct AddBabyForm: View {
    let onSave: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        Form {
            Section(String(localized: "Baby")) {
                TextField(String(localized: "Name"), text: $name)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle(String(localized: "Add Baby"))
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
                    onSave(name)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - Toast + Sharing Notifications

private extension ContentView {
    var babyObjectIDs: [NSManagedObjectID] {
        babies.map { $0.objectID }
    }

    func cacheKnownBabies() {
        knownBabyIDs = Set(babyObjectIDs)
        knownBabyNames = babies.reduce(into: [:]) { partialResult, baby in
            partialResult[baby.objectID] = baby.name
        }
    }

    func handleBabyListChange(_ newIDs: [NSManagedObjectID]) {
        let currentSet = Set(newIDs)
        let added = currentSet.subtracting(knownBabyIDs)
        for identifier in added {
            if let baby = babies.first(where: { $0.objectID == identifier }) {
                _ = ShareController.shared.refreshShareInfo(for: baby)
                notifyBabyAdded(baby)
            }
        }

        let removed = knownBabyIDs.subtracting(currentSet)
        for identifier in removed {
            let name = knownBabyNames[identifier] ?? "Baby"
            notifyBabyRemoved(name: name, objectID: identifier)
        }

        knownBabyIDs = currentSet
        knownBabyNames = babies.reduce(into: [:]) { partialResult, baby in
            partialResult[baby.objectID] = baby.name
        }
    }

    func notifyBabyAdded(_ baby: BabyProfile) {
        debugPrint("[Sharing] Baby added: \(baby.name)")
        let message = String(
            format: NSLocalizedString("%@ was added.", comment: "Toast shown when a shared baby appears"),
            baby.name
        )
        showToast(message)
        highlight(baby: baby)
    }

    func notifyBabyRemoved(name: String, objectID: NSManagedObjectID) {
        debugPrint("[Sharing] Baby removed: \(name)")
        ShareController.shared.clearShareInfo(forObjectID: objectID)
        let message = String(
            format: NSLocalizedString("%@ is no longer available.", comment: "Toast shown when a shared baby disappears"),
            name
        )
        showToast(message)
    }

    func showToast(_ message: String) {
        guard scenePhase == .active else { return }
        toastDismissWorkItem?.cancel()
        withAnimation {
            toastMessage = message
        }
        let workItem = DispatchWorkItem {
            withAnimation {
                toastMessage = nil
            }
        }
        toastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    func highlight(baby: BabyProfile) {
        guard scenePhase == .active else { return }
        highlightResetWorkItem?.cancel()
        let animation = reduceMotion ? Animation.easeInOut(duration: 0.3) : Animation.spring(response: 0.5, dampingFraction: 0.7)
        withAnimation(animation) {
            highlightedBabyID = baby.objectID
        }
        let workItem = DispatchWorkItem {
            withAnimation(animation) {
                highlightedBabyID = nil
            }
        }
        highlightResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 8)
            .accessibilityLabel(Text(message))
    }
}

// MARK: - Preview

#Preview("ContentView") {
    let controller = PersistenceController.preview
    let context = controller.viewContext

    context.performAndWait {
        let baby1 = BabyProfile(context: context, name: "연두")
        let baby2 = BabyProfile(context: context, name: "초원")

        let session1 = FeedSession(context: context, startTime: Date().addingTimeInterval(-60 * 60))
        session1.endTime = Date().addingTimeInterval(-15 * 60)
        session1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.0 : 120.0,
                                      unit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
        session1.profile = baby1

        let diaper1 = DiaperChange(context: context, timestamp: Date().addingTimeInterval(-30 * 60), type: .pee)
        diaper1.profile = baby1

        let session2 = FeedSession(context: context, startTime: Date().addingTimeInterval(-5 * 60))
        session2.profile = baby2

        let diaper2 = DiaperChange(context: context, timestamp: Date().addingTimeInterval(-10 * 60), type: .poo)
        diaper2.profile = baby2

        try? context.save()
    }

    let vm = ContentViewModel(context: context)

    return ContentView(viewModel: vm)
        .environmentObject(AppSettings())
        .environment(\.managedObjectContext, context)
}

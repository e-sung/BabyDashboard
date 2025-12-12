import SwiftUI
import Combine
import CoreData
import Model
import WidgetKit
import CloudKit
import StoreKit

// MainViewModel is defined in ContentView.swift (or should be extracted to its own file)


// MARK: - MainView (UI)

struct MainView: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview


    // Size class environment for conditional UI
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    @FetchRequest(
        fetchRequest: MainView.makeBabiesRequest(),
        animation: .default
    ) private var babies: FetchedResults<BabyProfile>

    @State private var editingProfile: BabyProfile? = nil
    @State private var editingDiaperTimeFor: BabyProfile? = nil
    @State private var finishingFeedFor: BabyProfile? = nil
    @State private var changingDiaperFor: BabyProfile? = nil
    @State private var feedAmountString: String = ""
    @State private var selectedFeedType: FeedType = .babyFormula
    @State private var feedMemoText: String = ""
    @State private var editingFeedSession: FeedSession? = nil
    @State private var editingDiaperChange: DiaperChange? = nil
    
    @State private var sessionToDelete: FeedSession? = nil
    @State private var showDeleteAlert: Bool = false

    @State private var highlightedBabyID: NSManagedObjectID? = nil
    @State private var knownBabyIDs: Set<NSManagedObjectID> = []
    @State private var knownBabyNames: [NSManagedObjectID: String] = [:]
    @State private var toastMessage: String? = nil
    @State private var toastDismissWorkItem: DispatchWorkItem? = nil
    @State private var highlightResetWorkItem: DispatchWorkItem? = nil

    // Daily checklist configuration
    @State private var isConfiguringChecklist = false
    @State private var showingChecklistConfig: BabyProfile? = nil

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
    
    private func removeFromChecklist(emoji: String, for baby: BabyProfile) {
        if let item = baby.dailyChecklistArray.first(where: { $0.eventTypeEmoji == emoji }) {
            viewContext.delete(item)
            do {
                try viewContext.save()
                NearbySyncManager.shared.sendPing()
            } catch {
                viewContext.rollback()
                print("Error removing from checklist: \(error)")
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                dashboardView
            }
            // Add Baby sheet to allow adding one or two babies
            .sheet(isPresented: $isShowingAddBaby) {
                addBabySheet()
            }
            .sheet(item: $editingProfile) { ProfileView(profile: $0, context: viewContext, shareController: .shared) }
            .sheet(item: $editingDiaperTimeFor, content: diaperEditSheet)
            .sheet(item: $finishingFeedFor, onDismiss: { feedAmountString = ""; feedMemoText = "" }) { baby in
                finishFeedSheet(baby: baby)
                    .presentationSizing(.fitted)
                    .presentationDetents(isIPhone ? [.medium, .large] : [])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingFeedSession) { session in
                HistoryEditView(model: .feed(session), babies: Array(babies))
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(settings)
            }
            .sheet(item: $editingDiaperChange) { change in
                HistoryEditView(model: .diaper(change), babies: Array(babies))
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(settings)
            }
            .sheet(item: $showingChecklistConfig) { baby in
                ChecklistConfigurationSheet(baby: baby)
                    .environment(\.managedObjectContext, viewContext)
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
        .overlay(alignment: .topTrailing) {
            if !isIPhone {
                ClockView()
                    .padding(.trailing, 20)
            }
           // Adjust top padding based on device
        }
        .confirmationDialog("Diaper Change", isPresented: .init(get: { changingDiaperFor != nil }, set: { if !$0 { changingDiaperFor = nil } }), titleVisibility: .visible) {
            if let baby = changingDiaperFor {
                Button("Pee") { viewModel.logDiaperChange(for: baby, type: .pee) }
                Button("Poo") { viewModel.logDiaperChange(for: baby, type: .poo) }
            }
        }
        .alert("Do you want to cancel this Feed Session?", isPresented: $showDeleteAlert, presenting: sessionToDelete) { session in
            Button(String(localized: "Yes"), role: .destructive) {
                viewContext.delete(session)
                do {
                    try viewContext.save()
                    NearbySyncManager.shared.sendPing()
                } catch {
                    viewContext.rollback()
                    print("Error deleting feed session: \(error.localizedDescription)")
                }
                sessionToDelete = nil
            }
            Button(String(localized: "No"), role: .cancel) {
                sessionToDelete = nil
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

private extension MainView {
    static func makeBabiesRequest() -> NSFetchRequest<BabyProfile> {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
}

// MARK: - MainView Subviews & Logic

private extension MainView {
    var dashboardView: some View {
        GeometryReader { proxy in
            let isPortrait = proxy.size.height > proxy.size.width
            let layout = isPortrait ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            let scrollAxis: Axis.Set = isPortrait ? .vertical : .horizontal

            ScrollView(scrollAxis, showsIndicators: false) {
                layout {
                    ForEach(0..<maxBabySlots, id: \.self) { index in
                        if index < babies.count {
                            let baby = babies[index]
                            let tile = BabyStatusView(
                                baby: baby,
                                checklistEmojis: baby.dailyChecklistArray.map { $0.eventTypeEmoji },
                                isConfiguringChecklist: isConfiguringChecklist,
                                isFeedAnimating: viewModel.feedAnimationStates[baby.id, default: false],
                                isDiaperAnimating: viewModel.diaperAnimationStates[baby.id, default: false],
                                onFeedTap: { handleFeedTap(for: baby) },
                                onFeedLongPress: { viewModel.cancelFeeding(for: baby) },
                                onDiaperTap: { changingDiaperFor = baby },
                                onNameTap: { editingProfile = baby },
                                onLastFeedTap: { session in
                                    editingFeedSession = session
                                },
                                onLastDiaperTap: { change in
                                    editingDiaperChange = change
                                },
                                onConfigureChecklist: { baby in
                                    showingChecklistConfig = baby
                                },
                                onRemoveFromChecklist: { emoji in
                                    removeFromChecklist(emoji: emoji, for: baby)
                                }
                            )
                            .padding()
                            
                            if !isIPhone {
                                tile.frame(width: proxy.size.width / 2, height: proxy.size.height)
                            } else {
                                tile
                            }
                        } else {
                            addBabyPlaceholder()
                                .onTapGesture { isShowingAddBaby = true }
                        }
                    }
                }
            }
        }
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
                get: { baby.lastDiaperChange?.timestamp ?? Date.current },
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
                feedAmountString = clamped.formatted(.number.precision(.fractionLength(UnitUtils.baseFractionLength)))
            }
        )

        VStack(spacing: 20) {
            // Title
            Text(String(localized: "Log Feed Session"))
                .font(.title)
                .padding(.top, 8)

            // Feed type section
            VStack(alignment: .leading, spacing: 6) {

            }
            .padding(.horizontal)

            // input section
            VStack(alignment: .leading, spacing: 8) {
                Menu {
                    ForEach(FeedType.allCases, id: \.self) { type in
                        Button {
                            selectedFeedType = type
                        } label: {
                            HStack {
                                Text("\(type.emoji) \(type.displayName)")
                                if selectedFeedType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedFeedType.emoji)
                            .font(.title2)
                        Text(selectedFeedType.displayName)
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .accessibilityLabel(String(localized: "Feed type: \(selectedFeedType.displayName)"))

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        TextField("0", text: $feedAmountString)
                            .font(.title.bold())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 120)
                            .accessibilityLabel(Text("Amount"))

                        Text(currentVolumeUnitSymbol)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                    
                    // Stepper buttons
                    Stepper("", value: amountBinding, in: 0...10_000, step: 10)
                        .labelsHidden()
                }
            }

            // Memo input section
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Memo"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField(String(localized: "#hashtags or notes"), text: $feedMemoText, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            

            Spacer()
            
            // Done button
            Button {
                if let amountValue = Double(feedAmountString) {
                    let unit = UnitUtils.preferredUnit
                    let measurement = Measurement(value: amountValue, unit: unit)
                    viewModel.finishFeeding(for: baby, amount: measurement, feedType: selectedFeedType, memoText: feedMemoText)
                    finishingFeedFor = nil
                }
            } label: {
                Text(String(localized: "Log"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(feedAmountString.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(feedAmountString.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .padding()
        .onAppear {
            // Pre-select feed type from last finished session, or default to babyFormula
            selectedFeedType = baby.lastFinishedFeedSession?.feedType ?? .babyFormula
            feedMemoText = ""
            
            guard let latestFeedAmount = baby.lastFinishedFeedSession?.amountValue else {
                return
            }
            feedAmountString = latestFeedAmount.formatted(.number.precision(.fractionLength(UnitUtils.baseFractionLength)))
        }
    }
    
    @ViewBuilder
    func confirmationDialogActions(baby: BabyProfile) -> some View {
        Button("Pee") { viewModel.logDiaperChange(for: baby, type: .pee) }
        Button("Poo") { viewModel.logDiaperChange(for: baby, type: .poo) }
    }
    
    @ToolbarContentBuilder
    func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: isIPhone ? .navigationBarTrailing : .navigationBarLeading) {
            HStack(spacing: 20) {
                if isConfiguringChecklist {
                    Button(action: { isConfiguringChecklist = false }) {
                        Text("Done")
                    }
                } else {
                    Button(action: { isConfiguringChecklist = true }) {
                        Image(systemName: isConfiguringChecklist ? "rectangle.3.group.dashed" : "rectangle.3.group")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Configure Daily Checklist")
                }

            }
        }
        
        // ClockView is now an overlay, so we remove it from here
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

private extension MainView {
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

#Preview("MainView") {
    let controller = PersistenceController.preview
    let context = controller.viewContext

    context.performAndWait {
        let baby1 = BabyProfile(context: context, name: "연두")
        baby1.feedTerm = 100
        let baby2 = BabyProfile(context: context, name: "초원")

        let session1 = FeedSession(context: context, startTime: Date.current.addingTimeInterval(-60 * 60 * 4 - 60 * 48))
        session1.endTime = Date.current.addingTimeInterval(-15 * 60)
        session1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.0 : 120.0,
                                      unit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
        session1.profile = baby1

        let diaper1 = DiaperChange(context: context, timestamp: Date.current.addingTimeInterval(-30 * 60), type: .pee)
        diaper1.profile = baby1

        let session2 = FeedSession(context: context, startTime: Date.current.addingTimeInterval(-5 * 60))
        session2.profile = baby2

        let diaper2 = DiaperChange(context: context, timestamp: Date.current.addingTimeInterval(-10 * 60), type: .poo)
        diaper2.profile = baby2

        try? context.save()
    }

    let vm = MainViewModel(context: context)

    return MainView(viewModel: vm)
        .environmentObject(AppSettings())
        .environment(\.managedObjectContext, context)
}

import SwiftUI
import Combine
import SwiftData

// MARK: - ContentViewModel (Business Logic)

@MainActor
class ContentViewModel: ObservableObject {
    @Published var hour: String = "00"
    @Published var minute: String = "00"
    @Published var showColon: Bool = true
    @Published var date: String = ""
    
    private var modelContext: ModelContext {
        SharedModelContainer.container.mainContext
    }

    private var feedAnimationTimers: [UUID: Timer] = [:]
    private var diaperAnimationTimers: [UUID: Timer] = [:]
    @Published var feedAnimationStates: [UUID: Bool] = [:]
    @Published var diaperAnimationStates: [UUID: Bool] = [:]

    static var shared = ContentViewModel()

    init() {
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
            modelContext.delete(ongoing)
        }
        let newSession = FeedSession(startTime: Date())
        newSession.profile = baby
        modelContext.insert(newSession)
        triggerAnimation(for: baby.id, type: .feed)
    }
    
    func finishFeeding(for baby: BabyProfile, amount: Measurement<UnitVolume>) {
        guard let session = baby.inProgressFeedSession else { return }
        session.endTime = Date()
        session.amount = amount
        baby.lastFeedAmountValue = session.amount?.value
        baby.lastFeedAmountUnitSymbol = session.amount?.unit.symbol
        try? modelContext.save()
    }
    
    func cancelFeeding(for baby: BabyProfile) {
        guard let session = baby.inProgressFeedSession else { return }
        modelContext.delete(session)
        triggerAnimation(for: baby.id, type: .feed)
    }
    
    func logDiaperChange(for baby: BabyProfile, type: DiaperType) {
        let newDiaper = DiaperChange(timestamp: Date(), type: type)
        newDiaper.profile = baby
        modelContext.insert(newDiaper)
        triggerAnimation(for: baby.id, type: .diaper)
    }
    
    func setDiaperTime(for baby: BabyProfile, to date: Date) {
        if let lastChange = baby.lastDiaperChange {
            lastChange.timestamp = date
        } else {
            let newDiaper = DiaperChange(timestamp: date, type: .pee)
            newDiaper.profile = baby
            modelContext.insert(newDiaper)
        }
    }
    
    func updateProfileName(for baby: BabyProfile, to newName: String) {
        baby.name = newName
        try? modelContext.save()
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
}

// MARK: - ContentView (UI)

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings

    @Query(sort: [SortDescriptor(\BabyProfile.name)]) private var babies: [BabyProfile]

    @State private var editingProfile: BabyProfile? = nil
    @State private var editingDiaperTimeFor: BabyProfile? = nil
    @State private var finishingFeedFor: BabyProfile? = nil
    @State private var changingDiaperFor: BabyProfile? = nil
    @State private var feedAmountString: String = ""
    @State private var showingHistory = false
    @State private var editingFeedSession: FeedSession? = nil

    // New: analysis navigation
    @State private var showingAnalysis = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                progressBarsView
                mainVStack
            }
            .task(initialDataTask)
            .sheet(item: $editingProfile) { ProfileEditView(viewModel: viewModel, profile: $0) }
            .sheet(item: $editingDiaperTimeFor, content: diaperEditSheet)
            .sheet(item: $finishingFeedFor, onDismiss: { feedAmountString = "" }, content: finishFeedSheet)
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
                                    try? modelContext.save()
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
                SettingsView(settings: settings)
            }
            .toolbar(content: toolbarContent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
        }
        .navigationViewStyle(.stack)
        .confirmationDialog("Diaper Change", isPresented: .init(get: { changingDiaperFor != nil }, set: { if !$0 { changingDiaperFor = nil } }), titleVisibility: .visible) {
            if let baby = changingDiaperFor {
                Button("Pee") { viewModel.logDiaperChange(for: baby, type: .pee) }
                Button("Poo") { viewModel.logDiaperChange(for: baby, type: .poo) }
            }
        }
    }
}

// MARK: - ContentView Subviews & Logic

private extension ContentView {
    
    @MainActor
    func initialDataTask() async {
        if babies.isEmpty {
            let baby1 = BabyProfile(id: UUID(), name: String(localized: "Baby 1"))
            let baby2 = BabyProfile(id: UUID(), name: String(localized: "Baby 2"))
            modelContext.insert(baby1)
            modelContext.insert(baby2)
        }
    }
    
    var progressBarsView: some View {
        HStack(spacing: 0) {
            ForEach(babies) { baby in
                let lastFeedTime = baby.lastFeedSession?.startTime
                let progress = lastFeedTime == nil ? 0 : (Date().timeIntervalSince(lastFeedTime!) / (3 * 3600))
                VerticalProgressView(progress: progress, timeScope: 3 * 3600)
                    .frame(width: 20)
                    .padding(.leading, baby.id == babies.first?.id ? 10 : 0)
                    .padding(.trailing, baby.id == babies.last?.id ? 10 : 0)
                if baby.id != babies.last?.id {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    var mainVStack: some View {
        VStack {
            Spacer()
            ZStack {
                tappableArea
                VStack {
                    clockView
                        .offset(x: 0, y: -70)
                    Spacer()
                    dashboardView
                        .padding(.horizontal, 100)
                }
            }
        }
        .padding()
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

    var dashboardView: some View {
        HStack {
            ForEach(babies) { baby in
                BabyStatusView(
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
                if baby.id != babies.last?.id {
                    Spacer()
                }
            }
        }
        .font(.system(size: 60))
    }

    var tappableArea: some View {
        HStack(spacing: 0) {
            ForEach(babies) { baby in
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { handleFeedTap(for: baby) }
            }
        }.ignoresSafeArea()
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
            
            Spacer()
        }
        .padding()
        .onAppear {
            if let lastAmount = baby.lastFeedAmountValue {
                feedAmountString = String(lastAmount)
            }
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
}

// MARK: - Preview

#Preview("ContentView") {
    // In-memory SwiftData container for previews
    let schema = Schema([BabyProfile.self, FeedSession.self, DiaperChange.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    let context = container.mainContext

    // Seed sample data
    let baby1 = BabyProfile(id: UUID(), name: "연두")
    let baby2 = BabyProfile(id: UUID(), name: "초원")

    // Baby 1: last finished feed 45 minutes ago, 120 ml, 15 min
    let session1 = FeedSession(startTime: Date().addingTimeInterval(-60 * 60)) // 60 min ago
    session1.endTime = Date().addingTimeInterval(-15 * 60) // ended 15 min after start => 45 min ago
    session1.amount = Measurement(value: Locale.current.measurementSystem == .us ? 4.0 : 120.0,
                                  unit: (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
    session1.profile = baby1
    baby1.lastFeedAmountValue = session1.amount?.value
    baby1.lastFeedAmountUnitSymbol = session1.amount?.unit.symbol

    // Baby 1: last diaper 30 minutes ago
    let diaper1 = DiaperChange(timestamp: Date().addingTimeInterval(-30 * 60), type: .pee)
    diaper1.profile = baby1

    // Baby 2: in-progress feed started 5 minutes ago
    let session2 = FeedSession(startTime: Date().addingTimeInterval(-5 * 60))
    session2.profile = baby2

    // Baby 2: last diaper 10 minutes ago
    let diaper2 = DiaperChange(timestamp: Date().addingTimeInterval(-10 * 60), type: .poo)
    diaper2.profile = baby2

    context.insert(baby1)
    context.insert(baby2)
    context.insert(session1)
    context.insert(diaper1)
    context.insert(session2)
    context.insert(diaper2)

    // Use a fresh view model instance for previews
    let vm = ContentViewModel()

    return ContentView(viewModel: vm)
        .modelContainer(container)
}

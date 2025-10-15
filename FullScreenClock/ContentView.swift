import SwiftUI
import Combine

private let suiteName = "group.sungdoo.fullscreenClock"

class ContentViewModel: ObservableObject {
    @Published var hour: String = "00"
    @Published var minute: String = "00"
    @Published var showColon: Bool = true
    @Published var date: String = ""

    @Published var babyStates: [BabyState] = []
    @Published var profiles: [BabyProfile] = [] {
        didSet {
            saveProfiles()
        }
    }

    private var feedAnimationTimers: [UUID: Timer] = [:]
    private var diaperAnimationTimers: [UUID: Timer] = [:]
    @Published var feedAnimationStates: [UUID: Bool] = [:]
    @Published var diaperAnimationStates: [UUID: Bool] = [:]

    let timeScope: TimeInterval = 3 * 3600

    static var shared = ContentViewModel()

    private var cancellables = Set<AnyCancellable>()
    private let sharedDefaults = UserDefaults(suiteName: suiteName)
    private let profilesKey = "babyProfiles"
    private let diaperKeySuffix = "-diaper"

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init() {
        loadProfiles()
        setupBabyStates()
        loadInitialStates()

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.updateClockAndElapsedTimes()
        })

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateFromDefaults()
                }
            }
            .store(in: &cancellables)
    }

    private func loadProfiles() {
        if let data = sharedDefaults?.data(forKey: profilesKey),
           let decodedProfiles = try? JSONDecoder().decode([BabyProfile].self, from: data), decodedProfiles.count == 2 { // currently support only twin baby scenario
            self.profiles = decodedProfiles
        } else {
            self.profiles = [
                BabyProfile(id: UUID(), name: String(localized: "Baby 1", comment: "Default name for baby 1")),
                BabyProfile(id: UUID(), name: String(localized: "Baby 2", comment: "Default name for baby 2"))
            ]
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            sharedDefaults?.set(data, forKey: profilesKey)
        }
    }

    private func setupBabyStates() {
        babyStates = profiles.map { BabyState(profile: $0, feedState: FeedState(feededAt: nil), diaperState: DiaperState(diaperChangedAt: nil)) }
        profiles.forEach { profile in
            feedAnimationStates[profile.id] = false
            diaperAnimationStates[profile.id] = false
        }
    }

    private func loadInitialStates() {
        for state in babyStates {
            if let date = sharedDefaults?.object(forKey: state.profile.id.uuidString) as? Date {
                state.feedState = FeedState(feededAt: date)
            }
            if let date = sharedDefaults?.object(forKey: state.profile.id.uuidString + diaperKeySuffix) as? Date {
                state.diaperState = DiaperState(diaperChangedAt: date)
            }
        }
    }

    private func updateClockAndElapsedTimes() {
        let now = Date()
        let calendar = Calendar.current
        let second = calendar.component(.second, from: now)
        showColon = second % 2 == 0

        let components = calendar.dateComponents([.hour, .minute], from: now)
        hour = String(format: "%02d", components.hour ?? 0)
        minute = String(format: "%02d", components.minute ?? 0)
        date = now.formatted(Date.FormatStyle(locale: Locale(identifier: "ko")).year(.defaultDigits).month(.abbreviated).day(.defaultDigits).weekday(.wide))

        for state in babyStates {
            if state.feedState.feededAt != nil {
                state.feedState = FeedState(feededAt: state.feedState.feededAt)
            }
            if state.diaperState.diaperChangedAt != nil {
                state.diaperState = DiaperState(diaperChangedAt: state.diaperState.diaperChangedAt)
            }
        }
    }

    @MainActor
    private func updateFromDefaults() {
        // This might need to be more specific if we have many things in UserDefaults
        for state in babyStates {
            if let date = sharedDefaults?.object(forKey: state.profile.id.uuidString) as? Date {
                state.feedState = FeedState(feededAt: date)
            }
            if let date = sharedDefaults?.object(forKey: state.profile.id.uuidString + diaperKeySuffix) as? Date {
                state.diaperState = DiaperState(diaperChangedAt: date)
            }
        }
    }

    func updateFeedTime(for babyId: UUID) {
        let now = Date()
        if let babyState = babyStates.first(where: { $0.profile.id == babyId }) {
            babyState.feedState = FeedState(feededAt: now)
            sharedDefaults?.set(now, forKey: babyId.uuidString)
            
            // Animation
            feedAnimationStates[babyId] = true
            feedAnimationTimers[babyId]?.invalidate()
            feedAnimationTimers[babyId] = Timer.scheduledTimer(withTimeInterval: 0.31, repeats: false) { [weak self] _ in
                self?.feedAnimationStates[babyId] = false
            }
        }
    }
    
    func updateDiaperTime(for babyId: UUID) {
        let now = Date()
        if let babyState = babyStates.first(where: { $0.profile.id == babyId }) {
            babyState.diaperState = DiaperState(diaperChangedAt: now)
            sharedDefaults?.set(now, forKey: babyId.uuidString + diaperKeySuffix)
            
            // Animation
            diaperAnimationStates[babyId] = true
            diaperAnimationTimers[babyId]?.invalidate()
            diaperAnimationTimers[babyId] = Timer.scheduledTimer(withTimeInterval: 0.31, repeats: false) { [weak self] _ in
                self?.diaperAnimationStates[babyId] = false
            }
        }
    }
    
    func setFeedTime(for babyId: UUID, to date: Date) {
        if let babyState = babyStates.first(where: { $0.profile.id == babyId }) {
            babyState.feedState = FeedState(feededAt: date)
            sharedDefaults?.set(date, forKey: babyId.uuidString)
        }
    }

    func updateProfile(profile: BabyProfile, newName: String) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].name = newName
            if let stateIndex = babyStates.firstIndex(where: { $0.profile.id == profile.id }) {
                babyStates[stateIndex].profile = profiles[index]
            }
        }
    }
}




private struct BabyStatusView: View {
    @ObservedObject var babyState: BabyState
    @Binding var isAnimating: Bool
    let onFeedTimeTap: () -> Void
    let onNameTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var feedingTime: String {
        if let date = babyState.feedState.feededAt { return timeFormatter.string(from: date) }
        return String(localized: "--:--")
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack {
                Text("\(babyState.profile.name) ")
                    .font(.system(size: 50))
                    .onTapGesture(perform: onNameTap)
                Text("\(feedingTime)")
                    .fontWeight(.heavy)
                    .onTapGesture(perform: onFeedTimeTap)
            }
            Text(babyState.feedState.elapsedTimeFormatted)
                .font(.title)
                .fontWeight(babyState.feedState.shouldWarn ? .bold : .regular)
                .foregroundColor(babyState.feedState.shouldWarn ? .red : .primary)
        }
        .scaleEffect(isAnimating ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.3), value: isAnimating)
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var editingTarget: UUID?
    @State private var editingProfile: BabyProfile? = nil

    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                if let targetId = editingTarget,
                   let babyState = viewModel.babyStates.first(where: { $0.profile.id == targetId }) {
                    return babyState.feedState.feededAt ?? Date()
                }
                return Date()
            },
            set: { newTime in
                if let targetId = editingTarget {
                    viewModel.setFeedTime(for: targetId, to: newTime)
                }
            }
        )
    }

    var clockView: some View {
        VStack {
            HStack(spacing: 16) {
                Text(viewModel.hour)
                ZStack {
                    Text(":")
                        .opacity(0)
                    Text(":")
                        .opacity(viewModel.showColon ? 1 : 0)
                }
                .offset(y: -10)
                .font(.system(size: 200))
                Text(viewModel.minute)
            }
            .font(.system(size: 290))
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            .fontWeight(.bold)

            Text(viewModel.date)
                .font(.largeTitle)
                .fontWeight(.bold)
                .monospacedDigit()
                .offset(y: -30)
        }
    }

    var dashboardView: some View {
        HStack {
            ForEach(viewModel.babyStates) { babyState in
                let isFeedAnimating = Binding(
                    get: { viewModel.feedAnimationStates[babyState.profile.id, default: false] },
                    set: { viewModel.feedAnimationStates[babyState.profile.id] = $0 }
                )
                let isDiaperAnimating = Binding(
                    get: { viewModel.diaperAnimationStates[babyState.profile.id, default: false] },
                    set: { viewModel.diaperAnimationStates[babyState.profile.id] = $0 }
                )
                BabyStatusView2(
                    babyState: babyState,
                    isFeedAnimating: isFeedAnimating,
                    isDiaperAnimating: isDiaperAnimating,
                    onFeedTimeTap: { self.editingTarget = babyState.profile.id },
                    onDiaperTap: { viewModel.updateDiaperTime(for: babyState.profile.id) },
                    onNameTap: { self.editingProfile = babyState.profile }
                )
                if babyState.id != viewModel.babyStates.last?.id {
                    Spacer()
                }
            }
        }
        .font(.system(size: 60))
        .padding()
        .padding([.leading, .trailing])
        .sheet(item: $editingProfile) { profile in
            ProfileEditView(viewModel: viewModel, profile: profile)
        }
    }

    var tappableArea: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.babyStates) { babyState in
                Color.clear.contentShape(Rectangle()).onTapGesture { viewModel.updateFeedTime(for: babyState.profile.id) }
            }
        }.ignoresSafeArea()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(viewModel.babyStates) { babyState in
                    VerticalProgressView(progress: babyState.feedState.progress, timeScope: viewModel.timeScope)
                        .frame(width: 20)
                        .padding(.leading, babyState.id == viewModel.babyStates.first?.id ? 10 : 0)
                        .padding(.trailing, babyState.id == viewModel.babyStates.last?.id ? 10 : 0)
                    if babyState.id != viewModel.babyStates.last?.id {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            VStack {
                Spacer()
                ZStack {
                    tappableArea
                    VStack {
                        clockView
                            .offset(y: 30)
                        Spacer()
                        dashboardView
                            .padding(.leading, 100)
                            .padding(.trailing, 100)
                    }
                    tappableArea
                        .frame(height: 100)
                }

            }
            .padding()
        }
        .sheet(item: $editingTarget) { _ in
            VStack {
                DatePicker(String(localized: "시간 선택"), selection: timeBinding, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Button(String(localized: "완료")) {
                    self.editingTarget = nil
                }
                .padding()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: createMockViewModel())
    }

    static func createMockViewModel() -> ContentViewModel {
        let vm = ContentViewModel()
        return vm
    }
}

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

    private var animationTimers: [UUID: Timer] = [:]
    @Published var animationStates: [UUID: Bool] = [:]

    let timeScope: TimeInterval = 3 * 3600

    static var shared = ContentViewModel()

    private var cancellables = Set<AnyCancellable>()
    private let sharedDefaults = UserDefaults(suiteName: suiteName)
    private let profilesKey = "babyProfiles"

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    init() {
        loadProfiles()
        setupBabyStates()
        loadInitialFeedingTimes()

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
           var decodedProfiles = try? JSONDecoder().decode([BabyProfile].self, from: data) {
            while decodedProfiles.count < 2 {
                decodedProfiles.append(BabyProfile(id: UUID(), name: "Baby \(decodedProfiles.count + 1)"))
            }
            self.profiles = Array(decodedProfiles.prefix(2))
        } else {
            self.profiles = [
                BabyProfile(id: UUID(), name: "Baby 1"),
                BabyProfile(id: UUID(), name: "Baby 2")
            ]
        }
    }

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            sharedDefaults?.set(data, forKey: profilesKey)
        }
    }

    private func setupBabyStates() {
        babyStates = profiles.map { BabyState(profile: $0) }
        profiles.forEach { profile in
            animationStates[profile.id] = false
        }
    }

    private func loadInitialFeedingTimes() {
        for state in babyStates {
            if let date = sharedDefaults?.object(forKey: state.profile.id.uuidString) as? Date {
                state.lastFeedingTime = date
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
            if let feedingTime = state.lastFeedingTime {
                let interval = now.timeIntervalSince(feedingTime)
                state.elapsedTime = formatElapsedTime(from: interval)
                state.isWarning = interval > (3 * 3600) // 3 hours
                state.progress = interval / (3 * 3600)
            } else {
                state.elapsedTime = ""
                state.isWarning = false
                state.progress = 0.0
            }
        }
    }

    private func formatElapsedTime(from interval: TimeInterval) -> String {
        guard interval >= 0 else { return "" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분 전"
        } else if minutes > 0 {
            return "\(minutes)분 전"
        } else {
            return "방금 전"
        }
    }

    @MainActor
    private func updateFromDefaults() {
        // This might need to be more specific if we have many things in UserDefaults
        for state in babyStates {
            if let date = sharedDefaults?.object(forKey: state.profile.id.uuidString) as? Date {
                state.lastFeedingTime = date
            }
        }
    }

    func updateFeedingTime(for babyId: UUID) {
        let now = Date()
        if let babyState = babyStates.first(where: { $0.profile.id == babyId }) {
            babyState.lastFeedingTime = now
            sharedDefaults?.set(now, forKey: babyId.uuidString)
            
            // Animation
            animationStates[babyId] = true
            animationTimers[babyId]?.invalidate()
            animationTimers[babyId] = Timer.scheduledTimer(withTimeInterval: 0.31, repeats: false) { [weak self] _ in
                self?.animationStates[babyId] = false
            }
        }
    }
    
    func setFeedingTime(for babyId: UUID, to date: Date) {
        if let babyState = babyStates.first(where: { $0.profile.id == babyId }) {
            babyState.lastFeedingTime = date
            sharedDefaults?.set(date, forKey: babyId.uuidString)
        }
    }

    func updateProfile(profile: BabyProfile, newName: String) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].name = newName
            if let stateIndex = babyStates.firstIndex(where: { $0.profile.id == profile.id }) {
                // Recreate the baby state to ensure the view updates.
                let oldState = babyStates[stateIndex]
                let newState = BabyState(profile: profiles[index])
                newState.lastFeedingTime = oldState.lastFeedingTime
                babyStates[stateIndex] = newState
            }
        }
    }
}




private struct BabyStatusView: View {
    @ObservedObject var babyState: BabyState
    @Binding var isAnimating: Bool
    let onTimeTap: () -> Void
    let onNameTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var feedingTime: String {
        if let date = babyState.lastFeedingTime { return timeFormatter.string(from: date) }
        return "--:--"
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            HStack {
                Text("\(babyState.profile.name) ")
                    .font(.system(size: 50))
                Text("\(feedingTime)")
                    .fontWeight(.heavy)
            }
            .onTapGesture(perform: onNameTap)
            Text(babyState.elapsedTime)
                .font(.title)
                .fontWeight(babyState.isWarning ? .bold : .regular)
                .foregroundColor(babyState.isWarning ? .red : .primary)
                .onTapGesture(perform: onTimeTap)
        }
        .scaleEffect(isAnimating ? 0.9 : 1)
        .animation(.easeInOut(duration: 0.3), value: isAnimating)
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var editingTarget: UUID?
    @State private var editingProfile: BabyProfile? = nil
    @State private var isAddingProfile = false

    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                if let targetId = editingTarget,
                   let babyState = viewModel.babyStates.first(where: { $0.profile.id == targetId }) {
                    return babyState.lastFeedingTime ?? Date()
                }
                return Date()
            },
            set: { newTime in
                if let targetId = editingTarget {
                    viewModel.setFeedingTime(for: targetId, to: newTime)
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
            .font(.system(size: 320))
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
                let isAnimating = Binding(
                    get: { viewModel.animationStates[babyState.profile.id, default: false] },
                    set: { viewModel.animationStates[babyState.profile.id] = $0 }
                )
                BabyStatusView(
                    babyState: babyState,
                    isAnimating: isAnimating,
                    onTimeTap: { self.editingTarget = babyState.profile.id },
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
                Color.clear.contentShape(Rectangle()).onTapGesture { viewModel.updateFeedingTime(for: babyState.profile.id) }
            }
        }.ignoresSafeArea()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(viewModel.babyStates) { babyState in
                    VerticalProgressView(progress: babyState.progress, timeScope: viewModel.timeScope)
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
                DatePicker("시간 선택", selection: timeBinding, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Button("완료") {
                    self.editingTarget = nil
                }
                .padding()
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: createMockViewModel())
    }

    static func createMockViewModel() -> ContentViewModel {
        let vm = ContentViewModel()
        vm.profiles = []
//        let baby1 = BabyProfile(id: UUID(), name: "연두")
//        let baby2 = BabyProfile(id: UUID(), name: "초원")
//        vm.profiles = [baby1, baby2]
//        vm.babyStates = [
//            BabyState(profile: baby1),
//            BabyState(profile: baby2)
//        ]
//        vm.babyStates[0].lastFeedingTime = Date().addingTimeInterval(-120)
//        vm.babyStates[1].lastFeedingTime = Date().addingTimeInterval(-7200)
        return vm
    }
}
#endif

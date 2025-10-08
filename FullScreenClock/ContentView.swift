import SwiftUI
import Combine

private let suiteName = "group.sungdoo.fullscreenClock"

class ContentViewModel: ObservableObject {
    @Published var time: String = "00:00"
    @Published var date: String = ""
    
    @Published var 연두수유시간: Date?
    @Published var 초원수유시간: Date?
    
    @Published var 연두_경과시간: String = ""
    @Published var 초원_경과시간: String = ""
    @Published var 연두_경고: Bool = false
    @Published var 초원_경고: Bool = false

    @Published var 연두_progress: Double = 0.0
    @Published var 초원_progress: Double = 0.0

    @Published var animateYeondoo: Bool = false
    @Published var animateChowon: Bool = false

    static var shared = ContentViewModel()

    private var cancellables = Set<AnyCancellable>()
    private let sharedDefaults = UserDefaults(suiteName: suiteName)
    private let yeondooKey = "연두수유시간"
    private let chowonKey = "초원수유시간"

    // Single source of truth for formatting
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // Computed properties for display
    var 연두수유시간_string: String {
        if let date = 연두수유시간 { return timeFormatter.string(from: date) }
        return "--:--"
    }
    var 초원수유시간_string: String {
        if let date = 초원수유시간 { return timeFormatter.string(from: date) }
        return "--:--"
    }

    init() {
        // Load initial values from UserDefaults
        self.연두수유시간 = sharedDefaults?.object(forKey: yeondooKey) as? Date
        self.초원수유시간 = sharedDefaults?.object(forKey: chowonKey) as? Date

        // Timer for the main clock and elapsed time
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            
            self.time = self.timeFormatter.string(from: now)
            self.date = now.formatted(Date.FormatStyle(locale: Locale(identifier: "ko")).year(.defaultDigits).month(.abbreviated).day(.defaultDigits).weekday(.wide))

            if let yeondooTime = self.연두수유시간 {
                let interval = now.timeIntervalSince(yeondooTime)
                self.연두_경과시간 = self.formatElapsedTime(from: interval)
                self.연두_경고 = interval > (3 * 3600) // 3 hours in seconds
                self.연두_progress = interval / (3 * 3600)
            } else {
                self.연두_경과시간 = ""
                self.연두_경고 = false
                self.연두_progress = 0.0
            }
            
            if let chowonTime = self.초원수유시간 {
                let interval = now.timeIntervalSince(chowonTime)
                self.초원_경과시간 = self.formatElapsedTime(from: interval)
                self.초원_경고 = interval > (3 * 3600)
                self.초원_progress = interval / (3 * 3600)
            } else {
                self.초원_경과시간 = ""
                self.초원_경고 = false
                self.초원_progress = 0.0
            }
        })

        // Observe changes from other processes (Siri Intent)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateFromDefaults()
                }
            }
            .store(in: &cancellables)
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
        self.연두수유시간 = sharedDefaults?.object(forKey: yeondooKey) as? Date
        self.초원수유시간 = sharedDefaults?.object(forKey: chowonKey) as? Date
    }

    func update연두수유시간() {
        let now = Date()
        self.연두수유시간 = now
        sharedDefaults?.set(now, forKey: yeondooKey)
        animateYeondoo = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
            self.animateYeondoo = false
        }
    }

    func update초원수유시간() {
        let now = Date()
        self.초원수유시간 = now
        sharedDefaults?.set(now, forKey: chowonKey)
        animateChowon = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
            self.animateChowon = false
        }
    }
    
    func setTime(for target: ContentView.EditingTarget, to date: Date) {
        switch target {
        case .yeondoo:
            self.연두수유시간 = date
            sharedDefaults?.set(date, forKey: yeondooKey)
        case .chowon:
            self.초원수유시간 = date
            sharedDefaults?.set(date, forKey: chowonKey)
        }
    }
}


private struct VerticalProgressView: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background track
                Capsule()
                    .fill(Color.gray.opacity(0.3))

                // Filled progress
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: geometry.size.height * CGFloat(min(max(0, progress), 1))) // Clamp progress between 0 and 1
            }
            .frame(width: 4)
        }
    }
}

private struct BabyStatusView: View {
    let name: String
    let feedingTime: String
    let elapsedTime: String
    let isWarning: Bool
    let isAnimating: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .center) {
            Text("\(name) \(feedingTime)")
                .onTapGesture(perform: onTap)
            Text(elapsedTime)
                .font(.title)
                .fontWeight(isWarning ? .bold : .regular)
                .foregroundColor(isWarning ? .red : .primary)
        }
        .scaleEffect(isAnimating ? 1.2 : 1)
        .animation(.easeInOut(duration: 0.3), value: isAnimating)
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel

    enum EditingTarget: Identifiable {
        case yeondoo, chowon
        var id: Self { self }
    }
    @State private var editingTarget: EditingTarget?

    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                switch editingTarget {
                case .yeondoo:
                    return viewModel.연두수유시간 ?? Date()
                case .chowon:
                    return viewModel.초원수유시간 ?? Date()
                case .none:
                    return Date()
                }
            },
            set: { newTime in
                if let target = editingTarget {
                    viewModel.setTime(for: target, to: newTime)
                }
            }
        )
    }

    var clockView: some View {
        VStack {
            Text(viewModel.date)
                .font(.largeTitle)
                .fontWeight(.bold)
                .monospacedDigit()
                .padding(.top)
            Text(viewModel.time)
                .font(.system(size: 320))
                .lineLimit(1)
                .minimumScaleFactor(0.1)
                .padding()
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }

    var dashboardView: some View {
        HStack {
            BabyStatusView(
                name: "연두",
                feedingTime: viewModel.연두수유시간_string,
                elapsedTime: viewModel.연두_경과시간,
                isWarning: viewModel.연두_경고,
                isAnimating: viewModel.animateYeondoo,
                onTap: { self.editingTarget = .yeondoo }
            )
            Spacer()
            BabyStatusView(
                name: "초원",
                feedingTime: viewModel.초원수유시간_string,
                elapsedTime: viewModel.초원_경과시간,
                isWarning: viewModel.초원_경고,
                isAnimating: viewModel.animateChowon,
                onTap: { self.editingTarget = .chowon }
            )
        }
        .font(.system(size: 60))
        .padding()
    }

    var tappableArea: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle()).onTapGesture { viewModel.update연두수유시간() }
            Color.clear.contentShape(Rectangle()).onTapGesture { viewModel.update초원수유시간() }
        }.ignoresSafeArea()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                VerticalProgressView(progress: viewModel.연두_progress)
                    .frame(width: 20) // Fixed width for the vertical bar
                    .padding(.leading, 10)
                Spacer()
                VerticalProgressView(progress: viewModel.초원_progress)
                    .frame(width: 20) // Fixed width for the vertical bar
                    .padding(.trailing, 10)
            }
            VStack {
                Spacer() // Pushes content to the center vertically
                ZStack {
                    clockView
                    tappableArea
                }
                Spacer()
                dashboardView

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

#Preview {
    ContentView(viewModel: ContentViewModel())
}

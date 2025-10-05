import SwiftUI
import Combine

private let suiteName = "group.sungdoo.fullscreenClock"

class ContentViewModel: ObservableObject {
    @Published var time: String = "00:00"
    @Published var date: String = ""
    
    @Published var 연두수유시간: Date?
    @Published var 초원수유시간: Date?
    
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

        // Timer for the main clock
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            self.time = self.timeFormatter.string(from: now)
            self.date = now.formatted(Date.FormatStyle(locale: Locale(identifier: "ko")).year(.defaultDigits).month(.abbreviated).day(.defaultDigits).weekday(.wide))
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

    @MainActor
    private func updateFromDefaults() {
        self.연두수유시간 = sharedDefaults?.object(forKey: yeondooKey) as? Date
        self.초원수유시간 = sharedDefaults?.object(forKey: chowonKey) as? Date
    }

    func update연두수유시간() {
        let now = Date()
        self.연두수유시간 = now
        sharedDefaults?.set(now, forKey: yeondooKey)
    }

    func update초원수유시간() {
        let now = Date()
        self.초원수유시간 = now
        sharedDefaults?.set(now, forKey: chowonKey)
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

    var body: some View {
        ZStack {
            // The large tappable areas
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { viewModel.update연두수유시간() }
                Color.clear.contentShape(Rectangle()).onTapGesture { viewModel.update초원수유시간() }
            }.ignoresSafeArea()

            // The visible UI
            VStack {
                HStack {
                    Text("연두수유")
                        .bold()
                    Spacer()
                    Text("초원수유")
                        .bold()
                }
                .font(.largeTitle)
                .padding()

                Spacer()
                Text(viewModel.time)
                    .font(.system(size: 320))
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                    .padding()
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text(viewModel.date)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Spacer()
                HStack {
                    Text("연두 \(viewModel.연두수유시간_string)")
                        .onTapGesture { self.editingTarget = .yeondoo }
                    Spacer()
                    Text("초원 \(viewModel.초원수유시간_string)")
                        .onTapGesture { self.editingTarget = .chowon }
                }
                .font(.system(size: 60))
                .padding()
            }
        }
        .sheet(item: $editingTarget) { _ in
            VStack {
                DatePicker("시간 선택", selection: timeBinding, displayedComponents: .hourAndMinute)
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
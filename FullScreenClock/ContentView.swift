import SwiftUI
import Combine

private let suiteName = "group.sungdoo.fullscreenClock"

class ContentViewModel: ObservableObject {
    @Published var time: String = "00:00"
    @Published var date: String = ""
    
    @AppStorage("연두수유시간", store: UserDefaults(suiteName: suiteName)) var 연두수유시간: String = "00:00" {
        didSet { objectWillChange.send() }
    }
    @AppStorage("초원수유시간", store: UserDefaults(suiteName: suiteName)) var 초원수유시간: String = "00:00" {
        didSet { objectWillChange.send() }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let sharedDefaults = UserDefaults(suiteName: suiteName)

    init() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.time = Date().formatted(
                Date.FormatStyle()
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
            )
            self.date = Date().formatted(Date.FormatStyle(locale: Locale(identifier: "ko")).year(.defaultDigits).month(.abbreviated).day(.defaultDigits).weekday(.wide))
        })

        // Observe changes from other processes (like the App Intent)
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
        let yeondoo = sharedDefaults?.string(forKey: "연두수유시간") ?? "00:00"
        if self.연두수유시간 != yeondoo {
            self.연두수유시간 = yeondoo
        }
        
        let chowon = sharedDefaults?.string(forKey: "초원수유시간") ?? "00:00"
        if self.초원수유시간 != chowon {
            self.초원수유시간 = chowon
        }
    }

    func update연두수유시간() {
        self.연두수유시간 = time
    }

    func update초원수유시간() {
        self.초원수유시간 = time
    }
}


struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel

    // For Time Picker
    enum EditingTarget: Identifiable {
        case yeondoo, chowon
        var id: Self { self }
    }
    @State private var editingTarget: EditingTarget?
    @State private var tempDate = Date()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button {
                        viewModel.update연두수유시간()
                    } label: {
                        Text("연두수유")
                            .bold()
                    }
                    Spacer()
                    Button {
                        viewModel.update초원수유시간()
                    } label: {
                        Text("초원수유")
                            .bold()
                    }
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
                    Text("연두 \(viewModel.연두수유시간)")
                        .onTapGesture {
                            self.tempDate = timeFormatter.date(from: viewModel.연두수유시간) ?? Date()
                            self.editingTarget = .yeondoo
                        }
                    Spacer()
                    Text("초원 \(viewModel.초원수유시간)")
                        .onTapGesture {
                            self.tempDate = timeFormatter.date(from: viewModel.초원수유시간) ?? Date()
                            self.editingTarget = .chowon
                        }
                }
                .font(.system(size: 60))
                .padding()
            }
        }
        .sheet(item: $editingTarget) { target in
            VStack {
                DatePicker("시간 선택", selection: $tempDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Button("완료") {
                    let newTime = timeFormatter.string(from: self.tempDate)
                    switch target {
                    case .yeondoo:
                        viewModel.연두수유시간 = newTime
                    case .chowon:
                        viewModel.초원수유시간 = newTime
                    }
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

//
//  ContentView.swift
//  FullScreenClock
//
//  Created by 류성두 on 10/1/25.
//

import SwiftUI
import Intents

// Define activity types
let yeondooActivityType = "sungdoo.fullscreenClock.yeondooFeeding"
let chowonActivityType = "sungdoo.fullscreenClock.chowonFeeding"

class ContentViewModel: ObservableObject {
    @Published var time: String = "00:00"
    @Published var date: String = ""
    @Published var 연두수유시간: String = "00:00"
    @Published var 초원수유시간: String = "00:00"

    init() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
            self.time = Date().formatted(
                Date.FormatStyle()
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
            )
            self.date = Date().formatted(Date.FormatStyle(locale: Locale(identifier: "ko")).year(.defaultDigits).month(.abbreviated).day(.defaultDigits).weekday(.wide))
        })
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
        VStack {
            HStack {
                Button {
                    viewModel.update연두수유시간()
                } label: {
                    Text("연두수유")
                }
                .userActivity(yeondooActivityType) { activity in
                    activity.title = "연두 수유 간 기록"
                    activity.isEligibleForSearch = true
                    activity.isEligibleForPrediction = true
                    activity.suggestedInvocationPhrase = "연두 수유"
                    let suggestions = INShortcut(userActivity: activity)
                    INVoiceShortcutCenter.shared.setShortcutSuggestions([suggestions])
                }
                Spacer()
                Button {
                    viewModel.update초원수유시간()
                } label: {
                    Text("초원수유")
                }
                .userActivity(chowonActivityType) { activity in
                    activity.title = "초원 수유 시간 기록"
                    activity.isEligibleForSearch = true
                    activity.isEligibleForPrediction = true
                    activity.suggestedInvocationPhrase = "초원 수유"
                    let suggestions = INShortcut(userActivity: activity)
                    INVoiceShortcutCenter.shared.setShortcutSuggestions([suggestions])
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
            VStack(alignment: .leading) {
                VStack {
                    Text("연두: \(viewModel.연두수유시간)")
                        .onTapGesture {
                            self.tempDate = timeFormatter.date(from: viewModel.연두수유시간) ?? Date()
                            self.editingTarget = .yeondoo
                        }
                    Text("초원: \(viewModel.초원수유시간)")
                        .onTapGesture {
                            self.tempDate = timeFormatter.date(from: viewModel.초원수유시간) ?? Date()
                            self.editingTarget = .chowon
                        }
                }
                .font(.system(size: 60))
            }
            .padding()
        }
        .onContinueUserActivity(yeondooActivityType) { _ in
            viewModel.update연두수유시간()
        }
        .onContinueUserActivity(chowonActivityType) { _ in
            viewModel.update초원수유시간()
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

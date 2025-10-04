//
//  ContentView.swift
//  FullScreenClock
//
//  Created by 류성두 on 10/1/25.
//

import SwiftUI

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

    var body: some View {
        VStack {
            HStack {
                Button {
                    viewModel.update연두수유시간()
                } label: {
                    Text("연두수유")
                }
                Spacer()
                Button {
                    viewModel.update초원수유시간()
                } label: {
                    Text("초원수유")
                }
            }
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
            VStack {
                Text("최근 수유")
                    .padding()
                    .font(.system(size: 50))
                VStack {
                    Text("연두: \(viewModel.연두수유시간)")
                    Text("초원: \(viewModel.초원수유시간)")
                }
                .font(.largeTitle)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel())
}

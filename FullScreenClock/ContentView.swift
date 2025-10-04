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
}


struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack {
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
        }
    }
}

#Preview {
    ContentView(viewModel: ContentViewModel())
}

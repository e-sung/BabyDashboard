import SwiftUI

struct ClockView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            ClockContent(date: context.date)
        }
    }
    
    struct ClockContent: View {
        let date: Date
        
        var body: some View {
            HStack(spacing: 0) {
                Text(date, formatter: hourFormatter)
                Text(":")
                    .opacity(shouldShowColon ? 1 : 0)
                    .offset(y: -4)
                Text(date, formatter: minuteFormatter)
            }
            .font(.system(size: 50))
            .fontWeight(.bold)
        }
        
        private var shouldShowColon: Bool {
            // Blink every 2 seconds: visible for 1s, invisible for 1s
            let timeInterval = date.timeIntervalSince1970
            return Int(timeInterval) % 2 == 0
        }
        
        private var hourFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH"
            return formatter
        }
        
        private var minuteFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "mm"
            return formatter
        }
    }
}

#Preview {
    ClockView()
}

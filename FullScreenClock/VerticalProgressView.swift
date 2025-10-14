import SwiftUI

struct VerticalProgressView: View {
    let progress: Double
    let timeScope: TimeInterval

    private var indicatorInterval: TimeInterval { 30 * 60 } // 30 minutes

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Determine colors and progress based on overflow
                let isOverdue = progress > 1.0
                let trackColor = isOverdue ? Color.green.opacity(0.5) : Color.gray.opacity(0.3)
                let fillColor = isOverdue ? Color.red : Color.green
                let displayProgress = isOverdue ? progress - 1.0 : progress

                // Background track
                Capsule().fill(trackColor)

                // Filled progress
                Capsule()
                    .fill(fillColor)
                    .frame(height: geometry.size.height * CGFloat(min(max(0, displayProgress), 1)))
                
                // Indicators
                ForEach(0..<Int(timeScope / indicatorInterval), id: \.self) { index in
                    let interval = TimeInterval(index + 1) * indicatorInterval
                    let isHourMark = (index + 1) % 2 == 0
                    
                    if interval < timeScope {
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.primary.opacity(0.3))
                                .frame(width: 10, height: isHourMark ? 3 : 1)
                                .offset(y: -geometry.size.height * CGFloat(interval / timeScope))
                        }
                    }
                }
            }
            .frame(width: 10)
            .clipShape(Capsule())
            .animation(.linear(duration: 0.6), value: progress)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        VStack {
            Text("Zero")
            VerticalProgressView(progress: 0.0, timeScope: 3 * 3600)
        }
        VStack {
            Text("Overdue")
            VerticalProgressView(progress: 1.2, timeScope: 3 * 3600)
        }
        VStack {
            Text("2 Hours")
            VerticalProgressView(progress: 2/3, timeScope: 3 * 3600)
        }
    }
    .padding()
    .frame(height: 300)
}

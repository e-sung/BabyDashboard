import SwiftUI

struct VerticalProgressView: View {
    let progress: Double
    let timeScope: TimeInterval

    // New: allow caller to customize the fill color (defaults to green).
    var progressColor: Color = .green
    // New: allow hiding track and background indicators (for overlays).
    var drawTrackAndBackground: Bool = true

    private var indicatorInterval: TimeInterval { 30 * 60 } // 30 minutes

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Determine colors and progress based on overflow
                let isOverdue = progress > 1.0
                let trackColor = isOverdue ? Color.green : Color.gray.opacity(0.3)
                let fillColor = isOverdue ? Color.red : progressColor
                let displayProgress = isOverdue ? progress - 1.0 : progress

                // Background track (optional)
                if drawTrackAndBackground {
                    Capsule().fill(trackColor)
                }

                // Background Indicators (optional)
                if drawTrackAndBackground {
                    indicators(geometry: geometry, color: Color.primary.opacity(0.8))
                }

                // Filled progress
                let filledHeight = geometry.size.height * CGFloat(min(max(0, displayProgress), 1))
                Capsule()
                    .fill(fillColor)
                    .frame(height: filledHeight)
                
                // Foreground Indicators masked into the filled area
                indicators(geometry: geometry, color: Color.black)
                    .mask(
                        VStack {
                            Spacer()
                            Rectangle()
                                .frame(height: filledHeight)
                        }
                    )
            }
            .frame(width: 10)
            .clipShape(Capsule())
            .animation(.linear(duration: 0.6), value: progress)
        }
    }

    private func indicators(geometry: GeometryProxy, color: Color) -> some View {
        ForEach(0..<Int(timeScope / indicatorInterval), id: \.self) { index in
            let interval = TimeInterval(index + 1) * indicatorInterval
            let isHourMark = (index + 1) % 2 == 0
            
            if interval < timeScope {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(color)
                        .frame(width: 10, height: isHourMark ? 3 : 1)
                        .offset(y: -geometry.size.height * CGFloat(interval / timeScope))
                }
            }
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
        VStack {
            Text("Blue only (no track)")
            VerticalProgressView(progress: 0.4, timeScope: 3 * 3600, progressColor: .blue, drawTrackAndBackground: false)
        }
    }
    .padding()
    .frame(height: 300)
}

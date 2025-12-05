import SwiftUI

struct StatusToggleButton: View {
    let emoji: String
    let isOn: Bool
    var isInConfigMode: Bool = false
    let action: () -> Void
    var onDelete: (() -> Void)? = nil
    
    @State private var wiggleAngle: Double = 0
    
    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.body)
                .padding(12)
                .background(isOn ? Color.green.opacity(0.7) : Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityHint(isInConfigMode ? "editable" : "")
        .overlay(alignment: .topLeading) {
            if isInConfigMode, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.white, .red)
                        .font(.system(size: 20))
                }
                .offset(x: -8, y: -8)
                .zIndex(1)
                .accessibilityLabel("Remove from checklist")
            }
        }
        .rotationEffect(.degrees(wiggleAngle))
        .onAppear {
            if isInConfigMode {
                startWiggling()
            }
        }
        .onChange(of: isInConfigMode) { _, newValue in
            if newValue {
                startWiggling()
            } else {
                stopWiggling()
            }
        }
    }
    
    private func startWiggling() {
        withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
            wiggleAngle = 2
        }
    }
    
    private func stopWiggling() {
        withAnimation(.easeInOut(duration: 0.1)) {
            wiggleAngle = 0
        }
    }
}

#if DEBUG
struct StatusToggleButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack {
                StatusToggleButton(emoji: "💊", isOn: true, action: {})
                StatusToggleButton(emoji: "💊", isOn: false, action: {})
            }
            
            HStack {
                StatusToggleButton(emoji: "💊", isOn: true, isInConfigMode: true, action: {}, onDelete: {})
                StatusToggleButton(emoji: "🛁", isOn: false, isInConfigMode: true, action: {}, onDelete: {})
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif


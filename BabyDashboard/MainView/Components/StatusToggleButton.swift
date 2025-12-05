import SwiftUI

struct StatusToggleButton: View {
    let emoji: String
    let isOn: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.body)
                .padding(12)
                .background(isOn ? Color.green.opacity(0.7) : Color.gray.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#if DEBUG
struct StatusToggleButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            StatusToggleButton(emoji: "💊", isOn: true, action: {})
            StatusToggleButton(emoji: "💊", isOn: false, action: {})
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

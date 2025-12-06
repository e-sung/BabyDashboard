import SwiftUI

struct PlaceholderToggleButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle")
                .font(.title)
                .padding(8)
                .tint(.gray)
                .background(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [4]))
                        .foregroundColor(.gray.opacity(0.5))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("Add daily checklist item")
        .accessibilityIdentifier("PlaceholderChecklistButton")
    }
}

#if DEBUG
struct PlaceholderToggleButton_Previews: PreviewProvider {
    static var previews: some View {
        PlaceholderToggleButton(action: {})
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

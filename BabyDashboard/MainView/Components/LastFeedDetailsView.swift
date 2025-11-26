import SwiftUI

/// A view to display details of the last feeding session.
struct LastFeedDetailsView: View {
    /// The amount consumed in the last session. e.g., "120 ml"
    let amountString: String
    
    /// The duration of the last session. e.g., "15 min"
    let durationString: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(amountString) in \(durationString)")}
            .font(.body)
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    LastFeedDetailsView(amountString: "150 ml", durationString: "25 min")
        .padding()
}

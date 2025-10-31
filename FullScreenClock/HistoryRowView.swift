import SwiftUI
import SwiftData
import Model

struct HistoryRowView: View {
    let event: HistoryEvent

    var body: some View {
        HStack(spacing: 15) {
            if event.type == .diaper {
                Image("diaper")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            if event.type == .feed {
                Text("🍼")
                    .font(.title2)
                    .frame(width: 30)
            }

            VStack(alignment: .leading) {
                Text(event.babyName)
                    .font(.headline)
                Text(event.details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(event.date, style: .time)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var iconName: String {
        switch event.type {
        case .feed:
            return "baby.bottle.fill"
        case .diaper:
            return "person.fill"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch event.type {
        case .feed:
            return .blue
        case .diaper:
            return event.diaperType == .poo ? .brown : .green
        @unknown default:
            return .gray
        }
    }
}

#Preview("Light") {
    // No need to construct PersistentIdentifier directly.
    let now = Date()
    
    let feedEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-15 * 60),
        babyName: "연두",
        type: .feed,
        details: Locale.current.measurementSystem == .us
            ? "4.0 fl oz over 15 min"
            : "120.0 ml over 15 min",
        diaperType: nil,
        underlyingObjectId: nil
    )
    
    let diaperPeeEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-30 * 60),
        babyName: "초원",
        type: .diaper,
        details: String(localized: "Pee"),
        diaperType: .pee,
        underlyingObjectId: nil
    )
    
    let diaperPooEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-5 * 60),
        babyName: "연두",
        type: .diaper,
        details: String(localized: "Poo"),
        diaperType: .poo,
        underlyingObjectId: nil
    )

    return List {
        HistoryRowView(event: feedEvent)
        HistoryRowView(event: diaperPeeEvent)
        HistoryRowView(event: diaperPooEvent)
    }
}

#Preview("Dark") {
    let now = Date()
    
    let feedEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-15 * 60),
        babyName: "연두",
        type: .feed,
        details: Locale.current.measurementSystem == .us
            ? "4.0 fl oz over 15 min"
            : "120.0 ml over 15 min",
        diaperType: nil,
        underlyingObjectId: nil
    )
    
    let diaperPeeEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-30 * 60),
        babyName: "초원",
        type: .diaper,
        details: "Pee",
        diaperType: .pee,
        underlyingObjectId: nil
    )
    
    let diaperPooEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-5 * 60),
        babyName: "연두",
        type: .diaper,
        details: "Poo",
        diaperType: .poo,
        underlyingObjectId: nil
    )

    return List {
        HistoryRowView(event: feedEvent)
        HistoryRowView(event: diaperPeeEvent)
        HistoryRowView(event: diaperPooEvent)
    }
    .environment(\.colorScheme, .dark)
}

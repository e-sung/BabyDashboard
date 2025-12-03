import SwiftUI
import Model

struct HistoryRowView: View {
    let event: HistoryEvent

    var body: some View {
        HStack(spacing: 15) {
            // Custom events use emoji from the event type
            if event.type == .customEvent, let emoji = event.emoji {
                Text(emoji)
                    .font(.title2)
                    .frame(width: 30)
            }
            else if event.type == .diaper {
                Image("diaper")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            else if event.type == .feed {
                Text("🍼")
                    .font(.title2)
                    .frame(width: 30)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(event.babyName)
                    .font(.headline)

                Text(event.details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if !event.hashtags.isEmpty {
                    FlowLayout(spacing: 6, rowSpacing: 6) {
                        ForEach(event.hashtags, id: \.self) { tag in
                            TagCapsule(text: tag.hasPrefix("#") ? tag : "#\(tag)")
                        }
                    }
                    .accessibilityElement(children: .contain)
                }
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

// MARK: - Wrapped Tag Capsule

private struct TagCapsule: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
            .accessibilityLabel(Text("Hashtag \(text)"))
    }
}

// MARK: - Simple Flow Layout (wraps items across lines)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

    init(spacing: CGFloat = 6, rowSpacing: CGFloat = 6) {
        self.spacing = spacing
        self.rowSpacing = rowSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lines: [[CGSize]] = [[]]
        var currentLineWidth: CGFloat = 0
        var currentLineMaxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentLineWidth > 0, currentLineWidth + spacing + size.width > maxWidth {
                // New line
                lines.append([])
                currentLineWidth = 0
                currentLineMaxHeight = 0
            }
            lines[lines.count - 1].append(size)
            currentLineWidth = (currentLineWidth == 0) ? size.width : (currentLineWidth + spacing + size.width)
            currentLineMaxHeight = max(currentLineMaxHeight, size.height)
        }

        // Compute total size
        let lineHeights = lines.map { line in line.map(\.height).max() ?? 0 }
        let totalHeight = lineHeights.reduce(0) { partial, h in
            partial == 0 ? h : (partial + rowSpacing + h)
        }
        // Width is either the proposed width or the max line width encountered
        let measuredWidth: CGFloat
        if maxWidth.isFinite {
            measuredWidth = maxWidth
        } else {
            // If unconstrained, compute max line width
            var maxLineWidth: CGFloat = 0
            for line in lines {
                let w = line.reduce(0) { partial, size in
                    partial == 0 ? size.width : (partial + spacing + size.width)
                }
                maxLineWidth = max(maxLineWidth, w)
            }
            measuredWidth = maxLineWidth
        }
        return CGSize(width: measuredWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineMaxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                // Wrap to next line
                x = bounds.minX
                y += lineMaxHeight + rowSpacing
                lineMaxHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += (x == bounds.minX ? 0 : spacing) + size.width
            lineMaxHeight = max(lineMaxHeight, size.height)
        }
    }
}

#Preview("Light") {
    // No need to construct PersistentIdentifier directly.
    let now = Date.current
    
    let feedEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-15 * 60),
        babyName: "연두",
        type: .feed,
        details: Locale.current.measurementSystem == .us
            ? "4.0 fl oz over 15 min"
            : "120.0 ml over 15 min",
        diaperType: nil,
        underlyingObjectId: nil,
        hashtags: ["#night", "#dreamfeed", "#longtagexample", "#milk", "#happy", "#growth"]
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
    let now = Date.current
    
    let feedEvent = HistoryEvent(
        id: UUID(),
        date: now.addingTimeInterval(-15 * 60),
        babyName: "연두",
        type: .feed,
        details: Locale.current.measurementSystem == .us
            ? "4.0 fl oz over 15 min"
            : "120.0 ml over 15 min",
        diaperType: nil,
        underlyingObjectId: nil,
        hashtags: ["#late", "#cluster", "#wrapwrapwrap", "#tag"]
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

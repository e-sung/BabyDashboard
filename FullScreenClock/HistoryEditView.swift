import SwiftUI
import SwiftData
import Model

struct HistoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings

    let model: any PersistentModel
    
    // State for the amount text field
    @State private var amountString: String = ""

    // Memo editing
    @State private var memoText: String = ""
    @State private var pendingInsertion: String? = nil

    // Keyboard handling
    private let memoSectionID = "MemoSection"

    // Styling for hashtags in the memo editor
    private var hashtagAttributes: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.preferredFont(forTextStyle: .body).bold()
        ]
    }

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                Form {
                    if let session = model as? FeedSession {
                        feedEditor(for: session)
                        memoEditor(for: session)
                            .id(memoSectionID)
                    } else if let diaper = model as? DiaperChange {
                        diaperEditor(for: diaper)
                    }
                }
                .navigationTitle("Edit Event")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            saveAndDismiss()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    // Note: The hashtag bar is now provided by the UITextView's inputAccessoryView,
                    // not by SwiftUI's keyboard toolbar.
                }
                .onAppear(perform: setupInitialState)
                // When the keyboard appears or changes frame, scroll the memo section into view
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    withAnimation {
                        proxy.scrollTo(memoSectionID, anchor: .bottom)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
                    withAnimation {
                        proxy.scrollTo(memoSectionID, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func feedEditor(for session: FeedSession) -> some View {
        Section("Time") {
            DatePicker("Start Time", selection: .init(get: { session.startTime }, set: { session.startTime = $0 }))
            DatePicker("End Time", selection: .init(get: { session.endTime ?? session.startTime }, set: { session.endTime = $0 }))
        }
        Section("Amount") {
            HStack {
                TextField("Amount", text: $amountString)
                    .keyboardType(.decimalPad)
                Text(session.amountUnitSymbol ?? currentVolumeUnitSymbol)
            }
        }
        .onChange(of: amountString) { _, newValue in
            if let value = Double(newValue) {
                // Use existing unit if present; otherwise infer from locale
                let unit: UnitVolume = {
                    if let symbol = session.amountUnitSymbol, let u = unitVolume(from: symbol) {
                        return u
                    }
                    return (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
                }()
                // Write to stored fields so SwiftData publishes changes
                session.amountValue = value
                session.amountUnitSymbol = unit.symbol
            } else {
                session.amountValue = nil
                session.amountUnitSymbol = nil
            }
        }
    }

    @ViewBuilder
    private func memoEditor(for session: FeedSession) -> some View {
        Section("Memo") {
            HashtagTextView(
                text: $memoText,
                pendingInsertion: $pendingInsertion,
                hashtagAttributes: hashtagAttributes,
                recentHashtags: settings.recentHashtags
            )
            .frame(minHeight: 120)
            .accessibilityLabel(Text("Memo"))
            .onChange(of: memoText) { _, newText in
                // Keep session memo live-updated
                session.memoText = newText
            }
        }
    }

    @ViewBuilder
    private func diaperEditor(for diaper: DiaperChange) -> some View {
        Section("Time") {
            DatePicker("Time", selection: .init(get: { diaper.timestamp }, set: { diaper.timestamp = $0 }))
        }
        Section("Type") {
            Picker("Type", selection: .init(get: { diaper.type }, set: { diaper.type = $0 })) {
                Text("Pee").tag(DiaperType.pee)
                Text("Poo").tag(DiaperType.poo)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private func setupInitialState() {
        if let session = model as? FeedSession {
            if let value = session.amountValue {
                // Preserve a single decimal like before
                amountString = String(format: "%.1f", value)
            }
            memoText = session.memoText ?? ""
        }
    }

    private func saveAndDismiss() {
        if let session = model as? FeedSession {
            // Persist memo text
            session.memoText = memoText
            // Update MRU hashtags
            settings.addRecentHashtags(from: memoText)
        }
        try? modelContext.save()
        NearbySyncManager.shared.sendPing()
        dismiss()
    }
}

// Local helper to decode a UnitVolume from a symbol/name
private func unitVolume(from symbolOrName: String) -> UnitVolume? {
    let trimmed = symbolOrName.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    switch lower {
    case "ml", "mL".lowercased(), "milliliter", "milliliters":
        return .milliliters
    case "fl oz", "fl oz", "fl. oz", "fluid ounce", "fluid ounces", "floz":
        return .fluidOunces
    case "l", "liter", "liters":
        return .liters
    case "cup", "cups":
        return .cups
    default:
        return nil
    }
}

// UIKit font helper
private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

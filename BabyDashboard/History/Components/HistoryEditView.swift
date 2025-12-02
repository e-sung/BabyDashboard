import SwiftUI
import CoreData
import Model

enum HistoryEditModel {
    case feed(FeedSession)
    case diaper(DiaperChange)
}

struct HistoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: AppSettings

    let model: HistoryEditModel

    @State private var amountString: String = ""
    @State private var memoText: String = ""
    @State private var pendingInsertion: String? = nil
    @State private var startTime: Date = Date.current
    @State private var endTime: Date = Date.current
    @State private var diaperTime: Date = Date.current
    @State private var diaperType: DiaperType = .pee

    private let memoSectionID = "MemoSection"

    private var feedSession: FeedSession? {
        if case .feed(let session) = model { return session }
        return nil
    }

    private var diaperChange: DiaperChange? {
        if case .diaper(let change) = model { return change }
        return nil
    }

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
                    if let session = feedSession {
                        feedEditor(for: session)
                        memoEditor(for: session)
                            .id(memoSectionID)
                    } else if let diaper = diaperChange {
                        diaperEditor(for: diaper)
                    }
                }
                .navigationTitle("Edit Event")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            saveAndDismiss()
                        }
                        .disabled({
                            if feedSession != nil {
                                return endTime < startTime
                            }
                            return false
                        }())
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .onAppear(perform: setupInitialState)
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
            DatePicker(
                "Start Time",
                selection: $startTime,
                in: ...endTime,
                displayedComponents: [.hourAndMinute]
            )
            .accessibilityIdentifier("Start Time")
            DatePicker(
                "End Time",
                selection: $endTime,
                in: startTime...Date.distantFuture,
                displayedComponents: [.hourAndMinute]
            )
            .accessibilityIdentifier("End Time")
            if endTime < startTime {
                Text("End time must be after start time.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
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
                let unit: UnitVolume = {
                    if let symbol = session.amountUnitSymbol,
                       let resolved = unitVolume(from: symbol) {
                        return resolved
                    }
                    return (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
                }()
                session.amountValue = value
                session.amountUnitSymbol = unit.symbol
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
                session.memoText = newText
            }
        }
    }

    @ViewBuilder
    private func diaperEditor(for diaper: DiaperChange) -> some View {
        Section("Time") {
            DatePicker("Time", selection: $diaperTime)
        }
        Section("Type") {
            Picker("Type", selection: $diaperType) {
                Text("Pee").tag(DiaperType.pee)
                Text("Poo").tag(DiaperType.poo)
            }
            .pickerStyle(.segmented)
        }
    }

    private func setupInitialState() {
        if let session = feedSession {
            amountString = String(format: "%.1f", session.amountValue)
            memoText = session.memoText ?? ""
            startTime = session.startTime
            endTime = session.endTime ?? Date.current
        } else if let diaper = diaperChange {
            diaperTime = diaper.timestamp
            diaperType = diaper.diaperType
        }
    }

    private func saveAndDismiss() {
        if let session = feedSession {
            session.startTime = startTime
            session.endTime = endTime
            session.memoText = memoText
            settings.addRecentHashtags(from: memoText)
        } else if let diaper = diaperChange {
            diaper.timestamp = diaperTime
            diaper.diaperType = diaperType
        }

        do {
            try viewContext.save()
        } catch {
            assertionFailure(error.localizedDescription)
        }

        NearbySyncManager.shared.sendPing()
        dismiss()
    }
}

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

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

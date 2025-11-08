import SwiftUI
import CoreData
import Model

struct FeedSessionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var session: FeedSession

    @State private var endTime: Date
    @State private var amountString: String

    private var durationString: String {
        let start = session.startTime
        let duration = endTime.timeIntervalSince(start)
        guard duration > 0 else { return "--" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: duration) ?? "--"
    }

    init(session: FeedSession) {
        self.session = session
        _endTime = State(initialValue: session.endTime ?? Date())
        _amountString = State(initialValue: session.amount.map { String(format: "%.1f", $0.value) } ?? "")
    }

    var body: some View {
        Form {
            Section("Time") {
                DatePicker(
                    "Started",
                    selection: .constant(session.startTime),
                    displayedComponents: [.hourAndMinute]
                )
                .disabled(true)
                DatePicker("Ended", selection: $endTime, displayedComponents: [.hourAndMinute])
                LabeledContent("Duration", value: durationString)
            }

            Section("Amount") {
                HStack {
                    TextField("Amount", text: $amountString)
                        .keyboardType(.decimalPad)
                    Text(session.amount?.unit.symbol ?? currentVolumeUnitSymbol)
                }
            }
        }
        .onDisappear(perform: save)
    }

    private func save() {
        session.endTime = endTime
        if let value = Double(amountString) {
            let unit = session.amount?.unit ?? ((Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
            let newAmount = Measurement(value: value, unit: unit)
            session.amount = newAmount
        }

        do {
            try session.managedObjectContext?.save()
        } catch {
            // If save fails we silently ignore in edit sheet to avoid user-facing crash in preview builds.
        }
    }
}

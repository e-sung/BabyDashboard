import SwiftUI
import SwiftData
import Model

struct HistoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    let model: any PersistentModel
    
    // State for the amount text field
    @State private var amountString: String = ""

    var body: some View {
        NavigationView {
            Form {
                if let session = model as? FeedSession {
                    feedEditor(for: session)
                } else if let diaper = model as? DiaperChange {
                    diaperEditor(for: diaper)
                }
            }
            .navigationTitle("Edit Event")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: setupInitialState)
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
                Text(session.amount?.unit.symbol ?? currentVolumeUnitSymbol)
            }
        }
        .onChange(of: amountString) { _, newValue in
            if let value = Double(newValue) {
                let unit = session.amount?.unit ?? ((Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters)
                session.amount = Measurement(value: value, unit: unit)
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
            if let amount = session.amount {
                amountString = String(format: "%.1f", amount.value)
            }
        }
    }
}

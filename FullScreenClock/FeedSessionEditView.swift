import SwiftUI
import SwiftData

struct FeedSessionEditView: View {
    @Environment(\.dismiss) var dismiss
    
    @Bindable var session: FeedSession
    
    @State private var endTime: Date
    @State private var amountString: String
    
    private var durationString: String {
        let duration = endTime.timeIntervalSince(session.startTime)
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
                DatePicker("Started", selection: .constant(session.startTime), displayedComponents: [.hourAndMinute])
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
            
            // For consistency, update the last feed amount on the profile
            session.profile?.lastFeedAmountValue = session.amount?.value
            session.profile?.lastFeedAmountUnitSymbol = session.amount?.unit.symbol
        }
    }
}

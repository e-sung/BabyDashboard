
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    // Create a Date binding from the hour/minute integers
    private var startOfDayBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = settings.startOfDayHour
                components.minute = settings.startOfDayMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                settings.startOfDayHour = components.hour ?? 7
                settings.startOfDayMinute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Daily Summaries")) {
                    DatePicker("Start of Day", selection: startOfDayBinding, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

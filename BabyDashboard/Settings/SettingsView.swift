import SwiftUI
import UniformTypeIdentifiers
import CoreData
import Model
import AppIntents

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shareController: ShareController
    @Environment(\.managedObjectContext) private var viewContext

    #if DEBUG
    @State private var showingNukeConfirm = false
    @State private var nukeError: String?
    #endif

    // Create a Date binding from the hour/minute integers
    private var startOfDayBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = settings.startOfDayHour
                components.minute = settings.startOfDayMinute
                return Calendar.current.date(from: components) ?? Date.current
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                settings.startOfDayHour = components.hour ?? 7
                settings.startOfDayMinute = components.minute ?? 0
            }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Daily Summaries")) {
                DatePicker("Start of Day", selection: startOfDayBinding, displayedComponents: .hourAndMinute)
            }

            Section(header: Text("Measurement Unit")) {
                Picker("Unit", selection: Binding(
                    get: { UnitUtils.preferredUnit },
                    set: { UnitUtils.preferredUnit = $0 }
                )) {
                    ForEach([UnitVolume.milliliters, UnitVolume.fluidOunces], id: \.self) { unit in
                        Text(unit.symbol).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Appearance")) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "textformat.size.smaller")
                        Spacer()
                        Text(settings.preferredFontScale.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "textformat.size.larger")
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: {
                                Double(AppFontScale.allCases.firstIndex(of: settings.preferredFontScale) ?? 0)
                            },
                            set: { newValue in
                                let index = Int(round(newValue))
                                if index >= 0 && index < AppFontScale.allCases.count {
                                    settings.preferredFontScale = AppFontScale.allCases[index]
                                }
                            }
                        ),
                        in: 0...Double(AppFontScale.allCases.count - 1),
                        step: 1
                    )
                    .accessibilityIdentifier("FontSizeSlider")
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Siri & Shortcuts")) {
                Text("Add shortcuts to quickly start and finish feedings, or log diaper changes using Siri or the Shortcuts app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ShortcutsLink()
            }

            #if DEBUG
            Section(header: Text("Debug – Danger Zone")) {
                Button(role: .destructive) {
                    showingNukeConfirm = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
            }
            #endif
        }
        .readableContentWidth(maxWidth: 720)
        .navigationTitle("Settings")
        #if DEBUG
        .alert("Delete All Data?", isPresented: $showingNukeConfirm) {
            Button("Delete", role: .destructive) {
                do {
                    try nukeAllData()
                } catch {
                    nukeError = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This deletes all feed sessions, diaper changes, cached amounts, and resets app settings. This action cannot be undone.")
        }
        .alert("Nuke Failed", isPresented: Binding(get: { nukeError != nil }, set: { if !$0 { nukeError = nil } })) {
            Button("OK", role: .cancel) { nukeError = nil }
        } message: {
            Text(nukeError ?? "")
        }
        #endif
    }

    #if DEBUG
    private func nukeAllData() throws {
        let feedFetch: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
        let feeds = try viewContext.fetch(feedFetch)
        feeds.forEach(viewContext.delete)

        let diaperFetch: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
        let diapers = try viewContext.fetch(diaperFetch)
        diapers.forEach(viewContext.delete)

        if viewContext.hasChanges {
            try viewContext.save()
        }

        settings.resetAll()
        clearUserDefaultsStores()
    }

    private func clearUserDefaultsStores() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        let groupDefaults = appGroupUserDefaults()
        for key in groupDefaults.dictionaryRepresentation().keys {
            groupDefaults.removeObject(forKey: key)
        }
        groupDefaults.synchronize()
    }
    #endif
}

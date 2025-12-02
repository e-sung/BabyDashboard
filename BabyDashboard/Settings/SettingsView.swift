import SwiftUI
import UniformTypeIdentifiers
import CoreData
import Model
import AppIntents

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var shareController: ShareController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    // Kind used for both export and import
    private enum DataKind: String {
        case feeds
        case diapers

        var displayName: String {
            switch self {
            case .feeds: return "Feeds"
            case .diapers: return "Diapers"
            }
        }
    }

    // Export / Import state
    @State private var isExporting = false
    @State private var exportKind: DataKind? = nil
    @State private var preparedExport = CSVDocument(data: Data())

    @State private var isImporting = false
    @State private var importKind: DataKind? = nil

    @State private var importReport: HistoryCSVService.ImportReport?
    @State private var importError: String?
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
        NavigationView {
            Form {
                Section(header: Text("Daily Summaries")) {
                    DatePicker("Start of Day", selection: startOfDayBinding, displayedComponents: .hourAndMinute)
                }

                Section(header: Text("Siri & Shortcuts")) {
                    Text("Add shortcuts to quickly start and finish feedings, or log diaper changes using Siri or the Shortcuts app.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ShortcutsLink()
                }

                Section(header: Text("Data – Feeds")) {
                    Button {
                        Task { await export(kind: .feeds) }
                    } label: {
                        Label("Export Feeds CSV", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        importKind = .feeds
                        isImporting = true
                    } label: {
                        Label("Import Feeds CSV", systemImage: "square.and.arrow.down")
                    }
                }

                Section(header: Text("Data – Diapers")) {
                    Button {
                        Task { await export(kind: .diapers) }
                    } label: {
                        Label("Export Diapers CSV", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        importKind = .diapers
                        isImporting = true
                    } label: {
                        Label("Import Diapers CSV", systemImage: "square.and.arrow.down")
                    }
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
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            // Exporter (single document, presented when preparedExport is set)
            .fileExporter(
                isPresented: $isExporting,
                document: preparedExport,
                contentType: .commaSeparatedText,
                defaultFilename: defaultExportFilename()
            ) { result in
                if case .failure(let error) = result {
                    importError = "Export failed: \(error.localizedDescription)"
                }
                exportKind = nil
            }
            // Single importer for both kinds
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        do {
                            let didStart = url.startAccessingSecurityScopedResource()
                            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
                            let data = try Data(contentsOf: url)
                            if importKind == .feeds {
                                let report = try await HistoryCSVService.decodeFeedsAndImport(data: data, context: viewContext)
                                importReport = report
                            } else if importKind == .diapers {
                                let report = try await HistoryCSVService.decodeDiapersAndImport(data: data, context: viewContext)
                                importReport = report
                            }
                            importKind = nil
                        } catch {
                            importError = "Import failed: \(error.localizedDescription)"
                        }
                    }
                case .failure(let error):
                    importError = "Import failed: \(error.localizedDescription)"
                }
            }
            .alert("Import Complete", isPresented: Binding(get: { importReport != nil }, set: { if !$0 { importReport = nil } })) {
                Button("OK", role: .cancel) { importReport = nil }
            } message: {
                if let r = importReport {
                    Text("""
Inserted Feeds: \(r.insertedFeeds)
Updated Feeds: \(r.updatedFeeds)
Skipped Feeds: \(r.skippedFeeds)
Inserted Diapers: \(r.insertedDiapers)
Skipped Diapers: \(r.skippedDiapers)
Created Babies: \(r.createdBabies)
Errors: \(r.errors.count)
\(r.errors.prefix(5).joined(separator: "\n"))
""")
                }
            }
            .alert("Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
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

    // MARK: - Export helpers

    private func export(kind: DataKind) async {
        do {
            let data: Data
            switch kind {
            case .feeds:
                data = try HistoryCSVService.encodeFeeds(context: viewContext)
            case .diapers:
                data = try HistoryCSVService.encodeDiapers(context: viewContext)
            }
            preparedExport = CSVDocument(data: data)
            exportKind = kind
            isExporting = true
        } catch {
            importError = "Export failed: \(error.localizedDescription)"
        }
    }

    private func defaultExportFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = df.string(from: Date.current)
        let kindName = exportKind?.displayName ?? "Data"
        return "Export-\(kindName)-\(stamp).csv"
    }

    private func timestampString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        return df.string(from: Date.current)
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


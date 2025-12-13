import SwiftUI
import UniformTypeIdentifiers
import CoreData
import Model

/// A self-contained view that handles all data export/import operations.
/// Present this as a sheet from HistoryView when the user taps the hamburger menu.
struct ExportImportDialogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Data Kind
    
    enum DataKind: String, CaseIterable, Identifiable {
        case feeds
        case diapers
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .feeds: return "Feeds"
            case .diapers: return "Diapers"
            }
        }
        
        var emoji: String {
            switch self {
            case .feeds: return "🍼"
            case .diapers: return "🧷"
            }
        }
    }
    
    // MARK: - State
    
    @State private var isLoading = false
    @State private var loadingMessage = ""
    
    // Export state
    @State private var isExporting = false
    @State private var exportKind: DataKind? = nil
    @State private var preparedExport = CSVDocument(data: Data())
    
    // Import state
    @State private var isImporting = false
    @State private var importKind: DataKind? = nil
    
    // Results
    @State private var importReport: HistoryCSVService.ImportReport?
    @State private var errorMessage: String?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await export(kind: .feeds) }
                    } label: {
                        Label("Export Feeds", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isLoading)
                    
                    Button {
                        importKind = .feeds
                        isImporting = true
                    } label: {
                        Label("Import Feeds", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isLoading)
                } header: {
                    Label("Feeds", systemImage: "drop.fill")
                }
                
                Section {
                    Button {
                        Task { await export(kind: .diapers) }
                    } label: {
                        Label("Export Diapers", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isLoading)
                    
                    Button {
                        importKind = .diapers
                        isImporting = true
                    } label: {
                        Label("Import Diapers", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isLoading)
                } header: {
                    Label("Diapers", systemImage: "leaf.fill")
                }
            }
            .navigationTitle("Export / Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    loadingOverlay
                }
            }
            // File exporter
            .fileExporter(
                isPresented: $isExporting,
                document: preparedExport,
                contentType: .commaSeparatedText,
                defaultFilename: defaultExportFilename()
            ) { result in
                if case .failure(let error) = result {
                    errorMessage = "Export failed: \(error.localizedDescription)"
                }
                exportKind = nil
            }
            // File importer
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleImport(result: result)
                }
            }
            // Import report alert
            .alert("Import Complete", isPresented: Binding(
                get: { importReport != nil },
                set: { if !$0 { importReport = nil } }
            )) {
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
            // Error alert
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(loadingMessage)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Export
    
    private func export(kind: DataKind) async {
        isLoading = true
        loadingMessage = "Exporting \(kind.displayName)..."
        
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
            isLoading = false
            isExporting = true
        } catch {
            isLoading = false
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }
    
    private func defaultExportFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = df.string(from: Date.current)
        let kindName = exportKind?.displayName ?? "Data"
        return "Export-\(kindName)-\(stamp).csv"
    }
    
    // MARK: - Import
    
    private func handleImport(result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isLoading = true
            loadingMessage = "Importing \(importKind?.displayName ?? "data")..."
            
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
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
            
            isLoading = false
            
        case .failure(let error):
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    ExportImportDialogView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

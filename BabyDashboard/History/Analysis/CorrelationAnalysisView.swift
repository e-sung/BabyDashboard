import SwiftUI
import CoreData
import Model
import Charts

struct CorrelationAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Configuration State
    @State private var selectedHashtags: Set<String> = []
    @State private var availableHashtags: [String] = []
    @State private var showingHashtagSelection = false
    
    @State private var targetType: TargetType = .customEvent
    @State private var targetCustomEventTypeID: UUID?
    @State private var targetHashtag: String = ""
    
    @State private var timeWindow: TimeInterval = 3600 // 1 hour default
    @State private var selectedBabyID: UUID?
    
    // Analysis State
    @State private var results: [CorrelationResult] = []
    @State private var isAnalyzing = false
    @State private var analysisTask: Task<Void, Never>?
    
    enum TargetType: String, CaseIterable, Identifiable {
        case customEvent = "Custom Event"
        case customEventWithHashtag = "Custom Event + Hashtag"
        case feedAmount = "Feed Amount"
        
        var id: String { rawValue }
    }
    
    // Data Source for Pickers
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CustomEventType.name, ascending: true)],
        animation: .default)
    private var customEventTypes: FetchedResults<CustomEventType>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BabyProfile.name, ascending: true)],
        animation: .default)
    private var babies: FetchedResults<BabyProfile>
    
    var body: some View {
        Form {
            Section("Configuration") {
                Picker("Baby", selection: $selectedBabyID) {
                    Text("All Babies").tag(UUID?.none)
                    ForEach(babies) { baby in
                        Text(baby.name).tag(UUID?.some(baby.id))
                    }
                }
                .onChange(of: selectedBabyID) { _, _ in loadHashtags() }
                
                Button {
                    showingHashtagSelection = true
                } label: {
                    HStack {
                        Text("Source Hashtags")
                        Spacer()
                        Text("\(selectedHashtags.count) selected")
                            .foregroundStyle(.secondary)
                    }
                }
                .sheet(isPresented: $showingHashtagSelection) {
                    NavigationView {
                        HashtagSelectionView(availableHashtags: availableHashtags, selectedHashtags: $selectedHashtags)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        showingHashtagSelection = false
                                    }
                                }
                            }
                    }
                }
                
                Picker("Target Type", selection: $targetType) {
                    ForEach(TargetType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                if targetType == .customEvent || targetType == .customEventWithHashtag {
                    Picker("Event Type", selection: $targetCustomEventTypeID) {
                        Text("Select Event...").tag(UUID?.none)
                        ForEach(customEventTypes) { type in
                            Text(type.emoji + " " + type.name).tag(UUID?.some(type.id))
                        }
                    }
                }
                
                if targetType == .customEventWithHashtag {
                    TextField("Target Hashtag (e.g. severe)", text: $targetHashtag)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Picker("Time Window", selection: $timeWindow) {
                    Text("30 min").tag(1800.0)
                    Text("1 hour").tag(3600.0)
                    Text("2 hours").tag(7200.0)
                    Text("4 hours").tag(14400.0)
                    Text("12 hours").tag(43200.0)
                    Text("24 hours").tag(86400.0)
                }
                
                Button {
                    runAnalysis()
                } label: {
                    if isAnalyzing {
                        ProgressView()
                    } else {
                        Text("Analyze")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isAnalyzing || selectedHashtags.isEmpty || (targetType != .feedAmount && targetCustomEventTypeID == nil))
            }
            
            if !results.isEmpty {
                Section("Results") {
                    Chart(results) { result in
                        if targetType == .feedAmount {
                            BarMark(
                                x: .value("Hashtag", result.hashtag),
                                y: .value("Avg Amount", result.averageValue ?? 0)
                            )
                        } else {
                            BarMark(
                                x: .value("Hashtag", result.hashtag),
                                y: .value("Percentage", result.percentage * 100)
                            )
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical)
                    
                    ForEach(results) { result in
                        HStack {
                            Text("#" + result.hashtag)
                                .font(.headline)
                            Spacer()
                            VStack(alignment: .trailing) {
                                if targetType == .feedAmount {
                                    if let avg = result.averageValue {
                                        Text("\(Int(avg)) ml")
                                    } else {
                                        Text("N/A")
                                    }
                                    Text("\(result.correlatedCount) feeds")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(result.percentage.formatted(.percent.precision(.fractionLength(0))))
                                        .foregroundStyle(result.percentage > 0.5 ? .red : .primary)
                                    Text("\(result.correlatedCount) / \(result.totalCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else if !isAnalyzing {
                Section {
                    Text("No correlations found or no data available.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Correlation Analysis")
        .onAppear {
            loadHashtags()
            // Default to Vomit if available
            if targetCustomEventTypeID == nil {
                if let vomitType = customEventTypes.first(where: { $0.name.localizedCaseInsensitiveContains("vomit") }) {
                    targetCustomEventTypeID = vomitType.id
                }
            }
        }
    }
    
    private func loadHashtags() {
        Task {
            let analyzer = CorrelationAnalyzer(context: viewContext)
            // Load hashtags from last 90 days to be safe
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
            let interval = DateInterval(start: startDate, end: endDate)
            
            let tags = await analyzer.fetchAllHashtags(dateInterval: interval, babyID: selectedBabyID)
            await MainActor.run {
                self.availableHashtags = tags
            }
        }
    }
    
    private func runAnalysis() {
        analysisTask?.cancel()
        isAnalyzing = true
        
        // Prepare target definition
        let target: CorrelationTarget
        switch targetType {
        case .customEvent:
            guard let id = targetCustomEventTypeID else { return }
            target = .customEvent(typeID: id)
        case .customEventWithHashtag:
            guard let id = targetCustomEventTypeID else { return }
            target = .customEventWithHashtag(typeID: id, hashtag: targetHashtag)
        case .feedAmount:
            target = .feedAmount
        }
        
        analysisTask = Task {
            let analyzer = CorrelationAnalyzer(context: viewContext)
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            let interval = DateInterval(start: startDate, end: endDate)
            
            let newResults = await analyzer.analyze(
                sourceHashtags: Array(selectedHashtags),
                target: target,
                timeWindow: timeWindow,
                dateInterval: interval,
                babyID: selectedBabyID
            )
            
            await MainActor.run {
                self.results = newResults
                self.isAnalyzing = false
            }
        }
    }
}

struct HashtagSelectionView: View {
    let availableHashtags: [String]
    @Binding var selectedHashtags: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            if availableHashtags.isEmpty {
                Text("No hashtags found in recent history.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(availableHashtags, id: \.self) { tag in
                    Button {
                        if selectedHashtags.contains(tag) {
                            selectedHashtags.remove(tag)
                        } else {
                            selectedHashtags.insert(tag)
                        }
                    } label: {
                        HStack {
                            Text("#" + tag)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedHashtags.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Hashtags")
    }
}

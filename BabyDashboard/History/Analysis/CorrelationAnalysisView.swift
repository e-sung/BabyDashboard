import SwiftUI
import CoreData
import Model
import Charts

struct CorrelationAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = CorrelationAnalysisViewModel()
    
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
                Picker("Baby", selection: $viewModel.selectedBabyID) {
                    Text("All Babies").tag(UUID?.none)
                    ForEach(babies) { baby in
                        Text(baby.name).tag(UUID?.some(baby.id))
                    }
                }
                .onChange(of: viewModel.selectedBabyID) { _, _ in viewModel.loadHashtags(context: viewContext) }
                
                Button {
                    viewModel.showingHashtagSelection = true
                } label: {
                    HStack {
                        Text("Source Hashtags")
                        Spacer()
                        Text("\(viewModel.selectedHashtags.count) selected")
                            .foregroundStyle(.secondary)
                    }
                }
                .sheet(isPresented: $viewModel.showingHashtagSelection) {
                    NavigationView {
                        HashtagSelectionView(availableHashtags: viewModel.availableHashtags, selectedHashtags: $viewModel.selectedHashtags)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        viewModel.showingHashtagSelection = false
                                    }
                                }
                            }
                    }
                }
                
                Picker("Target Type", selection: $viewModel.targetType) {
                    ForEach(TargetType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                if viewModel.targetType == .customEvent || viewModel.targetType == .customEventWithHashtag {
                    Picker("Event Type", selection: $viewModel.targetCustomEventTypeID) {
                        Text("Select Event...").tag(UUID?.none)
                        ForEach(customEventTypes) { type in
                            Text(type.emoji + " " + type.name).tag(UUID?.some(type.id))
                        }
                    }
                }
                
                if viewModel.targetType == .customEventWithHashtag {
                    TextField("Target Hashtag (e.g. severe)", text: $viewModel.targetHashtag)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                if viewModel.targetType != .feedAmount {
                    Picker("Time Window", selection: $viewModel.timeWindow) {
                        Text("30 min").tag(1800.0)
                        Text("1 hour").tag(3600.0)
                        Text("2 hours").tag(7200.0)
                        Text("4 hours").tag(14400.0)
                        Text("12 hours").tag(43200.0)
                        Text("24 hours").tag(86400.0)
                    }
                }
                
                Button {
                    viewModel.runAnalysis(context: viewContext)
                } label: {
                    if viewModel.isAnalyzing {
                        ProgressView()
                    } else {
                        Text("Analyze")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isAnalyzing || viewModel.selectedHashtags.isEmpty || (viewModel.targetType != .feedAmount && viewModel.targetCustomEventTypeID == nil))
            }
            
            if !viewModel.results.isEmpty {
                Section("Correlation Coefficient") {
                    Chart(viewModel.results) { result in
                        BarMark(
                            x: .value("Hashtag", result.hashtag),
                            y: .value("Correlation", result.correlationCoefficient)
                        )
                        .foregroundStyle(result.correlationCoefficient > 0 ? .green : .red)
                        .annotation(position: .overlay) {
                            Text(result.correlationCoefficient.formatted(.number.precision(.fractionLength(2))))
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                    }
                    .chartYScale(domain: -1.0...1.0)
                    .frame(height: 200)
                    .padding(.vertical)
                    
                    Text("Values close to 1.0 indicate strong positive correlation. Values close to -1.0 indicate strong negative correlation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Detailed Stats") {
                    ForEach(viewModel.results) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#" + result.hashtag)
                                    .font(.headline)
                                Spacer()
                                Text("r = \(result.correlationCoefficient.formatted(.number.precision(.fractionLength(2))))")
                                    .fontWeight(.bold)
                                    .foregroundStyle(result.correlationCoefficient > 0 ? .green : .red)
                            }
                            
                            HStack {
                                Text("P-value: \(result.pValue.formatted(.number.precision(.fractionLength(3))))")
                                    .font(.caption)
                                    .foregroundStyle(result.pValue < 0.05 ? .primary : .secondary)
                                
                                if result.pValue < 0.05 {
                                    Text("(Significant)")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("(Not Significant)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if viewModel.targetType == .feedAmount {
                                    if let avg = result.averageValue {
                                        Text("Avg: \(Int(avg)) ml")
                                            .font(.caption)
                                    }
                                } else {
                                    Text("\(result.percentage.formatted(.percent)) (\(result.correlatedCount)/\(result.totalCount))")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else if !viewModel.isAnalyzing {
                EmptyView()
            }
        }
        .navigationTitle("Correlation Analysis")
        .onAppear {
            viewModel.loadHashtags(context: viewContext)
            // Default to Vomit if available and not set
            if viewModel.targetCustomEventTypeID == nil {
                if let vomitType = customEventTypes.first(where: { $0.name.localizedCaseInsensitiveContains("vomit") }) {
                    viewModel.targetCustomEventTypeID = vomitType.id
                }
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

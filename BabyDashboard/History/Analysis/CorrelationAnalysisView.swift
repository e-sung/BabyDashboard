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
            Section("Analyze correlation of") {
                if viewModel.availableHashtags.isEmpty {
                    Text("No hashtags found in the selected period.")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(alignment: .top) {
                        // Left: Source Hashtags
                        VStack {
                            Text("Hashtags")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                viewModel.showingHashtagSelection = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    if viewModel.selectedHashtags.isEmpty {
                                        VStack {
                                            Image(systemName: "number")
                                                .font(.largeTitle)
                                            Text("0 Selected")
                                                .font(.caption)
                                        }
                                        .frame(maxWidth: .infinity)
                                    } else {
                                        let sortedTags = viewModel.selectedHashtags.sorted()
                                        let displayTags = sortedTags.prefix(viewModel.selectedHashtags.count > 5 ? 4 : 5)

                                        VStack {
                                            Image(systemName: "number")
                                                .font(.largeTitle)
                                            FlowLayout(spacing: 6, rowSpacing: 6) {
                                                ForEach(displayTags, id: \.self) { tag in
                                                    TagCapsule(text: tag.hasPrefix("#") ? tag : "#\(tag)")
                                                }
                                            }
                                            .accessibilityElement(children: .contain)
                                        }

                                        if viewModel.selectedHashtags.count > 5 {
                                            Text("...and \(viewModel.selectedHashtags.count - 4) selected")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .padding(.leading, 4)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 60, alignment: viewModel.selectedHashtags.isEmpty ? .center : .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Center: Arrow
                        VStack {
                            Spacer()
                            Image(systemName: "arrow.left.and.right")
                                .foregroundStyle(.secondary)
                                .padding(.top, 24)
                            Spacer()
                        }
                        
                        // Right: Target Event
                        VStack {
                            Text("Target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                viewModel.showingTargetSelection = true
                            } label: {
                                VStack {
                                    if viewModel.targetType == .feedAmount {
                                        Text("🍼")
                                            .font(.largeTitle)
                                    } else if let id = viewModel.targetCustomEventTypeID,
                                              let event = customEventTypes.first(where: { $0.id == id }) {
                                        Text(event.emoji)
                                            .font(.largeTitle)
                                    } else {
                                        Image(systemName: "target")
                                            .font(.largeTitle)
                                    }
                                    
                                    if let id = viewModel.targetCustomEventTypeID,
                                       let event = customEventTypes.first(where: { $0.id == id }),
                                       viewModel.targetType == .customEvent {
                                        Text(event.name)
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                    } else {
                                        Text(viewModel.targetSummary)
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    Picker("For", selection: $viewModel.selectedBabyID) {
                        Text("All Babies").tag(UUID?.none)
                        ForEach(babies) { baby in
                            Text(baby.name).tag(UUID?.some(baby.id))
                        }
                    }
                    .onChange(of: viewModel.selectedBabyID) { _, _ in viewModel.loadHashtags(context: viewContext) }
                    
                    Picker("During", selection: $viewModel.selectedTimePeriod) {
                        ForEach(AnalysisTimePeriod.allCases) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .onChange(of: viewModel.selectedTimePeriod) { _, _ in viewModel.loadHashtags(context: viewContext) }
                }
            }
            Section {
                Button {
                    viewModel.runAnalysis(context: viewContext)
                } label: {
                    if viewModel.isAnalyzing {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Analyze")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                    }
                }
                .disabled(viewModel.isAnalyzing || !canAnalyze)
            }
            
            if !viewModel.results.isEmpty {
                Section("Analysis Results") {
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
                
                Section("About this Analysis") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it works")
                            .font(.headline)
                        
                        if viewModel.targetType == .feedAmount {
                            Text("We compare the average feed amount of sessions **with** the selected hashtag versus those **without** it.")
                            Text("We use **Point-Biserial Correlation** to measure how strongly the presence of a hashtag is associated with the feed amount.")
                        } else {
                            Text("We check if the target event occurred within **1 hour** after the source event.")
                            Text("We use **Phi Coefficient** to measure the strength of association between the two binary variables.")
                        }
                        
                        Divider()
                        
                        Text("Interpretation")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text("**+1.0**: Strong positive correlation (They happen together)")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text("**-1.0**: Strong negative correlation (They rarely happen together)")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text("**0.0**: No correlation")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Correlation Analysis")
        .onAppear {
            viewModel.loadHashtags(context: viewContext)
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
        .sheet(isPresented: $viewModel.showingTargetSelection) {
            NavigationView {
                TargetSelectionView(viewModel: viewModel, customEventTypes: customEventTypes)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                viewModel.showingTargetSelection = false
                            }
                        }
                    }
            }
        }
    }
    

    
    private var canAnalyze: Bool {
        guard !viewModel.selectedHashtags.isEmpty else { return false }
        if viewModel.targetType == .feedAmount { return true }
        return viewModel.targetCustomEventTypeID != nil
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

struct TargetSelectionView: View {
    @ObservedObject var viewModel: CorrelationAnalysisViewModel
    var customEventTypes: FetchedResults<CustomEventType>
    
    var body: some View {
        Form {
            Section("Target Type") {
                Picker("Type", selection: $viewModel.targetType) {
                    ForEach(CorrelationAnalysisView.TargetType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.inline)
            }
            
            if viewModel.targetType == .customEvent || viewModel.targetType == .customEventWithHashtag {
                Section("Event Details") {
                    Picker("Event Type", selection: $viewModel.targetCustomEventTypeID) {
                        Text("Select Event...").tag(UUID?.none)
                        ForEach(customEventTypes) { type in
                            Text(type.emoji + " " + type.name).tag(UUID?.some(type.id))
                        }
                    }
                    
                    if viewModel.targetType == .customEventWithHashtag {
                        TextField("Target Hashtag (e.g. severe)", text: $viewModel.targetHashtag)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
            }
        }
        .navigationTitle("Select Target")
    }
}

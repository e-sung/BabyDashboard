import Foundation
import SwiftUI
import CoreData
import Combine

@MainActor
class CorrelationAnalysisViewModel: ObservableObject {
    // MARK: - Persistent State
    @Published var selectedHashtags: Set<String> = [] {
        didSet { saveState() }
    }
    @Published var targetType: CorrelationAnalysisView.TargetType = .customEvent {
        didSet { saveState() }
    }
    @Published var targetCustomEventTypeID: UUID? {
        didSet { saveState() }
    }
    @Published var targetHashtag: String = "" {
        didSet { saveState() }
    }

    @Published var selectedBabyID: UUID? {
        didSet { saveState() }
    }
    
    // MARK: - Transient State
    @Published var results: [CorrelationResult] = []
    @Published var isAnalyzing = false
    @Published var availableHashtags: [String] = []
    @Published var showingHashtagSelection = false
    @Published var showingTargetSelection = false
    
    var targetSummary: String {
        switch targetType {
        case .customEvent:
            return "Custom Event"
        case .customEventWithHashtag:
            return "Event + Hashtag"
        case .feedAmount:
            return "Feed Amount"
        }
    }
    
    private var analysisTask: Task<Void, Never>?
    private let userDefaultsKey = "CorrelationAnalysisState"
    
    init() {
        loadState()
    }
    
    // MARK: - Actions
    
    // MARK: - Actions
    
    func loadHashtags(context: NSManagedObjectContext) {
        Task {
            let analyzer = CorrelationAnalyzer(context: context)
            // Load hashtags from last 90 days
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
            let interval = DateInterval(start: startDate, end: endDate)
            
            let tags = await analyzer.fetchAllHashtags(dateInterval: interval, babyID: selectedBabyID)
            self.availableHashtags = tags
        }
    }
    
    func runAnalysis(context: NSManagedObjectContext) {
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
            let analyzer = CorrelationAnalyzer(context: context)
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
            let interval = DateInterval(start: startDate, end: endDate)
            
            let newResults = await analyzer.analyze(
                sourceHashtags: Array(selectedHashtags),
                target: target,

                dateInterval: interval,
                babyID: selectedBabyID
            )
            
            self.results = newResults
            self.isAnalyzing = false
        }
    }
    
    // MARK: - Persistence
    
    private struct SavedState: Codable {
        let selectedHashtags: Set<String>
        let targetTypeRawValue: String
        let targetCustomEventTypeID: UUID?
        let targetHashtag: String

        let selectedBabyID: UUID?
    }
    
    private func saveState() {
        let state = SavedState(
            selectedHashtags: selectedHashtags,
            targetTypeRawValue: targetType.rawValue,
            targetCustomEventTypeID: targetCustomEventTypeID,
            targetHashtag: targetHashtag,

            selectedBabyID: selectedBabyID
        )
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let state = try? JSONDecoder().decode(SavedState.self, from: data) else {
            return
        }
        
        self.selectedHashtags = state.selectedHashtags
        if let type = CorrelationAnalysisView.TargetType(rawValue: state.targetTypeRawValue) {
            self.targetType = type
        }
        self.targetCustomEventTypeID = state.targetCustomEventTypeID
        self.targetHashtag = state.targetHashtag

        self.selectedBabyID = state.selectedBabyID
    }
}

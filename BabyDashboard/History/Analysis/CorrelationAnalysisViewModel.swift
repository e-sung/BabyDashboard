import Foundation
import SwiftUI
import CoreData
import Combine
import Model


enum AnalysisTimePeriod: Int, CaseIterable, Identifiable, Codable {
    case last7Days = 7
    case last30Days = 30
    case last90Days = 90
    case allTime = 0
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .allTime: return "All Time"
        }
    }
    
    func dateInterval(endDate: Date = Date()) -> DateInterval {
        if self == .allTime {
            return DateInterval(start: .distantPast, end: endDate)
        }
        let startDate = Calendar.current.date(byAdding: .day, value: -rawValue, to: endDate) ?? endDate
        return DateInterval(start: startDate, end: endDate)
    }
}

@MainActor
class CorrelationAnalysisViewModel: ObservableObject {
    // MARK: - Persistent State
    @Published var selectedTimePeriod: AnalysisTimePeriod = .last30Days {
        didSet { saveState() }
    }

    @Published var selectedHashtags: Set<String> = [] {
        didSet { saveState() }
    }
    @Published var targetType: CorrelationAnalysisView.TargetType = .customEvent {
        didSet { saveState() }
    }
    @Published var targetCustomEventTypeEmoji: String? {
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
            let interval = self.selectedTimePeriod.dateInterval()
            
            let tags = await analyzer.fetchAllHashtags(dateInterval: interval, babyID: selectedBabyID)
            self.availableHashtags = tags
        }
    }

    func runAnalysis(context: NSManagedObjectContext) {
        analysisTask?.cancel()
        isAnalyzing = true
        
        // Prepare target definition
        analysisTask = Task {
            var target: CorrelationTarget?
            switch targetType {
            case .feedAmount:
                target = .feedAmount
            case .customEvent:
                guard let emoji = targetCustomEventTypeEmoji else {
                    self.isAnalyzing = false
                    return
                }
                target = .customEvent(emoji: emoji)
            case .customEventWithHashtag:
                guard let emoji = targetCustomEventTypeEmoji else {
                    self.isAnalyzing = false
                    return
                }
                target = .customEventWithHashtag(emoji: emoji, hashtag: targetHashtag)
            }
            
            guard let finalTarget = target else {
                self.isAnalyzing = false
                return
            }
            
            let analyzer = CorrelationAnalyzer(context: context)
            let interval = self.selectedTimePeriod.dateInterval()
            
            let newResults = await analyzer.analyze(
                sourceHashtags: Array(selectedHashtags),
                target: finalTarget,

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
        let targetCustomEventTypeEmoji: String?
        let targetHashtag: String
        let selectedTimePeriodRawValue: Int?
        let selectedBabyID: UUID?
    }
    
    private func saveState() {
        let state = SavedState(
            selectedHashtags: selectedHashtags,
            targetTypeRawValue: targetType.rawValue,
            targetCustomEventTypeEmoji: targetCustomEventTypeEmoji,
            targetHashtag: targetHashtag,


            selectedTimePeriodRawValue: selectedTimePeriod.rawValue,

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
        self.targetCustomEventTypeEmoji = state.targetCustomEventTypeEmoji
        self.targetHashtag = state.targetHashtag


        if let rawValue = state.selectedTimePeriodRawValue,
           let period = AnalysisTimePeriod(rawValue: rawValue) {
            self.selectedTimePeriod = period
        }

        self.selectedBabyID = state.selectedBabyID
    }
}

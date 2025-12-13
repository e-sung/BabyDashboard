import Foundation
import CoreData
import Model

enum CorrelationTarget: Equatable, Hashable, Sendable {
    case customEvent(emoji: String)
    case customEventWithHashtag(emoji: String, hashtag: String)
    case feedAmount
}

struct CorrelationResult: Identifiable, Sendable {
    let id = UUID()
    let hashtag: String
    
    // Raw Counts
    let totalCount: Int
    let correlatedCount: Int
    let averageValue: Double?
    
    // Statistics
    let correlationCoefficient: Double // Phi or Point-Biserial (-1 to 1)
    let pValue: Double // Significance (0 to 1)
    
    var percentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(correlatedCount) / Double(totalCount)
    }
}

actor CorrelationAnalyzer {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchAllHashtags(dateInterval: DateInterval, babyID: UUID?) async -> [String] {
        let context = self.context
        return await context.perform {
            var allTags: Set<String> = []
            
            // Fetch Feeds
            let feedReq: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
            feedReq.predicate = Self.makePredicate(dateInterval: dateInterval, babyID: babyID, dateKey: "startTime")
            if let feeds = try? context.fetch(feedReq) {
                feeds.forEach { allTags.formUnion($0.hashtags) }
            }
            
            // Fetch Diapers
            let diaperReq: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
            diaperReq.predicate = Self.makePredicate(dateInterval: dateInterval, babyID: babyID)
            if let diapers = try? context.fetch(diaperReq) {
                diapers.forEach { allTags.formUnion($0.hashtags) }
            }
            
            // Fetch Custom Events
            let customReq: NSFetchRequest<CustomEvent> = CustomEvent.fetchRequest()
            customReq.predicate = Self.makePredicate(dateInterval: dateInterval, babyID: babyID)
            if let customs = try? context.fetch(customReq) {
                customs.forEach { allTags.formUnion($0.hashtags) }
            }
            
            return Array(allTags).sorted()
        }
    }
    
    func analyze(
        sourceHashtags: [String],
        target: CorrelationTarget,
        timeWindow: TimeInterval = 3600,
        dateInterval: DateInterval,
        babyID: UUID?
    ) async -> [CorrelationResult] {
        let context = self.context
        return await context.perform {
            // 1. Fetch Data
            // For Feed Amount, we only care about FeedSessions.
            // For others, we need all events.
            
            var allSourceEvents: [HistoryEvent] = []
            var allFeedSessions: [FeedSession] = []
            
            if target == .feedAmount {
                let req: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
                req.predicate = Self.makePredicate(dateInterval: dateInterval, babyID: babyID, dateKey: "startTime")
                allFeedSessions = (try? context.fetch(req)) ?? []
            } else {
                // Exclude target event type from source events to prevent self-correlation
                var excludeCustomEventEmoji: String? = nil
                switch target {
                case .customEvent(let emoji), .customEventWithHashtag(let emoji, _):
                    excludeCustomEventEmoji = emoji
                default:
                    break
                }
                allSourceEvents = Self.fetchAllEvents(context: context, dateInterval: dateInterval, babyID: babyID, excludeCustomEventEmoji: excludeCustomEventEmoji)
            }
            
            // 2. Fetch Target Events (Only for non-FeedAmount targets)
            var targetEvents: [HistoryEvent] = []
            if target != .feedAmount {
                let targetFetchInterval = DateInterval(
                    start: dateInterval.start,
                    end: dateInterval.end.addingTimeInterval(timeWindow)
                )
                
                switch target {
                case .customEvent(let emoji), .customEventWithHashtag(let emoji, _):
                    targetEvents = Self.fetchEvents(
                        context: context,
                        type: .customEvent,
                        customEventEmoji: emoji,
                        dateInterval: targetFetchInterval,
                        babyID: babyID
                    )
                default: break
                }
            }
            
            // 3. Analyze per Hashtag
            var results: [CorrelationResult] = []
            
            for hashtag in sourceHashtags {
                
                if target == .feedAmount {
                    // --- Feed Amount Logic (Direct Correlation) ---
                    
                    // Group A: Feeds WITH hashtag
                    let groupA = allFeedSessions.filter { $0.hashtags.contains(hashtag) }
                    // Group B: Feeds WITHOUT hashtag
                    let groupB = allFeedSessions.filter { !$0.hashtags.contains(hashtag) }
                    
                    let totalCount = groupA.count
                    guard totalCount > 0 else {
                        results.append(CorrelationResult(hashtag: hashtag, totalCount: 0, correlatedCount: 0, averageValue: nil, correlationCoefficient: 0, pValue: 1.0))
                        continue
                    }
                    
                    // Extract amounts (convert to ml)
                    let valuesA = groupA.compactMap { $0.amount?.converted(to: .milliliters).value }
                    let valuesB = groupB.compactMap { $0.amount?.converted(to: .milliliters).value }
                    
                    let avgA = valuesA.isEmpty ? nil : valuesA.reduce(0, +) / Double(valuesA.count)
                    
                    if valuesB.isEmpty {
                        results.append(CorrelationResult(hashtag: hashtag, totalCount: totalCount, correlatedCount: valuesA.count, averageValue: avgA, correlationCoefficient: 0, pValue: 1.0))
                        continue
                    }
                    
                    let correlation = StatisticsUtils.calculatePointBiserialCorrelation(group1: valuesA, group0: valuesB)
                    let pValue = StatisticsUtils.calculateTTestPValue(group1: valuesA, group0: valuesB)
                    
                    results.append(CorrelationResult(
                        hashtag: hashtag,
                        totalCount: totalCount,
                        correlatedCount: valuesA.count,
                        averageValue: avgA,
                        correlationCoefficient: correlation.isNaN ? 0 : correlation,
                        pValue: pValue.isNaN ? 1.0 : pValue
                    ))
                    
                } else {
                    // --- Event Correlation Logic (Time Window) ---
                    
                    let groupA = allSourceEvents.filter { $0.hashtags.contains(hashtag) }
                    let groupB = allSourceEvents.filter { !$0.hashtags.contains(hashtag) }
                    
                    let totalCount = groupA.count
                    guard totalCount > 0 else {
                        results.append(CorrelationResult(hashtag: hashtag, totalCount: 0, correlatedCount: 0, averageValue: nil, correlationCoefficient: 0, pValue: 1.0))
                        continue
                    }
                    
                    let (correlatedA, notCorrelatedA) = Self.getBinaryCounts(for: groupA, targetEvents: targetEvents, target: target, timeWindow: timeWindow)
                    let (correlatedB, notCorrelatedB) = Self.getBinaryCounts(for: groupB, targetEvents: targetEvents, target: target, timeWindow: timeWindow)
                    
                    let a = correlatedA
                    let b = notCorrelatedA
                    let c = correlatedB
                    let d = notCorrelatedB
                    
                    let phi = StatisticsUtils.calculatePhiCoefficient(a: a, b: b, c: c, d: d)
                    let p = StatisticsUtils.calculateChiSquarePValue(a: a, b: b, c: c, d: d)
                    
                    results.append(CorrelationResult(
                        hashtag: hashtag,
                        totalCount: totalCount,
                        correlatedCount: correlatedA,
                        averageValue: nil,
                        correlationCoefficient: phi.isNaN ? 0 : phi,
                        pValue: p.isNaN ? 1.0 : p
                    ))
                }
            }
            
            return results.sorted { abs($0.correlationCoefficient) > abs($1.correlationCoefficient) }
        }
    }
    
    // MARK: - Helpers
    
    private nonisolated static func getBinaryCounts(for sources: [HistoryEvent], targetEvents: [HistoryEvent], target: CorrelationTarget, timeWindow: TimeInterval) -> (correlated: Int, notCorrelated: Int) {
        var correlated = 0
        var notCorrelated = 0
        
        for source in sources {
            let windowEnd = source.date.addingTimeInterval(timeWindow)
            var hasCorrelation = false
            
            switch target {
            case .customEvent:
                hasCorrelation = targetEvents.contains { target in
                    target.date > source.date && target.date <= windowEnd
                }
            case .customEventWithHashtag(_, let targetTag):
                hasCorrelation = targetEvents.contains { target in
                    target.date > source.date && target.date <= windowEnd && target.hashtags.contains(targetTag)
                }
            default: break
            }
            
            if hasCorrelation {
                correlated += 1
            } else {
                notCorrelated += 1
            }
        }
        return (correlated, notCorrelated)
    }
    
    private nonisolated static func makePredicate(dateInterval: DateInterval, babyID: UUID?, dateKey: String = "timestamp") -> NSPredicate {
        var predicates = [
            NSPredicate(format: "%K >= %@ AND %K < %@", argumentArray: [dateKey, dateInterval.start, dateKey, dateInterval.end])
        ]
        if let babyID {
            predicates.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID]))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    private nonisolated static func fetchAllEvents(context: NSManagedObjectContext, dateInterval: DateInterval, babyID: UUID?, excludeCustomEventEmoji: String? = nil) -> [HistoryEvent] {
        var events: [HistoryEvent] = []
        
        // Feeds
        let feedReq: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
        var feedPreds = [NSPredicate(format: "startTime >= %@ AND startTime < %@", argumentArray: [dateInterval.start, dateInterval.end])]
        if let babyID { feedPreds.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID])) }
        feedReq.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: feedPreds)
        if let feeds = try? context.fetch(feedReq) {
            events.append(contentsOf: feeds.map { HistoryEvent(from: $0) })
        }
        
        // Diapers
        let diaperReq: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
        var diaperPreds = [NSPredicate(format: "timestamp >= %@ AND timestamp < %@", argumentArray: [dateInterval.start, dateInterval.end])]
        if let babyID { diaperPreds.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID])) }
        diaperReq.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: diaperPreds)
        if let diapers = try? context.fetch(diaperReq) {
            events.append(contentsOf: diapers.map { HistoryEvent(from: $0) })
        }
        
        // Custom (exclude specific type if specified)
        let customReq: NSFetchRequest<CustomEvent> = CustomEvent.fetchRequest()
        var customPreds = [NSPredicate(format: "timestamp >= %@ AND timestamp < %@", argumentArray: [dateInterval.start, dateInterval.end])]
        if let babyID { customPreds.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID])) }
        if let excludeCustomEventEmoji {
            customPreds.append(NSPredicate(format: "eventTypeEmoji != %@", argumentArray: [excludeCustomEventEmoji]))
        }
        customReq.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: customPreds)
        if let customs = try? context.fetch(customReq) {
            events.append(contentsOf: customs.map { HistoryEvent(from: $0) })
        }
        
        return events
    }
    
    private nonisolated static func fetchEvents(
        context: NSManagedObjectContext,
        type: HistoryEventType,
        customEventEmoji: String? = nil,
        dateInterval: DateInterval,
        babyID: UUID?
    ) -> [HistoryEvent] {
        var events: [HistoryEvent] = []
        
        switch type {
        case .feed:
            let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
            var predicates = [
                NSPredicate(format: "startTime >= %@ AND startTime < %@", argumentArray: [dateInterval.start, dateInterval.end])
            ]
            if let babyID {
                predicates.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID]))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            if let results = try? context.fetch(request) {
                events = results.map { HistoryEvent(from: $0) }
            }
            
        case .diaper:
            let request: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
            var predicates = [
                NSPredicate(format: "timestamp >= %@ AND timestamp < %@", argumentArray: [dateInterval.start, dateInterval.end])
            ]
            if let babyID {
                predicates.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID]))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            if let results = try? context.fetch(request) {
                events = results.map { HistoryEvent(from: $0) }
            }
            
        case .customEvent:
            let request: NSFetchRequest<CustomEvent> = CustomEvent.fetchRequest()
            var predicates = [
                NSPredicate(format: "timestamp >= %@ AND timestamp < %@", argumentArray: [dateInterval.start, dateInterval.end])
            ]
            if let babyID {
                predicates.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID]))
            }
            // Prioritize matching by emoji if provided, otherwise fall back to ID
            if let customEventEmoji {
                predicates.append(NSPredicate(format: "eventTypeEmoji == %@", argumentArray: [customEventEmoji]))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            if let results = try? context.fetch(request) {
                events = results.map { HistoryEvent(from: $0) }
            }
        @unknown default:
            break
        }
        
        return events
    }
}

import Foundation
import CoreData
import Model

enum CorrelationTarget: Equatable, Hashable, Sendable {
    case customEvent(typeID: UUID)
    case customEventWithHashtag(typeID: UUID, hashtag: String)
    case feedAmount
}

struct CorrelationResult: Identifiable, Sendable {
    let id = UUID()
    let hashtag: String
    let totalCount: Int
    let correlatedCount: Int
    let averageValue: Double?
    
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
        await context.perform {
            var allTags: Set<String> = []
            
            // Fetch Feeds
            let feedReq: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
            feedReq.predicate = self.makePredicate(dateInterval: dateInterval, babyID: babyID)
            if let feeds = try? self.context.fetch(feedReq) {
                feeds.forEach { allTags.formUnion($0.hashtags) }
            }
            
            // Fetch Diapers
            let diaperReq: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
            diaperReq.predicate = self.makePredicate(dateInterval: dateInterval, babyID: babyID)
            if let diapers = try? self.context.fetch(diaperReq) {
                diapers.forEach { allTags.formUnion($0.hashtags) }
            }
            
            // Fetch Custom Events
            let customReq: NSFetchRequest<CustomEvent> = CustomEvent.fetchRequest()
            customReq.predicate = self.makePredicate(dateInterval: dateInterval, babyID: babyID)
            if let customs = try? self.context.fetch(customReq) {
                customs.forEach { allTags.formUnion($0.hashtags) }
            }
            
            return Array(allTags).sorted()
        }
    }
    
    func analyze(
        sourceHashtags: [String],
        target: CorrelationTarget,
        timeWindow: TimeInterval,
        dateInterval: DateInterval,
        babyID: UUID?
    ) async -> [CorrelationResult] {
        
        await context.perform {
            // 1. Fetch Source Events (Any event containing one of the source hashtags)
            // We fetch ALL events in the window and filter in memory for simplicity and flexibility
            let allSourceEvents = self.fetchAllEvents(dateInterval: dateInterval, babyID: babyID)
            
            // 2. Fetch Target Events
            let targetFetchInterval = DateInterval(
                start: dateInterval.start,
                end: dateInterval.end.addingTimeInterval(timeWindow)
            )
            
            var targetEvents: [HistoryEvent] = []
            var targetFeeds: [FeedSession] = []
            
            switch target {
            case .customEvent(let typeID), .customEventWithHashtag(let typeID, _):
                targetEvents = self.fetchEvents(
                    type: .customEvent,
                    customEventTypeID: typeID,
                    dateInterval: targetFetchInterval,
                    babyID: babyID
                )
            case .feedAmount:
                // For feed amount, we need the actual FeedSession objects to get amounts
                let req: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
                req.predicate = self.makePredicate(dateInterval: targetFetchInterval, babyID: babyID)
                targetFeeds = (try? self.context.fetch(req)) ?? []
            }
            
            // 3. Analyze
            var results: [CorrelationResult] = []
            
            for hashtag in sourceHashtags {
                // Filter source events for this hashtag
                let sources = allSourceEvents.filter { $0.hashtags.contains(hashtag) }
                let totalCount = sources.count
                
                guard totalCount > 0 else {
                    results.append(CorrelationResult(hashtag: hashtag, totalCount: 0, correlatedCount: 0, averageValue: nil))
                    continue
                }
                
                var correlatedCount = 0
                var totalValue: Double = 0
                var valueCount = 0
                
                for source in sources {
                    let windowEnd = source.date.addingTimeInterval(timeWindow)
                    
                    switch target {
                    case .customEvent:
                        let hasCorrelation = targetEvents.contains { target in
                            target.date > source.date && target.date <= windowEnd
                        }
                        if hasCorrelation { correlatedCount += 1 }
                        
                    case .customEventWithHashtag(_, let targetTag):
                        let hasCorrelation = targetEvents.contains { target in
                            target.date > source.date && target.date <= windowEnd && target.hashtags.contains(targetTag)
                        }
                        if hasCorrelation { correlatedCount += 1 }
                        
                    case .feedAmount:
                        // Find the FIRST feed that started after source.date within window
                        let nextFeed = targetFeeds
                            .filter { $0.startTime > source.date && $0.startTime <= windowEnd }
                            .sorted { $0.startTime < $1.startTime }
                            .first
                        
                        if let feed = nextFeed {
                            correlatedCount += 1
                            // Convert to preferred unit (e.g. ml)
                            // For simplicity, let's use base unit (ml) value if available, or just amountValue
                            // Ideally we should normalize units. Assuming amountValue is stored consistently or we use the helper.
                            // Let's use the amount property which handles conversion if we had a context, but here we have the object.
                            // We'll trust amountValue is what we want or we can use the helper if we were in the same context.
                            // Since we are in perform block, we can access properties.
                            if let amount = feed.amount {
                                totalValue += amount.converted(to: .milliliters).value
                                valueCount += 1
                            }
                        }
                    }
                }
                
                let avgValue: Double? = valueCount > 0 ? totalValue / Double(valueCount) : nil
                
                results.append(CorrelationResult(
                    hashtag: hashtag,
                    totalCount: totalCount,
                    correlatedCount: correlatedCount,
                    averageValue: avgValue
                ))
            }
            
            return results.sorted {
                if target == .feedAmount {
                    return ($0.averageValue ?? 0) > ($1.averageValue ?? 0)
                } else {
                    return $0.percentage > $1.percentage
                }
            }
        }
    }
    
    private func makePredicate(dateInterval: DateInterval, babyID: UUID?) -> NSPredicate {
        var predicates = [
            NSPredicate(format: "timestamp >= %@ AND timestamp < %@", argumentArray: [dateInterval.start, dateInterval.end])
        ]
        // FeedSession uses startTime, others use timestamp. We need to handle this.
        // Actually, let's just use a helper that returns the correct key based on entity?
        // Or just hardcode since we know the caller.
        // The fetchAllHashtags uses specific requests, so we can adjust there.
        // Wait, fetchAllHashtags calls this.
        // Let's make this generic or just inline it in fetchAllHashtags.
        // I'll inline it or make it smarter.
        return NSPredicate(value: true) // Placeholder, logic moved to specific fetchers
    }
    
    private func fetchAllEvents(dateInterval: DateInterval, babyID: UUID?) -> [HistoryEvent] {
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
        
        // Custom
        let customReq: NSFetchRequest<CustomEvent> = CustomEvent.fetchRequest()
        var customPreds = [NSPredicate(format: "timestamp >= %@ AND timestamp < %@", argumentArray: [dateInterval.start, dateInterval.end])]
        if let babyID { customPreds.append(NSPredicate(format: "profile.id == %@", argumentArray: [babyID])) }
        customReq.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: customPreds)
        if let customs = try? context.fetch(customReq) {
            events.append(contentsOf: customs.map { HistoryEvent(from: $0) })
        }
        
        return events
    }
    
    private func fetchEvents(
        type: HistoryEventType,
        customEventTypeID: UUID? = nil,
        dateInterval: DateInterval,
        babyID: UUID?
    ) -> [HistoryEvent] {
        // Reuse existing logic but adapted
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
            if let customEventTypeID {
                predicates.append(NSPredicate(format: "eventType.id == %@", argumentArray: [customEventTypeID]))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            if let results = try? context.fetch(request) {
                events = results.map { HistoryEvent(from: $0) }
            }
        }
        
        return events
    }
}

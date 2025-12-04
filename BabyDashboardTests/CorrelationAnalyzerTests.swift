import Testing
import Foundation
import CoreData
import Model
@testable import BabyDashboard

@Suite("Correlation Analyzer Tests")
@MainActor
struct CorrelationAnalyzerTests {
    
    let persistenceController = PersistenceController(inMemory: true)
    var context: NSManagedObjectContext { persistenceController.viewContext }
    
    @Test("Analyzes correlation between Hashtag and Custom Event")
    func analyzeHashtagToCustomEvent() async throws {
        // Given
        let baby = BabyProfile(context: context, name: "TestBaby")
        let vomitType = CustomEventType(context: context, name: "Vomit", emoji: "🤮")
        let now = Date()
        
        // Feed 1: #BrandA -> Vomit (Correlated)
        let feed1 = FeedSession(context: context, startTime: now.addingTimeInterval(-3600))
        feed1.endTime = now.addingTimeInterval(-3000)
        feed1.memoText = "Milk #BrandA"
        feed1.profile = baby
        
        let vomit1 = CustomEvent(context: context, timestamp: now.addingTimeInterval(-1800), eventType: vomitType)
        vomit1.profile = baby
        
        // Feed 2: #BrandB -> No Vomit
        let feed2 = FeedSession(context: context, startTime: now.addingTimeInterval(-7200))
        feed2.memoText = "Milk #BrandB"
        feed2.profile = baby
        
        try context.save()
        
        let analyzer = CorrelationAnalyzer(context: context)
        let dateInterval = DateInterval(start: now.addingTimeInterval(-86400), end: now)
        
        // When
        let results = await analyzer.analyze(
            sourceHashtags: ["branda", "brandb"],
            target: .customEvent(typeID: vomitType.id),
            timeWindow: 3600,
            dateInterval: dateInterval,
            babyID: baby.id
        )
        
        // Then
        let brandA = results.first(where: { $0.hashtag == "branda" })
        let brandB = results.first(where: { $0.hashtag == "brandb" })
        
        #expect(brandA?.correlatedCount == 1)
        #expect(brandA?.percentage == 1.0)
        
        #expect(brandB?.correlatedCount == 0)
        #expect(brandB?.percentage == 0.0)
    }
    
    @Test("Analyzes Feed Amount correlation")
    func analyzeFeedAmount() async throws {
        // Given
        let baby = BabyProfile(context: context, name: "TestBaby")
        let now = Date()
        
        // Feed 1: #BrandA -> Next Feed is 100ml
        let feed1 = FeedSession(context: context, startTime: now.addingTimeInterval(-7200))
        feed1.memoText = "#BrandA"
        feed1.profile = baby
        
        let nextFeed1 = FeedSession(context: context, startTime: now.addingTimeInterval(-5400)) // 30 mins later
        nextFeed1.amount = Measurement(value: 100, unit: .milliliters)
        nextFeed1.profile = baby
        
        // Feed 2: #BrandB -> Next Feed is 50ml
        let feed2 = FeedSession(context: context, startTime: now.addingTimeInterval(-3600))
        feed2.memoText = "#BrandB"
        feed2.profile = baby
        
        let nextFeed2 = FeedSession(context: context, startTime: now.addingTimeInterval(-1800)) // 30 mins later
        nextFeed2.amount = Measurement(value: 50, unit: .milliliters)
        nextFeed2.profile = baby
        
        try context.save()
        
        let analyzer = CorrelationAnalyzer(context: context)
        let dateInterval = DateInterval(start: now.addingTimeInterval(-86400), end: now)
        
        // When
        let results = await analyzer.analyze(
            sourceHashtags: ["branda", "brandb"],
            target: .feedAmount,
            timeWindow: 3600,
            dateInterval: dateInterval,
            babyID: baby.id
        )
        
        // Then
        let brandA = results.first(where: { $0.hashtag == "branda" })
        let brandB = results.first(where: { $0.hashtag == "brandb" })
        
        #expect(brandA?.averageValue == 100)
        #expect(brandB?.averageValue == 50)
    }
}

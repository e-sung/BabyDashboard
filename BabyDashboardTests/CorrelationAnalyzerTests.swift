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
    
    @Test("Analyzes statistical correlation (Phi Coefficient)")
    func analyzeStatisticalCorrelation() async throws {
        // Given
        let baby = BabyProfile(context: context, name: "TestBaby")
        let now = Date.current
        
        let vomitType = CustomEventType(context: context, name: "Vomit", emoji: "🤮")
        
        // Scenario: #BrandA causes vomit (Perfect Positive Correlation)
        // 10 feeds with #BrandA -> 10 Vomits
        // 10 feeds without #BrandA -> 0 Vomits
        
        for i in 0..<10 {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 10000))
            feed.memoText = "Milk #BrandA"
            feed.profile = baby
            
            let vomit = CustomEvent(context: context,
                                   timestamp: now.addingTimeInterval(-Double(i)*3600 - 9000),
                                   eventTypeName: vomitType.name,
                                   eventTypeEmoji: vomitType.emoji)
            vomit.profile = baby
        }
        
        for i in 0..<10 {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 50000))
            feed.memoText = "Milk #BrandB" // No vomit
            feed.profile = baby
        }
        
        try context.save()
        
        let analyzer = CorrelationAnalyzer(context: context)
        let dateInterval = DateInterval(start: now.addingTimeInterval(-100000), end: now)
        
        // When
        let results = await analyzer.analyze(
            sourceHashtags: ["#BrandA"],
            target: .customEvent(emoji: vomitType.emoji),

            dateInterval: dateInterval,
            babyID: baby.id
        )
        
        // Then
        let brandA = results.first(where: { $0.hashtag == "#BrandA" })
        
        // Contingency Table:
        //       | Yes | No
        // Has A | 10  | 0
        // No A  |  0  | 10 (BrandB feeds)
        // Phi should be 1.0
        
        #expect(brandA?.correlationCoefficient == 1.0)
        #expect(brandA?.pValue ?? 1.0 < 0.05) // Should be significant
    }
    
    @Test("Analyzes Feed Amount correlation (Direct)")
    func analyzeFeedAmountCorrelation() async throws {
        // Given
        let baby = BabyProfile(context: context, name: "TestBaby")
        let now = Date()
        
        // Scenario: #BrandA feeds are ~150ml, Others are ~50ml
        // Adding variance to make the t-test meaningful
        
        // 10 feeds with #BrandA (145-155ml, mean=150ml)
        let amountsA = [145.0, 148.0, 150.0, 152.0, 155.0, 146.0, 149.0, 151.0, 153.0, 151.0]
        for (i, amount) in amountsA.enumerated() {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 10000))
            feed.memoText = "#BrandA"
            feed.amount = Measurement(value: amount, unit: .milliliters)
            feed.profile = baby
        }
        
        // 10 feeds with #BrandB (45-55ml, mean=50ml)
        let amountsB = [45.0, 48.0, 50.0, 52.0, 55.0, 46.0, 49.0, 51.0, 53.0, 51.0]
        for (i, amount) in amountsB.enumerated() {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 50000))
            feed.memoText = "#BrandB"
            feed.amount = Measurement(value: amount, unit: .milliliters)
            feed.profile = baby
        }
        
        try context.save()
        
        let analyzer = CorrelationAnalyzer(context: context)
        let dateInterval = DateInterval(start: now.addingTimeInterval(-100000), end: now)
        
        // When
        let results = await analyzer.analyze(
            sourceHashtags: ["#BrandA"],
            target: .feedAmount,

            dateInterval: dateInterval,
            babyID: baby.id
        )
        
        // Then
        let brandA = results.first(where: { $0.hashtag == "#BrandA" })
        
        // Group A (Has BrandA): [145, 148, 150, 152, 155, 146, 149, 151, 153, 151] mean=150
        // Group B (No BrandA): [45, 48, 50, 52, 55, 46, 49, 51, 53, 51] mean=50
        // Correlation should be positive (close to 1.0)
        
        #expect(brandA?.correlationCoefficient ?? 0 > 0.8)
        #expect(brandA?.averageValue ?? 0 >= 149 && brandA?.averageValue ?? 0 <= 151) // Should be ~150
        #expect(brandA?.pValue ?? 1.0 < 0.05)
    }
}

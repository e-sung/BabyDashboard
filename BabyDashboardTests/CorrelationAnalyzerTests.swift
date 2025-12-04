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
        let vomitType = CustomEventType(context: context, name: "Vomit", emoji: "🤮")
        let now = Date()
        
        // Scenario: #BrandA causes vomit (Perfect Positive Correlation)
        // 5 feeds with #BrandA -> 5 Vomits
        // 5 feeds without #BrandA -> 0 Vomits
        
        for i in 0..<5 {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 10000))
            feed.memoText = "Milk #BrandA"
            feed.profile = baby
            
            let vomit = CustomEvent(context: context, timestamp: now.addingTimeInterval(-Double(i)*3600 - 9000), eventType: vomitType)
            vomit.profile = baby
        }
        
        for i in 0..<5 {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 50000))
            feed.memoText = "Milk #BrandB" // No vomit
            feed.profile = baby
        }
        
        try context.save()
        
        let analyzer = CorrelationAnalyzer(context: context)
        let dateInterval = DateInterval(start: now.addingTimeInterval(-100000), end: now)
        
        // When
        let results = await analyzer.analyze(
            sourceHashtags: ["branda"],
            target: .customEvent(typeID: vomitType.id),

            dateInterval: dateInterval,
            babyID: baby.id
        )
        
        // Then
        let brandA = results.first(where: { $0.hashtag == "branda" })
        
        // Contingency Table:
        //       | Yes | No
        // Has A |  5  | 0
        // No A  |  0  | 5 (BrandB feeds)
        // Phi should be 1.0
        
        #expect(brandA?.correlationCoefficient == 1.0)
        #expect(brandA?.pValue ?? 1.0 < 0.05) // Should be significant
    }
    
    @Test("Analyzes Feed Amount correlation (Direct)")
    func analyzeFeedAmountCorrelation() async throws {
        // Given
        let baby = BabyProfile(context: context, name: "TestBaby")
        let now = Date()
        
        // Scenario: #BrandA feeds are 150ml, Others are 50ml
        
        // 5 feeds with #BrandA (150ml)
        for i in 0..<5 {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 10000))
            feed.memoText = "#BrandA"
            feed.amount = Measurement(value: 150, unit: .milliliters)
            feed.profile = baby
        }
        
        // 5 feeds with #BrandB (50ml)
        for i in 0..<5 {
            let feed = FeedSession(context: context, startTime: now.addingTimeInterval(-Double(i)*3600 - 50000))
            feed.memoText = "#BrandB"
            feed.amount = Measurement(value: 50, unit: .milliliters)
            feed.profile = baby
        }
        
        try context.save()
        
        let analyzer = CorrelationAnalyzer(context: context)
        let dateInterval = DateInterval(start: now.addingTimeInterval(-100000), end: now)
        
        // When
        let results = await analyzer.analyze(
            sourceHashtags: ["branda"],
            target: .feedAmount,

            dateInterval: dateInterval,
            babyID: baby.id
        )
        
        // Then
        let brandA = results.first(where: { $0.hashtag == "branda" })
        
        // Group A (Has BrandA): [150, 150, 150, 150, 150]
        // Group B (No BrandA): [50, 50, 50, 50, 50]
        // Correlation should be positive (close to 1.0)
        
        #expect(brandA?.correlationCoefficient ?? 0 > 0.8)
        #expect(brandA?.averageValue == 150)
        #expect(brandA?.pValue ?? 1.0 < 0.05)
    }
}

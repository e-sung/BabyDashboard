import Testing
import Foundation
import Model
@testable import BabyDashboard

/// Tests for BabyStatusLogic - Documents display calculation behavior
/// Replaces UI test assertions about displayed text and progress values
@Suite("Baby Status Display Logic")
struct BabyStatusLogicTests {
    
    // MARK: - Feed Main Text Tests
    
    @Test("Feed main text shows 'Just now' under one minute")
    func feedMainTextJustNow() {
        // Given: Feed finished 30 seconds ago
        let now = Date()
        let session = FeedSessionSnapshot(
            startTime: now.addingTimeInterval(-30),
            endTime: now.addingTimeInterval(-25),
            amount: nil,
            feedType: .babyFormula,
            isInProgress: false
        )
        let logic = BabyStatusLogic(
            lastFeedSession: session,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let text = logic.feedMainText(now: now)
        
        // Then
        #expect(text == "Just now")
    }
    
    @Test("Feed main text shows elapsed time over one minute")
    func feedMainTextElapsedTime() {
        // Given: Feed started 2.5 hours ago
        let now = Date()
        let session = FeedSessionSnapshot(
            startTime: now.addingTimeInterval(-2.5 * 3600),
            endTime: now.addingTimeInterval(-2 * 3600),
            amount: nil,
            feedType: .babyFormula,
            isInProgress: false
        )
        let logic = BabyStatusLogic(
            lastFeedSession: session,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let text = logic.feedMainText(now: now)
        
        // Then: Should contain "2h 30m ago" or similar
        #expect(text.contains("ago"))
        #expect(text.contains("2") && text.contains("h"))
    }
    
    @Test("Feed main text shows elapsed during active feeding")
    func feedMainTextDuringFeeding() {
        // Given: Active feeding started 90 seconds ago
        let now = Date()
        let inProgress = FeedSessionSnapshot(
            startTime: now.addingTimeInterval(-90),
            endTime: nil,
            amount: nil,
            feedType: nil,
            isInProgress: true
        )
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: inProgress,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let text = logic.feedMainText(now: now)
        
        // Then: Should show minuteseconds format (e.g., "1m 30s")
        #expect(text.contains("1") && text.contains("m"))
        #expect(text.contains("s"))
    }
    
    @Test("Feed main text returns '--' with no data")
    func feedMainTextNoData() {
        // Given: No feed sessions
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let text = logic.feedMainText(now: Date())
        
        // Then
        #expect(text == "--")
    }
    
    // MARK: - Feed Progress Tests
    
    @Test("Feed progress calculation returns fraction of term")
    func feedProgressCalculation() {
        // Given: Feed started 1.5 hours ago, term is 3 hours
        let now = Date()
        let session = FeedSessionSnapshot(
            startTime: now.addingTimeInterval(-1.5 * 3600),
            endTime: now.addingTimeInterval(-1 * 3600),
            amount: nil,
            feedType: .babyFormula,
            isInProgress: false
        )
        let logic = BabyStatusLogic(
            lastFeedSession: session,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let progress = logic.feedProgress(now: now)
        
        // Then: 1.5h / 3h = 0.5
        #expect(progress >= 0.49 && progress <= 0.51)
    }
    
    @Test("Feed progress can exceed 1.0 when overdue")
    func feedProgressOverdue() {
        // Given: Feed started 4 hours ago, term is 3 hours
        let now = Date()
        let session = FeedSessionSnapshot(
            startTime: now.addingTimeInterval(-4 * 3600),
            endTime: now.addingTimeInterval(-3.5 * 3600),
            amount: nil,
            feedType: .babyFormula,
            isInProgress: false
        )
        let logic = BabyStatusLogic(
            lastFeedSession: session,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let progress = logic.feedProgress(now: now)
        
        // Then: 4h / 3h = 1.33
        #expect(progress > 1.0)
    }
    
    @Test("Feed progress returns 0 with no data")
    func feedProgressNoData() {
        // Given: No feed sessions
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let progress = logic.feedProgress(now: Date())
        
        // Then
        #expect(progress == 0)
    }
    
    // MARK: - Feed Footer Text Tests
    
    @Test("Feed footer includes amount formatted correctly")
    func feedFooterWithAmount() {
        // Given: Feed with 120ml
        let now = Date()
        let session = FeedSessionSnapshot(
            startTime: now.addingTimeInterval(-3600),
            endTime: now.addingTimeInterval(-2700), // 15 min duration
            amount: Measurement(value: 120, unit: .milliliters),
            feedType: .babyFormula,
            isInProgress: false
        )
        let logic = BabyStatusLogic(
            lastFeedSession: session,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600,
            preferredVolumeUnit: .milliliters
        )
        
        // When
        let footer = logic.feedFooterText(now: now)
        let icon = logic.feedFooterIcon
        
        // Then: Footer should contain duration and amount (no emoji - it's separate)
        #expect(!footer.contains("🍼")) // Emoji is now in feedFooterIcon
        #expect(footer.contains("15") || footer.contains("in"))
        #expect(footer.contains("120") || footer.lowercased().contains("ml"))
        
        // Icon should be the feed type emoji
        #expect(icon == "🍼")
    }
    
    @Test("Feed footer shows 'No data' with no session")
    func feedFooterNoData() {
        // Given: No feed sessions
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let footer = logic.feedFooterText(now: Date())
        
        // Then
        #expect(footer == "No data")
    }
    
    @Test("Feed footer is empty during active feeding")
    func feedFooterDuringFeeding() {
        // Given: Active feeding
        let now = Date()
        let inProgress = FeedSessionSnapshot(
            startTime: now.addingTimeInterval(-60),
            endTime: nil,
            amount: nil,
            feedType: nil,
            isInProgress: true
        )
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: inProgress,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let footer = logic.feedFooterText(now: now)
        
        // Then
        #expect(footer == "")
    }
    
    // MARK: - Diaper Display Tests
    
    @Test("Diaper time ago shows elapsed time")
    func diaperTimeAgo() {
        // Given: Diaper changed 30 minutes ago
        let now = Date()
        let diaper = DiaperChangeSnapshot(
            timestamp: now.addingTimeInterval(-30 * 60),
            type: .pee
        )
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: diaper,
            feedTerm: 3 * 3600
        )
        
        // When
        let text = logic.diaperTimeAgo(now: now)
        
        // Then
        #expect(text.contains("30") || text.contains("ago"))
    }
    
    @Test("Diaper time ago returns '--' with no data")
    func diaperTimeAgoNoData() {
        // Given: No diaper changes
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let text = logic.diaperTimeAgo(now: Date())
        
        // Then
        #expect(text == "--")
    }
    
    @Test("Diaper progress capped at 1.0")
    func diaperProgressCapped() {
        // Given: Diaper changed 2 hours ago, threshold is 1 hour
        let now = Date()
        let diaper = DiaperChangeSnapshot(
            timestamp: now.addingTimeInterval(-2 * 3600),
            type: .pee
        )
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: diaper,
            feedTerm: 3 * 3600,
            diaperWarningThreshold: 3600
        )
        
        // When
        let progress = logic.diaperProgress(now: now)
        
        // Then: Should be capped at 1.0
        #expect(progress == 1.0)
    }
    
    @Test("Diaper progress returns 0 with no data")
    func diaperProgressNoData() {
        // Given: No diaper changes
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let progress = logic.diaperProgress(now: Date())
        
        // Then
        #expect(progress == 0)
    }
    
    @Test("Diaper footer shows 'No data' with no diaper change")
    func diaperFooterNoData() {
        // Given: No diaper changes
        let logic = BabyStatusLogic(
            lastFeedSession: nil,
            inProgressFeedSession: nil,
            lastDiaperChange: nil,
            feedTerm: 3 * 3600
        )
        
        // When
        let footer = logic.diaperFooterText()
        
        // Then
        #expect(footer == "No data")
    }
}

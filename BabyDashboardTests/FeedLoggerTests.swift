import Testing
import Foundation
import CoreData
import Model
@testable import BabyDashboard

/// Tests for FeedLogger - Documents the feed session workflow
/// Replaces UI tests for feed start/finish/cancel operations
@Suite("Feed Logger")
@MainActor
struct FeedLoggerTests {
    
    // Each test gets a fresh in-memory context
    func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).viewContext
    }
    
    // MARK: - Start Feeding Tests
    
    @Test("Start feeding creates in-progress session")
    func startFeedingCreatesSession() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        
        // When
        let session = try logger.startFeeding(for: baby)
        
        // Then
        #expect(session.profile?.id == baby.id)
        #expect(session.isInProgress == true)
        #expect(session.endTime == nil)
        #expect(baby.inProgressFeedSession != nil)
    }
    
    @Test("Start feeding cancels existing in-progress session")
    func startFeedingCancelsExisting() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        let firstSession = try logger.startFeeding(for: baby)
        let firstSessionId = firstSession.uuid
        
        // When: Start another feed
        let secondSession = try logger.startFeeding(for: baby)
        
        // Then: First session should be deleted
        #expect(secondSession.uuid != firstSessionId)
        #expect(baby.inProgressFeedSession?.uuid == secondSession.uuid)
        
        // Verify first session is actually deleted
        let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", firstSessionId as CVarArg)
        let results = try context.fetch(request)
        #expect(results.isEmpty)
    }
    
    // MARK: - Finish Feeding Tests
    
    @Test("Finish feeding sets all fields correctly")
    func finishFeedingSetsAllFields() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        _ = try logger.startFeeding(for: baby)
        
        let amount = Measurement(value: 120, unit: UnitVolume.milliliters)
        
        // When
        let session = try logger.finishFeeding(
            for: baby,
            amount: amount,
            feedType: .babyFormula,
            memoText: "#morning"
        )
        
        // Then
        #expect(session != nil)
        #expect(session?.isInProgress == false)
        #expect(session?.endTime != nil)
        #expect(session?.amount?.value == 120)
        #expect(session?.feedType == .babyFormula)
        #expect(session?.memoText == "#morning")
    }
    
    @Test("Finish feeding with no in-progress session returns nil")
    func finishFeedingWithNoSession() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        // Note: No startFeeding called
        
        let amount = Measurement(value: 120, unit: UnitVolume.milliliters)
        
        // When
        let session = try logger.finishFeeding(
            for: baby,
            amount: amount,
            feedType: .babyFormula
        )
        
        // Then
        #expect(session == nil)
    }
    
    @Test("Finish feeding with empty memo sets nil")
    func finishFeedingEmptyMemo() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        _ = try logger.startFeeding(for: baby)
        
        // When
        let session = try logger.finishFeeding(
            for: baby,
            amount: Measurement(value: 100, unit: .milliliters),
            feedType: .breastFeed,
            memoText: ""
        )
        
        // Then
        #expect(session?.memoText == nil)
    }
    
    // MARK: - Cancel Feeding Tests
    
    @Test("Cancel feeding deletes in-progress session")
    func cancelFeedingDeletesSession() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        _ = try logger.startFeeding(for: baby)
        #expect(baby.inProgressFeedSession != nil)
        
        // When
        let cancelled = try logger.cancelFeeding(for: baby)
        
        // Then
        #expect(cancelled == true)
        #expect(baby.inProgressFeedSession == nil)
    }
    
    @Test("Cancel feeding with no session returns false")
    func cancelFeedingNoSession() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        // Note: No startFeeding called
        
        // When
        let cancelled = try logger.cancelFeeding(for: baby)
        
        // Then
        #expect(cancelled == false)
    }
    
    // MARK: - Feed Type Tests
    
    @Test("Finish feeding with different feed types")
    func finishFeedingWithDifferentTypes() throws {
        // Given
        let context = makeContext()
        let baby = BabyProfile(context: context, name: "Test Baby")
        try context.save()
        
        let logger = FeedLogger(context: context)
        
        // Test each feed type
        for feedType in FeedType.allCases {
            _ = try logger.startFeeding(for: baby)
            let session = try logger.finishFeeding(
                for: baby,
                amount: Measurement(value: 100, unit: .milliliters),
                feedType: feedType
            )
            
            #expect(session?.feedType == feedType)
        }
    }
}

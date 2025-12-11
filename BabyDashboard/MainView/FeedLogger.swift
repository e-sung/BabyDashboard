import Foundation
import CoreData
import Model

/// Handles feed session lifecycle operations.
/// Extracted from MainViewModel for testability.
struct FeedLogger {
    let context: NSManagedObjectContext
    
    /// Starts a new feeding session for the baby.
    /// If there's already an in-progress session, it is cancelled first.
    /// - Returns: The newly created FeedSession
    /// - Throws: Core Data save error; context is rolled back on failure
    @discardableResult
    func startFeeding(for baby: BabyProfile) throws -> FeedSession {
        // Cancel any existing in-progress session
        if let ongoing = baby.inProgressFeedSession {
            context.delete(ongoing)
        }
        
        let newSession = FeedSession(context: context, startTime: Date.current)
        newSession.profile = baby
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return newSession
    }
    
    /// Finishes an in-progress feeding session.
    /// - Parameters:
    ///   - baby: The baby profile
    ///   - amount: The amount consumed
    ///   - feedType: Type of feed (formula, breastfeed, solid)
    ///   - memoText: Optional memo/hashtags
    /// - Returns: The finished session, or nil if no in-progress session exists
    /// - Throws: Core Data save error; context is rolled back on failure
    @discardableResult
    func finishFeeding(
        for baby: BabyProfile,
        amount: Measurement<UnitVolume>,
        feedType: FeedType,
        memoText: String? = nil
    ) throws -> FeedSession? {
        guard let session = baby.inProgressFeedSession else { return nil }
        
        session.endTime = Date.current
        session.amount = amount
        session.feedType = feedType
        session.memoText = memoText?.isEmpty == true ? nil : memoText
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return session
    }
    
    /// Cancels (deletes) an in-progress feeding session.
    /// - Returns: true if a session was cancelled, false if none existed
    /// - Throws: Core Data save error; context is rolled back on failure
    @discardableResult
    func cancelFeeding(for baby: BabyProfile) throws -> Bool {
        guard let session = baby.inProgressFeedSession else { return false }
        context.delete(session)
        
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return true
    }
}

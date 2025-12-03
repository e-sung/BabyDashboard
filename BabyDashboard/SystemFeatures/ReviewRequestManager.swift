import Foundation
import CoreData
import StoreKit
import Model

/// Manages App Store review requests based on user engagement criteria
final class ReviewRequestManager {
    
    // MARK: - UserDefaults Key
    
    private enum Keys {
        static let hasRequestedReview = "hasRequestedReview"
    }
    
    // MARK: - Singleton
    
    static let shared = ReviewRequestManager()
    
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - Public API
    
    /// Request review if eligible (has 7+ days of feed sessions and hasn't been requested before)
    /// - Parameters:
    ///   - context: The managed object context to query feed sessions
    ///   - requestReview: The StoreKit requestReview action from environment
    func requestReviewIfEligible(context: NSManagedObjectContext, requestReview: @escaping () -> Void) {
        // Check if we've already requested a review
        guard !hasRequestedReview else {
            debugPrint("[ReviewRequest] Already requested review, skipping")
            return
        }
        
        // Check if user has at least 7 days of feed session data
        let daysCount = countDaysWithFeedSessions(context: context)
        debugPrint("[ReviewRequest] Found \(daysCount) days with feed sessions")
        
        guard daysCount >= 7 else {
            debugPrint("[ReviewRequest] Insufficient data (\(daysCount) days, need 7+), skipping")
            return
        }
        
        // All conditions met, request review
        debugPrint("[ReviewRequest] Conditions met, requesting review")
        requestReview()
        markReviewAsRequested()
    }
    
    // MARK: - Private Helpers
    
    private var hasRequestedReview: Bool {
        userDefaults.bool(forKey: Keys.hasRequestedReview)
    }
    
    private func markReviewAsRequested() {
        userDefaults.set(true, forKey: Keys.hasRequestedReview)
        debugPrint("[ReviewRequest] Marked review as requested in UserDefaults")
    }
    
    /// Counts the number of distinct days that have at least one feed session
    private func countDaysWithFeedSessions(context: NSManagedObjectContext) -> Int {
        let calendar = Calendar.current
        
        // Fetch all feed sessions
        let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        guard let sessions = try? context.fetch(request) else {
            return 0
        }
        
        // Extract unique days
        var uniqueDays = Set<DateComponents>()
        for session in sessions {
            let components = calendar.dateComponents([.year, .month, .day], from: session.startTime)
            uniqueDays.insert(components)
        }
        
        return uniqueDays.count
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    /// Reset the review request flag for testing purposes
    func resetReviewRequestFlag() {
        userDefaults.removeObject(forKey: Keys.hasRequestedReview)
        debugPrint("[ReviewRequest] Reset review request flag")
    }
    #endif
}

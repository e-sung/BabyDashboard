import Foundation

/// Represents the type of feeding for a FeedSession.
/// Each case has an associated emoji for UI display.
public enum FeedType: String, CaseIterable, Codable, Sendable {
    case babyFormula
    case breastFeed
    case solid
    
    /// Emoji representation for UI display
    public var emoji: String {
        switch self {
        case .babyFormula: return "🍼"
        case .breastFeed: return "🤱"
        case .solid: return "🍲"
        }
    }
    
    /// Localized display name for UI
    public var displayName: String {
        switch self {
        case .babyFormula: return String(localized: "Baby Formula")
        case .breastFeed: return String(localized: "Breastfeed")
        case .solid: return String(localized: "Solid Food")
        }
    }
}

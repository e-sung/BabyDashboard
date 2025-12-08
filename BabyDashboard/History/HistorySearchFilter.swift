//
//  HistorySearchFilter.swift
//  BabyDashboard
//
//  Created by Antigravity on 12/08/25.
//

import Foundation
import CoreData
import Model

// MARK: - Search Token

/// A token representing a search filter criterion
/// Conforms to SearchableToken for use with TokenSuggestionsOverlay
enum SearchToken: SearchableToken {
    case baby(id: UUID, name: String)
    case feed
    case pee
    case poo
    case customEvent(emoji: String, name: String)
    case hashtag(String)
    
    var id: String {
        switch self {
        case .baby(let id, _):
            return "baby-\(id.uuidString)"
        case .feed:
            return "feed"
        case .pee:
            return "pee"
        case .poo:
            return "poo"
        case .customEvent(let emoji, _):
            return "custom-\(emoji)"
        case .hashtag(let tag):
            return "hashtag-\(tag)"
        }
    }
    
    var displayText: String {
        switch self {
        case .baby(_, let name):
            return name
        case .feed:
            return "🍼 Feed"
        case .pee:
            return "💧 Pee"
        case .poo:
            return "💩 Poo"
        case .customEvent(let emoji, let name):
            return "\(emoji) \(name)"
        case .hashtag(let tag):
            return "#\(tag)"
        }
    }
}

// MARK: - Event Metadata Provider

/// Protocol to abstract event metadata lookups for testability
protocol EventMetadataProvider {
    func babyID(for event: HistoryEvent) -> UUID?
    func memoText(for event: HistoryEvent) -> String?
    func customEventEmoji(for event: HistoryEvent) -> String?
    func customEventName(for event: HistoryEvent) -> String?
}

// MARK: - History Search Filter

/// Pure, testable struct that encapsulates all search/filtering logic
struct HistorySearchFilter {
    
    /// Filters events by tokens and text search
    /// - Parameters:
    ///   - events: All events to filter
    ///   - tokens: Search tokens (OR within category, AND between categories)
    ///   - searchText: Text to search for in event type name or memo
    ///   - metadataProvider: Provider for event metadata lookups
    /// - Returns: Filtered events
    static func filter(
        events: [HistoryEvent],
        tokens: [SearchToken],
        searchText: String,
        metadataProvider: EventMetadataProvider
    ) -> [HistoryEvent] {
        events.filter { event in
            matchesTokens(event: event, tokens: tokens, metadataProvider: metadataProvider) &&
            matchesText(event: event, searchText: searchText, metadataProvider: metadataProvider)
        }
    }
    
    // MARK: - Suggestion Filtering
    
    /// Filters token suggestions based on search text and already selected tokens
    /// - Parameters:
    ///   - allTokens: All available tokens
    ///   - searchText: Current search text (empty shows all)
    ///   - selectedTokens: Already selected tokens to exclude
    /// - Returns: Filtered suggestions
    static func filterSuggestions(
        allTokens: [SearchToken],
        searchText: String,
        selectedTokens: [SearchToken]
    ) -> [SearchToken] {
        // Exclude already selected tokens
        let availableTokens = allTokens.filter { token in
            !selectedTokens.contains { $0.id == token.id }
        }
        
        // If no search text, return all available
        guard !searchText.isEmpty else {
            return availableTokens
        }
        
        // Filter by search text matching displayText
        let lowercasedSearch = searchText.lowercased()
        return availableTokens.filter { token in
            token.displayText.lowercased().contains(lowercasedSearch)
        }
    }
    
    // MARK: - Token Matching
    
    private static func matchesTokens(
        event: HistoryEvent,
        tokens: [SearchToken],
        metadataProvider: EventMetadataProvider
    ) -> Bool {
        guard !tokens.isEmpty else { return true }
        
        // Group tokens by category
        let babyTokens = tokens.compactMap { token -> UUID? in
            if case .baby(let id, _) = token { return id }
            return nil
        }
        let eventTypeTokens = tokens.filter { token in
            switch token {
            case .feed, .pee, .poo: return true
            default: return false
            }
        }
        let customEventTokens = tokens.compactMap { token -> String? in
            if case .customEvent(let emoji, _) = token { return emoji }
            return nil
        }
        
        // Check baby tokens (OR logic within category)
        if !babyTokens.isEmpty {
            guard let eventBabyID = metadataProvider.babyID(for: event),
                  babyTokens.contains(eventBabyID) else {
                return false
            }
        }
        
        // Check event type tokens (OR logic within category)
        if !eventTypeTokens.isEmpty {
            let matchesEventType = eventTypeTokens.contains { token in
                switch (token, event.type) {
                case (.feed, .feed):
                    return true
                case (.pee, .diaper):
                    return event.diaperType == .pee
                case (.poo, .diaper):
                    return event.diaperType == .poo
                default:
                    return false
                }
            }
            guard matchesEventType else { return false }
        }
        
        // Check custom event tokens (OR logic within category)
        if !customEventTokens.isEmpty {
            guard event.type == .customEvent,
                  let eventEmoji = metadataProvider.customEventEmoji(for: event),
                  customEventTokens.contains(eventEmoji) else {
                return false
            }
        }
        
        // Check hashtag tokens (OR logic within category)
        let hashtagTokens = tokens.compactMap { token -> String? in
            if case .hashtag(let tag) = token { return tag.lowercased() }
            return nil
        }
        if !hashtagTokens.isEmpty {
            let eventHashtags = event.hashtags.map { $0.lowercased() }
            guard !eventHashtags.isEmpty,
                  hashtagTokens.contains(where: { eventHashtags.contains($0) }) else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Text Search
    
    private static func matchesText(
        event: HistoryEvent,
        searchText: String,
        metadataProvider: EventMetadataProvider
    ) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        let lowercasedSearch = searchText.lowercased()
        
        // Search in event type name
        let matchesEventTypeName: Bool = {
            switch event.type {
            case .feed:
                return "feed".contains(lowercasedSearch)
            case .diaper:
                if event.diaperType == .pee {
                    return "pee".contains(lowercasedSearch)
                } else if event.diaperType == .poo {
                    return "poo".contains(lowercasedSearch)
                }
                return false
            case .customEvent:
                if let name = metadataProvider.customEventName(for: event) {
                    return name.lowercased().contains(lowercasedSearch)
                }
                return false
            @unknown default:
                return false
            }
        }()
        
        // Search in memo text
        let matchesMemo: Bool = {
            if let memo = metadataProvider.memoText(for: event) {
                return memo.lowercased().contains(lowercasedSearch)
            }
            return false
        }()
        
        return matchesEventTypeName || matchesMemo
    }
}

// MARK: - HistoryView Metadata Provider

/// Provides event metadata from Core Data objects for filtering
struct HistoryViewMetadataProvider: EventMetadataProvider {
    let feedSessions: [FeedSession]
    let diaperChanges: [DiaperChange]
    let customEvents: [CustomEvent]
    
    func babyID(for event: HistoryEvent) -> UUID? {
        switch event.type {
        case .feed:
            return feedSessions.first(where: { $0.objectID == event.underlyingObjectId })?.profile?.id
        case .diaper:
            return diaperChanges.first(where: { $0.objectID == event.underlyingObjectId })?.profile?.id
        case .customEvent:
            return customEvents.first(where: { $0.objectID == event.underlyingObjectId })?.profile?.id
        @unknown default:
            return nil
        }
    }
    
    func memoText(for event: HistoryEvent) -> String? {
        switch event.type {
        case .feed:
            return feedSessions.first(where: { $0.objectID == event.underlyingObjectId })?.memoText
        case .diaper:
            return diaperChanges.first(where: { $0.objectID == event.underlyingObjectId })?.memoText
        case .customEvent:
            return customEvents.first(where: { $0.objectID == event.underlyingObjectId })?.memoText
        @unknown default:
            return nil
        }
    }
    
    func customEventEmoji(for event: HistoryEvent) -> String? {
        guard event.type == .customEvent else { return nil }
        return customEvents.first(where: { $0.objectID == event.underlyingObjectId })?.eventTypeEmoji
    }
    
    func customEventName(for event: HistoryEvent) -> String? {
        guard event.type == .customEvent else { return nil }
        return customEvents.first(where: { $0.objectID == event.underlyingObjectId })?.eventTypeName
    }
}

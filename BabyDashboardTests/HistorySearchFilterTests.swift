//
//  HistorySearchFilterTests.swift
//  BabyDashboardTests
//
//  Created by Antigravity on 12/08/25.
//

import XCTest
@testable import BabyDashboard
import Model

final class HistorySearchFilterTests: XCTestCase {
    
    // MARK: - Mock Metadata Provider
    
    class MockMetadataProvider: EventMetadataProvider {
        var babyIDs: [UUID: UUID] = [:] // event.id -> babyID
        var memoTexts: [UUID: String] = [:] // event.id -> memo
        var customEventEmojis: [UUID: String] = [:] // event.id -> emoji
        var customEventNames: [UUID: String] = [:] // event.id -> name
        
        func babyID(for event: HistoryEvent) -> UUID? {
            babyIDs[event.id]
        }
        
        func memoText(for event: HistoryEvent) -> String? {
            memoTexts[event.id]
        }
        
        func customEventEmoji(for event: HistoryEvent) -> String? {
            customEventEmojis[event.id]
        }
        
        func customEventName(for event: HistoryEvent) -> String? {
            customEventNames[event.id]
        }
    }
    
    // MARK: - Test Fixtures
    
    let babyAId = UUID()
    let babyBId = UUID()
    
    var feedEventA: HistoryEvent!
    var feedEventB: HistoryEvent!
    var peeEventA: HistoryEvent!
    var pooEventA: HistoryEvent!
    var napEventA: HistoryEvent!
    var bathEventB: HistoryEvent!
    
    var allEvents: [HistoryEvent]!
    var mockProvider: MockMetadataProvider!
    
    override func setUp() {
        super.setUp()
        
        // Create test events using correct HistoryEvent signature
        feedEventA = HistoryEvent(
            id: UUID(),
            date: Date(),
            babyName: "Baby A",
            type: .feed,
            details: "120 ml",
            diaperType: nil,
            underlyingObjectId: nil
        )
        
        feedEventB = HistoryEvent(
            id: UUID(),
            date: Date().addingTimeInterval(-3600),
            babyName: "Baby B",
            type: .feed,
            details: "100 ml",
            diaperType: nil,
            underlyingObjectId: nil
        )
        
        peeEventA = HistoryEvent(
            id: UUID(),
            date: Date().addingTimeInterval(-1800),
            babyName: "Baby A",
            type: .diaper,
            details: "Pee",
            diaperType: .pee,
            underlyingObjectId: nil
        )
        
        pooEventA = HistoryEvent(
            id: UUID(),
            date: Date().addingTimeInterval(-900),
            babyName: "Baby A",
            type: .diaper,
            details: "Poo",
            diaperType: .poo,
            underlyingObjectId: nil
        )
        
        napEventA = HistoryEvent(
            id: UUID(),
            date: Date().addingTimeInterval(-5400),
            babyName: "Baby A",
            type: .customEvent,
            details: "Nap",
            diaperType: nil,
            underlyingObjectId: nil,
            emoji: "😴"
        )
        
        bathEventB = HistoryEvent(
            id: UUID(),
            date: Date().addingTimeInterval(-7200),
            babyName: "Baby B",
            type: .customEvent,
            details: "Bath",
            diaperType: nil,
            underlyingObjectId: nil,
            emoji: "🛁"
        )
        
        allEvents = [feedEventA, feedEventB, peeEventA, pooEventA, napEventA, bathEventB]
        
        // Setup mock provider
        mockProvider = MockMetadataProvider()
        mockProvider.babyIDs[feedEventA.id] = babyAId
        mockProvider.babyIDs[feedEventB.id] = babyBId
        mockProvider.babyIDs[peeEventA.id] = babyAId
        mockProvider.babyIDs[pooEventA.id] = babyAId
        mockProvider.babyIDs[napEventA.id] = babyAId
        mockProvider.babyIDs[bathEventB.id] = babyBId
        
        mockProvider.customEventEmojis[napEventA.id] = "😴"
        mockProvider.customEventEmojis[bathEventB.id] = "🛁"
        mockProvider.customEventNames[napEventA.id] = "Nap"
        mockProvider.customEventNames[bathEventB.id] = "Bath"
        
        mockProvider.memoTexts[feedEventA.id] = "Good morning feed #tired"
        mockProvider.memoTexts[pooEventA.id] = "After meal"
    }
    
    // MARK: - Token Filtering - Baby
    
    func testFilterBySingleBaby() {
        let tokens: [SearchToken] = [.baby(id: babyAId, name: "Baby A")]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 4) // feedEventA, peeEventA, pooEventA, napEventA
        XCTAssertTrue(result.allSatisfy { mockProvider.babyID(for: $0) == babyAId })
    }
    
    func testFilterByMultipleBabies_ORLogic() {
        let tokens: [SearchToken] = [
            .baby(id: babyAId, name: "Baby A"),
            .baby(id: babyBId, name: "Baby B")
        ]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 6) // All events (OR logic)
    }
    
    // MARK: - Token Filtering - Event Type
    
    func testFilterByFeed() {
        let tokens: [SearchToken] = [.feed]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.type == .feed })
    }
    
    func testFilterByPee() {
        let tokens: [SearchToken] = [.pee]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.diaperType, .pee)
    }
    
    func testFilterByPoo() {
        let tokens: [SearchToken] = [.poo]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.diaperType, .poo)
    }
    
    func testFilterByMultipleEventTypes_ORLogic() {
        let tokens: [SearchToken] = [.feed, .pee]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 3) // 2 feeds + 1 pee
    }
    
    // MARK: - Token Filtering - Custom Event
    
    func testFilterByCustomEvent() {
        let tokens: [SearchToken] = [.customEvent(emoji: "😴", name: "Nap")]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, napEventA.id)
    }
    
    func testFilterByMultipleCustomEvents_ORLogic() {
        let tokens: [SearchToken] = [
            .customEvent(emoji: "😴", name: "Nap"),
            .customEvent(emoji: "🛁", name: "Bath")
        ]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 2)
    }
    
    // MARK: - Multi-Category Tokens (AND Logic)
    
    func testFilterByBabyAndEventType_ANDLogic() {
        let tokens: [SearchToken] = [
            .baby(id: babyAId, name: "Baby A"),
            .feed
        ]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, feedEventA.id)
    }
    
    func testFilterByBabyAndCustomEvent_ANDLogic() {
        let tokens: [SearchToken] = [
            .baby(id: babyBId, name: "Baby B"),
            .customEvent(emoji: "🛁", name: "Bath")
        ]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, bathEventB.id)
    }
    
    // MARK: - Text Search
    
    func testTextSearchMatchesEventTypeName() {
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: [],
            searchText: "feed",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 2) // Both feed events
    }
    
    func testTextSearchMatchesMemo() {
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: [],
            searchText: "tired",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, feedEventA.id)
    }
    
    func testTextSearchIsCaseInsensitive() {
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: [],
            searchText: "FEED",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 2)
    }
    
    func testTextSearchMatchesCustomEventName() {
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: [],
            searchText: "nap",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, napEventA.id)
    }
    
    // MARK: - Combined Token + Text Search
    
    func testCombinedTokenAndTextSearch() {
        let tokens: [SearchToken] = [.baby(id: babyAId, name: "Baby A")]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "morning",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, feedEventA.id)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTokensReturnsAllEvents() {
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: [],
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, allEvents.count)
    }
    
    func testEmptyEventsReturnsEmpty() {
        let result = HistorySearchFilter.filter(
            events: [],
            tokens: [.feed],
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testNoMatchesReturnsEmpty() {
        let nonExistentBabyId = UUID()
        let tokens: [SearchToken] = [.baby(id: nonExistentBabyId, name: "Unknown")]
        
        let result = HistorySearchFilter.filter(
            events: allEvents,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - Token Filtering - Hashtag
    
    func testFilterByHashtag() {
        // Create events with hashtags
        let eventWithHashtag = HistoryEvent(
            id: UUID(),
            date: Date(),
            babyName: "Baby A",
            type: .feed,
            details: "100 ml",
            diaperType: nil,
            underlyingObjectId: nil,
            hashtags: ["morning", "goodfeed"]
        )
        
        let eventWithoutHashtag = HistoryEvent(
            id: UUID(),
            date: Date(),
            babyName: "Baby A",
            type: .feed,
            details: "120 ml",
            diaperType: nil,
            underlyingObjectId: nil,
            hashtags: []
        )
        
        let events = [eventWithHashtag, eventWithoutHashtag]
        let tokens: [SearchToken] = [.hashtag("morning")]
        
        let result = HistorySearchFilter.filter(
            events: events,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, eventWithHashtag.id)
    }
    
    func testFilterByHashtag_CaseInsensitive() {
        let eventWithHashtag = HistoryEvent(
            id: UUID(),
            date: Date(),
            babyName: "Baby A",
            type: .feed,
            details: "100 ml",
            diaperType: nil,
            underlyingObjectId: nil,
            hashtags: ["Morning"]  // Capitalized
        )
        
        let events = [eventWithHashtag]
        let tokens: [SearchToken] = [.hashtag("morning")]  // lowercase
        
        let result = HistorySearchFilter.filter(
            events: events,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 1)
    }
    
    func testFilterByMultipleHashtags_ORLogic() {
        let eventWithMorning = HistoryEvent(
            id: UUID(),
            date: Date(),
            babyName: "Baby A",
            type: .feed,
            details: "100 ml",
            diaperType: nil,
            underlyingObjectId: nil,
            hashtags: ["morning"]
        )
        
        let eventWithEvening = HistoryEvent(
            id: UUID(),
            date: Date(),
            babyName: "Baby A",
            type: .feed,
            details: "120 ml",
            diaperType: nil,
            underlyingObjectId: nil,
            hashtags: ["evening"]
        )
        
        let events = [eventWithMorning, eventWithEvening]
        let tokens: [SearchToken] = [.hashtag("morning"), .hashtag("evening")]
        
        let result = HistorySearchFilter.filter(
            events: events,
            tokens: tokens,
            searchText: "",
            metadataProvider: mockProvider
        )
        
        XCTAssertEqual(result.count, 2)
    }
    
    // MARK: - filterSuggestions Tests
    
    func testFilterSuggestions_EmptyText_ReturnsAllAvailable() {
        let allTokens: [SearchToken] = [
            .feed,
            .pee,
            .poo,
            .baby(id: babyAId, name: "Baby A"),
            .hashtag("morning")
        ]
        let selectedTokens: [SearchToken] = []
        
        let result = HistorySearchFilter.filterSuggestions(
            allTokens: allTokens,
            searchText: "",
            selectedTokens: selectedTokens
        )
        
        XCTAssertEqual(result.count, 5) // All tokens returned
    }
    
    func testFilterSuggestions_WithText_FiltersMatching() {
        let allTokens: [SearchToken] = [
            .feed,
            .pee,
            .poo,
            .baby(id: babyAId, name: "Baby A"),
            .hashtag("morning")
        ]
        let selectedTokens: [SearchToken] = []
        
        let result = HistorySearchFilter.filterSuggestions(
            allTokens: allTokens,
            searchText: "fee",
            selectedTokens: selectedTokens
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, .feed)
    }
    
    func testFilterSuggestions_WithText_MatchesHashtag() {
        let allTokens: [SearchToken] = [
            .feed,
            .pee,
            .hashtag("morning"),
            .hashtag("evening")
        ]
        let selectedTokens: [SearchToken] = []
        
        let result = HistorySearchFilter.filterSuggestions(
            allTokens: allTokens,
            searchText: "morn",
            selectedTokens: selectedTokens
        )
        
        XCTAssertEqual(result.count, 1)
        if case .hashtag(let tag) = result.first {
            XCTAssertEqual(tag, "morning")
        } else {
            XCTFail("Expected hashtag token")
        }
    }
    
    func testFilterSuggestions_ExcludesSelectedTokens() {
        let allTokens: [SearchToken] = [
            .feed,
            .pee,
            .poo
        ]
        let selectedTokens: [SearchToken] = [.feed]
        
        let result = HistorySearchFilter.filterSuggestions(
            allTokens: allTokens,
            searchText: "",
            selectedTokens: selectedTokens
        )
        
        XCTAssertEqual(result.count, 2) // feed excluded
        XCTAssertFalse(result.contains(.feed))
        XCTAssertTrue(result.contains(.pee))
        XCTAssertTrue(result.contains(.poo))
    }
    
    func testFilterSuggestions_CaseInsensitiveMatching() {
        let allTokens: [SearchToken] = [
            .feed,
            .baby(id: babyAId, name: "Baby A")
        ]
        let selectedTokens: [SearchToken] = []
        
        let result = HistorySearchFilter.filterSuggestions(
            allTokens: allTokens,
            searchText: "FEED",
            selectedTokens: selectedTokens
        )
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first, .feed)
    }
}

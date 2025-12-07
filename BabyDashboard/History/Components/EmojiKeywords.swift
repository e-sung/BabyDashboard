//
//  EmojiKeywords.swift
//  BabyDashboard
//
//  Curated emoji database with searchable keywords for baby care events
//

import Foundation

/// Represents an emoji with associated searchable keywords
struct EmojiData: Identifiable {
    let id: String // The emoji itself serves as the ID
    let emoji: String
    let keywords: [String] // Localized keywords for search
    
    init(emoji: String, keywords: [String]) {
        self.id = emoji
        self.emoji = emoji
        self.keywords = keywords
    }
}

/// Database of curated baby-related emojis with searchable keywords
struct EmojiDatabase {
    static let babyEmojis: [EmojiData] = [
        // Feeding & Food
        EmojiData(emoji: "🍼", keywords: ["bottle", "milk", "feed", "nursing", "formula"]),
        EmojiData(emoji: "🍎", keywords: ["apple", "fruit", "food", "snack", "healthy"]),
        EmojiData(emoji: "🥕", keywords: ["carrot", "vegetable", "food", "healthy", "orange"]),
        EmojiData(emoji: "🍌", keywords: ["banana", "fruit", "food", "snack", "yellow"]),
        EmojiData(emoji: "🥛", keywords: ["milk", "drink", "dairy", "beverage"]),
        EmojiData(emoji: "🥄", keywords: ["spoon", "eating", "utensil", "feeding"]),
        
        // Health & Medicine
        EmojiData(emoji: "💊", keywords: ["pill", "medicine", "medication", "vitamin", "drug", "health"]),
        EmojiData(emoji: "🌡️", keywords: ["thermometer", "temperature", "fever", "sick", "ill"]),
        EmojiData(emoji: "🩹", keywords: ["bandaid", "bandage", "injury", "wound", "hurt"]),
        EmojiData(emoji: "💉", keywords: ["syringe", "shot", "vaccine", "injection", "doctor"]),
        
        // Hygiene & Care
        EmojiData(emoji: "🛁", keywords: ["bath", "bathtub", "clean", "wash", "hygiene"]),
        EmojiData(emoji: "🧼", keywords: ["soap", "clean", "wash", "hygiene"]),
        EmojiData(emoji: "🧴", keywords: ["lotion", "cream", "bottle", "skincare"]),
        EmojiData(emoji: "🪥", keywords: ["toothbrush", "teeth", "dental", "brush", "hygiene"]),
        
        // Sleep & Rest
        EmojiData(emoji: "😴", keywords: ["sleep", "sleeping", "tired", "nap", "rest", "zzz"]),
        EmojiData(emoji: "🛏️", keywords: ["bed", "sleep", "nap", "rest", "bedroom"]),
        EmojiData(emoji: "🌙", keywords: ["moon", "night", "nighttime", "bedtime", "sleep"]),
        
        // Emotions & Expressions
        EmojiData(emoji: "😊", keywords: ["happy", "smile", "joy", "pleased", "content"]),
        EmojiData(emoji: "😭", keywords: ["cry", "crying", "sad", "tears", "upset"]),
        EmojiData(emoji: "😂", keywords: ["laugh", "laughing", "funny", "joy", "happy"]),
        EmojiData(emoji: "😡", keywords: ["angry", "mad", "frustrated", "upset", "tantrum"]),
        EmojiData(emoji: "🤮", keywords: ["vomit", "throw up", "sick", "ill", "nausea", "puke"]),
        EmojiData(emoji: "🤧", keywords: ["sneeze", "sick", "cold", "allergy", "tissue"]),
        
        // Activities & Play
        EmojiData(emoji: "🎵", keywords: ["music", "song", "singing", "melody", "sound"]),
        EmojiData(emoji: "📚", keywords: ["book", "reading", "story", "learning", "education"]),
        EmojiData(emoji: "🧸", keywords: ["teddy", "bear", "toy", "stuffed animal", "play"]),
        EmojiData(emoji: "🎨", keywords: ["art", "paint", "creative", "drawing", "craft"]),
        EmojiData(emoji: "⚽", keywords: ["ball", "soccer", "play", "sport", "game"]),
        
        // Nature & Outdoors
        EmojiData(emoji: "🌞", keywords: ["sun", "sunny", "day", "bright", "outside"]),
        EmojiData(emoji: "🌳", keywords: ["tree", "nature", "outside", "park", "outdoor"]),
    ]
    
    /// Searches emojis by keyword (case-insensitive)
    static func search(_ query: String) -> [EmojiData] {
        guard !query.isEmpty else {
            return babyEmojis
        }
        
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return babyEmojis.filter { emojiData in
            emojiData.keywords.contains { keyword in
                keyword.lowercased().contains(lowercasedQuery)
            }
        }
    }
}

import Foundation

extension String {
    /// Returns only the emoji characters from the string
    func onlyEmoji() -> String {
        return self.filter { $0.isEmoji }
    }
    
    /// Checks if the string contains only emoji characters
    var isEmoji: Bool {
        return !isEmpty && allSatisfy { $0.isEmoji }
    }
}

extension Character {
    /// Checks if a character is an emoji
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}

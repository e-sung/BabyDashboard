import Foundation
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

final class AppSettings: ObservableObject {
    // Keys
    private enum Keys {
        static let startOfDayHour = "startOfDayHour"
        static let startOfDayMinute = "startOfDayMinute"
        static let didSeedBabiesOnce = "didSeedBabiesOnce" // iCloud-wide seed guard
        static let recentHashtags = "recentHashtags"
        static let preferredFontScale = "preferredFontScale"
    }

    // Backing stores
    private let local = UserDefaults.standard
    private let ubiquitous = NSUbiquitousKeyValueStore.default

    @Published var startOfDayHour: Int {
        didSet {
            write(value: startOfDayHour, forKey: Keys.startOfDayHour)
        }
    }

    @Published var startOfDayMinute: Int {
        didSet {
            write(value: startOfDayMinute, forKey: Keys.startOfDayMinute)
        }
    }

    // Whether any device in this iCloud account has performed the default seed.
    // Stored in both local and ubiquitous stores; ubiquitous wins when available.
    @Published var didSeedBabiesOnce: Bool {
        didSet {
            write(bool: didSeedBabiesOnce, forKey: Keys.didSeedBabiesOnce)
        }
    }

    // MRU list of recent hashtags (strings with leading '#')
    @Published var recentHashtags: [String] {
        didSet {
            write(array: recentHashtags, forKey: Keys.recentHashtags)
        }
    }

    @Published var preferredFontScale: AppFontScale {
        didSet {
            write(value: preferredFontScale.rawValue, forKey: Keys.preferredFontScale)
        }
    }

    private var notificationObserver: NSObjectProtocol?

    init() {
        // Pull latest from iCloud first, then fall back to local defaults.
        ubiquitous.synchronize()

        let hour = (ubiquitous.object(forKey: Keys.startOfDayHour) as? Int)
            ?? local.object(forKey: Keys.startOfDayHour) as? Int
            ?? 7
        let minute = (ubiquitous.object(forKey: Keys.startOfDayMinute) as? Int)
            ?? local.object(forKey: Keys.startOfDayMinute) as? Int
            ?? 0

        let seeded = (ubiquitous.object(forKey: Keys.didSeedBabiesOnce) as? Bool)
            ?? local.object(forKey: Keys.didSeedBabiesOnce) as? Bool
            ?? false

        let hashtags = (ubiquitous.array(forKey: Keys.recentHashtags) as? [String])
            ?? local.array(forKey: Keys.recentHashtags) as? [String]
            ?? []

        let fontScaleRaw = (ubiquitous.string(forKey: Keys.preferredFontScale))
            ?? local.string(forKey: Keys.preferredFontScale)
            ?? AppFontScale.system.rawValue

        self.startOfDayHour = hour
        self.startOfDayMinute = minute
        self.didSeedBabiesOnce = seeded
        self.recentHashtags = hashtags
        self.preferredFontScale = AppFontScale(rawValue: fontScaleRaw) ?? .system

        // Keep local store consistent with the chosen initial values
        local.set(hour, forKey: Keys.startOfDayHour)
        local.set(minute, forKey: Keys.startOfDayMinute)
        local.set(seeded, forKey: Keys.didSeedBabiesOnce)
        local.set(hashtags, forKey: Keys.recentHashtags)
        local.set(fontScaleRaw, forKey: Keys.preferredFontScale)

        // Observe incoming iCloud KVS changes
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitous,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            if let userInfo = note.userInfo,
               let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
               reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange,
               let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {

                if changedKeys.contains(Keys.startOfDayHour),
                   let newHour = self.ubiquitous.object(forKey: Keys.startOfDayHour) as? Int,
                   self.startOfDayHour != newHour {
                    self.startOfDayHour = newHour
                    self.local.set(newHour, forKey: Keys.startOfDayHour)
                }

                if changedKeys.contains(Keys.startOfDayMinute),
                   let newMinute = self.ubiquitous.object(forKey: Keys.startOfDayMinute) as? Int,
                   self.startOfDayMinute != newMinute {
                    self.startOfDayMinute = newMinute
                    self.local.set(newMinute, forKey: Keys.startOfDayMinute)
                }

                if changedKeys.contains(Keys.didSeedBabiesOnce),
                   let newSeeded = self.ubiquitous.object(forKey: Keys.didSeedBabiesOnce) as? Bool,
                   self.didSeedBabiesOnce != newSeeded {
                    self.didSeedBabiesOnce = newSeeded
                    self.local.set(newSeeded, forKey: Keys.didSeedBabiesOnce)
                }

                if changedKeys.contains(Keys.recentHashtags),
                   let newTags = self.ubiquitous.array(forKey: Keys.recentHashtags) as? [String],
                   self.recentHashtags != newTags {
                    self.recentHashtags = newTags
                    self.recentHashtags = newTags
                    self.local.set(newTags, forKey: Keys.recentHashtags)
                }

                if changedKeys.contains(Keys.preferredFontScale),
                   let newScaleRaw = self.ubiquitous.string(forKey: Keys.preferredFontScale),
                   let newScale = AppFontScale(rawValue: newScaleRaw),
                   self.preferredFontScale != newScale {
                    self.preferredFontScale = newScale
                    self.local.set(newScaleRaw, forKey: Keys.preferredFontScale)
                }
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Write-through helpers: keep both local and iCloud stores updated.
    private func write(value: Int, forKey key: String) {
        local.set(value, forKey: key)
        ubiquitous.set(value, forKey: key)
        ubiquitous.synchronize()
    }

    private func write(bool: Bool, forKey key: String) {
        local.set(bool, forKey: key)
        ubiquitous.set(bool, forKey: key)
        ubiquitous.synchronize()
    }

    private func write(array: [String], forKey key: String) {
        local.set(array, forKey: key)
        ubiquitous.set(array, forKey: key)
        ubiquitous.synchronize()
    }

    private func write(value: String, forKey key: String) {
        local.set(value, forKey: key)
        ubiquitous.set(value, forKey: key)
        ubiquitous.synchronize()
    }

    // Public helpers

    func addRecentHashtags(from memoText: String, maxCount: Int = 12) {
        let tags = AppSettings.extractHashtags(from: memoText)
        guard !tags.isEmpty else { return }
        var mru = recentHashtags
        // Move to front, dedup case-insensitively
        for tag in tags {
            let lower = tag.lowercased()
            if let idx = mru.firstIndex(where: { $0.lowercased() == lower }) {
                mru.remove(at: idx)
            }
            mru.insert(tag, at: 0)
        }
        // Trim
        if mru.count > maxCount {
            mru = Array(mru.prefix(maxCount))
        }
        recentHashtags = mru
    }

    static func extractHashtags(from text: String) -> [String] {
        let pattern = #"(?<!\w)#([\p{L}\p{N}_]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        var tags: [String] = matches.map {
            ns.substring(with: $0.range(at: 0))
        }
        var seen = Set<String>()
        tags = tags.filter { seen.insert($0.lowercased()).inserted }
        return tags
    }
}

enum AppFontScale: String, CaseIterable, Identifiable {
    case system
    case xSmall
    case small
    case medium
    case large
    case xLarge
    case xxLarge
    case xxxLarge
    case accessibility1
    case accessibility2
    case accessibility3
    case accessibility4
    case accessibility5

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System Default"
        case .xSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .xLarge: return "Extra Large"
        case .xxLarge: return "Extra Extra Large"
        case .xxxLarge: return "Extra Extra Extra Large"
        case .accessibility1: return "Accessibility Medium"
        case .accessibility2: return "Accessibility Large"
        case .accessibility3: return "Accessibility Extra Large"
        case .accessibility4: return "Accessibility Extra Extra Large"
        case .accessibility5: return "Accessibility Extra Extra Extra Large"
        }
    }

    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .system:
            #if canImport(UIKit)
            let category = UIApplication.shared.preferredContentSizeCategory
            switch category {
            case .extraSmall: return .xSmall
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .extraLarge: return .xLarge
            case .extraExtraLarge: return .xxLarge
            case .extraExtraExtraLarge: return .xxxLarge
            case .accessibilityMedium: return .accessibility1
            case .accessibilityLarge: return .accessibility2
            case .accessibilityExtraLarge: return .accessibility3
            case .accessibilityExtraExtraLarge: return .accessibility4
            case .accessibilityExtraExtraExtraLarge: return .accessibility5
            default:
                return nil
            }
            #else
            return nil
            #endif
        case .xSmall: return .xSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .xLarge
        case .xxLarge: return .xxLarge
        case .xxxLarge: return .xxxLarge
        case .accessibility1: return .accessibility1
        case .accessibility2: return .accessibility2
        case .accessibility3: return .accessibility3
        case .accessibility4: return .accessibility4
        case .accessibility5: return .accessibility5
        }
    }
}

#if DEBUG
extension AppSettings {
    func resetAll() {
        startOfDayHour = 7
        startOfDayMinute = 0
        didSeedBabiesOnce = false
        recentHashtags = []

        local.removeObject(forKey: Keys.startOfDayHour)
        local.removeObject(forKey: Keys.startOfDayMinute)
        local.removeObject(forKey: Keys.didSeedBabiesOnce)
        local.removeObject(forKey: Keys.recentHashtags)
        local.removeObject(forKey: Keys.preferredFontScale)

        ubiquitous.removeObject(forKey: Keys.startOfDayHour)
        ubiquitous.removeObject(forKey: Keys.startOfDayMinute)
        ubiquitous.removeObject(forKey: Keys.didSeedBabiesOnce)
        ubiquitous.removeObject(forKey: Keys.recentHashtags)
        ubiquitous.removeObject(forKey: Keys.preferredFontScale)
        ubiquitous.synchronize()
    }
}
#endif

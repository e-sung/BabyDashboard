import Foundation
import Combine

final class AppSettings: ObservableObject {
    // Keys
    private enum Keys {
        static let startOfDayHour = "startOfDayHour"
        static let startOfDayMinute = "startOfDayMinute"
        static let didSeedBabiesOnce = "didSeedBabiesOnce" // iCloud-wide seed guard
        static let recentHashtags = "recentHashtags"
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

        self.startOfDayHour = hour
        self.startOfDayMinute = minute
        self.didSeedBabiesOnce = seeded
        self.recentHashtags = hashtags

        // Keep local store consistent with the chosen initial values
        local.set(hour, forKey: Keys.startOfDayHour)
        local.set(minute, forKey: Keys.startOfDayMinute)
        local.set(seeded, forKey: Keys.didSeedBabiesOnce)
        local.set(hashtags, forKey: Keys.recentHashtags)

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
                    self.local.set(newTags, forKey: Keys.recentHashtags)
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


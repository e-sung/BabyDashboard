
import Foundation

extension UUID: Identifiable {
    public var id: UUID { self }
}

struct BabyProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var feedingInterval: TimeInterval {
        // TODO: should be configurable per baby
        return 3600 * 3
    }
}

class BabyState: ObservableObject, Identifiable {
    @Published var profile: BabyProfile
    @Published var feedState: FeedState
    @Published var diaperState: DiaperState

    init(profile: BabyProfile, feedState: FeedState, diaperState: DiaperState) {
        self.profile = profile
        self.feedState = feedState
        self.diaperState = diaperState
    }
}

struct FeedState {
    var feededAt: Date?
    var elapsedTimeFormatted: String {
        if feededAt != nil {
            return formatElapsedTime(from: elapsedTime)
        }
        return "--:--"
    }
    var elapsedTime: TimeInterval {
        if let feededAt {
            return Date().timeIntervalSince(feededAt)
        }
        return 0
    }

    var shouldWarn: Bool {
        elapsedTime > (3 * 3600) // 3 hours
    }

    var progress: Double {
        return elapsedTime / (3 * 3600)
    }
}

struct DiaperState {
    var diaperChangedAt: Date?
    var elapsedTimeFormatted: String {
        if diaperChangedAt != nil {
            return formatElapsedTime(from: elapsedTime)
        }
        return "--:--"
    }
    var elapsedTime: TimeInterval {
        if let diaperChangedAt {
            return Date().timeIntervalSince(diaperChangedAt)
        }
        return 0
    }

    var shouldWarn: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour > 19 && hour < 7 {
            return elapsedTime > (3 * 3600) // 3hour for night
        }
        return elapsedTime > (1 * 3600) // 1 hour for day
    }
}

func formatElapsedTime(from interval: TimeInterval) -> String {
    guard interval >= 0 else { return "" }
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    if hours > 0 {
        if minutes == 0 {
            return String(localized: "\(hours)시간 전")
        }
        return String(localized: "\(hours)시간 \(minutes)분 전", comment: "Elapsed time format: X hours Y minutes ago")
    } else if minutes > 0 {
        return String(localized: "\(minutes)분 전", comment: "Elapsed time format: Y minutes ago")
    } else {
        return String(localized: "방금 전", comment: "Elapsed time format: Just now")
    }
}

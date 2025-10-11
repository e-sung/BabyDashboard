
import Foundation

struct BabyProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
}

class BabyState: ObservableObject, Identifiable {
    let profile: BabyProfile
    @Published var lastFeedingTime: Date?
    @Published var elapsedTime: String = ""
    @Published var isWarning: Bool = false
    @Published var progress: Double = 0.0

    init(profile: BabyProfile) {
        self.profile = profile
    }
}

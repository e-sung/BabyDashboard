import Foundation

// Returns the UserDefaults for the app group. Falls back to .standard if misconfigured.
func appGroupUserDefaults() -> UserDefaults {
    #if DEBUG
    let suite = "group.sungdoo.babyDashboard.dev"
    #else
    let suite = "group.sungdoo.babyDashboard"
    #endif
    return UserDefaults(suiteName: suite) ?? .standard
}

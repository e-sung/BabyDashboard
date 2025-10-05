import AppIntents
import Foundation

private let suiteName = "group.sungdoo.fullscreenClock"

struct UpdateYeondooFeedingTimeIntent: AppIntent  {

    static var title: LocalizedStringResource = "연두 수유 시간 기록"
    static var description = IntentDescription("연두의 마지막 수유 시간을 현재 시간으로 기록합니다.")
    
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let sharedDefaults = UserDefaults(suiteName: suiteName) {
            let currentTime = Date().formatted(
                Date.FormatStyle()
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
            )
            sharedDefaults.set(currentTime, forKey: "연두수유시간")
            return .result(dialog: "연두 수유 시간을 \(currentTime)으로 기록했어요.")
        } else {
            return .result(dialog: "App Group이 설정되지 않았습니다.")
        }
    }
}

struct UpdateChowonFeedingTimeIntent: AppIntent {

    static var title: LocalizedStringResource = "초원 수유 시간 기록"
    static var description = IntentDescription("초원의 마지막 수유 시간을 현재 시간으로 기록합니다.")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let sharedDefaults = UserDefaults(suiteName: suiteName) {
            let currentTime = Date().formatted(
                Date.FormatStyle()
                    .hour(.twoDigits(amPM: .omitted))
                    .minute(.twoDigits)
            )
            sharedDefaults.set(currentTime, forKey: "초원수유시간")
            return .result(dialog: "초원 수유 시간을 \(currentTime)으로 기록했어요.")
        } else {
            return .result(dialog: "App Group이 설정되지 않았습니다.")
        }
    }
}

struct BabyMonitorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UpdateYeondooFeedingTimeIntent(),
            phrases: [
                "\(.applicationName)으로 연두 수유 시간 기록",
                "\(.applicationName)으로 연두 수유"
            ],
            shortTitle: "연두 수유 기록",
            systemImageName: "baby.bottle.fill"
        )
        AppShortcut(
            intent: UpdateChowonFeedingTimeIntent(),
            phrases: [
                "\(.applicationName)으로 초원 수유 시간 기록",
                "\(.applicationName)으로 초원 수유"
            ],
            shortTitle: "초원 수유 기록",
            systemImageName: "baby.bottle.fill"
        )
    }
}

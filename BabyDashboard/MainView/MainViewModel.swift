import SwiftUI
import Combine
import CoreData
import Model
import WidgetKit
import CloudKit

// MARK: - MainViewModel (Business Logic)

@MainActor
class MainViewModel: ObservableObject {
    @Published var hour: String = "00"
    @Published var minute: String = "00"
    @Published var showColon: Bool = true
    @Published var date: String = ""

    private let viewContext: NSManagedObjectContext

    private var feedAnimationTimers: [UUID: Timer] = [:]
    private var diaperAnimationTimers: [UUID: Timer] = [:]
    @Published var feedAnimationStates: [UUID: Bool] = [:]
    @Published var diaperAnimationStates: [UUID: Bool] = [:]

    // Use ShareController directly for any share-related actions
    private let shareController: ShareController

    static var shared = MainViewModel(context: PersistenceController.shared.viewContext)

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.shareController = .shared

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateClock()
            }
        })
    }

    private func updateClock() {
        let now = Date.current
        let calendar = Calendar.current
        let second = calendar.component(.second, from: now)
        showColon = second % 2 == 0

        let components = calendar.dateComponents([.hour, .minute], from: now)
        hour = String(format: "%02d", components.hour ?? 0)
        minute = String(format: "%02d", components.minute ?? 0)
        date = now.formatted(Date.FormatStyle(locale: Locale.autoupdatingCurrent).year(.defaultDigits).month(.abbreviated).day(.defaultDigits).weekday(.wide))
    }
    
    // MARK: - Intents
    
    func startFeeding(for baby: BabyProfile) {
        if let ongoing = baby.inProgressFeedSession {
            viewContext.delete(ongoing)
        }
        let newSession = FeedSession(context: viewContext, startTime: Date.current)
        newSession.profile = baby
        saveAndPing()
        triggerAnimation(for: baby.id, type: .feed)
    }
    
    func finishFeeding(for baby: BabyProfile, amount: Measurement<UnitVolume>) {
        guard let session = baby.inProgressFeedSession else { return }
        session.endTime = Date.current
        session.amount = amount

        saveAndPing()
    }
    
    func cancelFeeding(for baby: BabyProfile) {
        guard let session = baby.inProgressFeedSession else { return }
        viewContext.delete(session)
        saveAndPing()
        triggerAnimation(for: baby.id, type: .feed)
    }
    
    func logDiaperChange(for baby: BabyProfile, type: DiaperType) {
        let newDiaper = DiaperChange(context: viewContext, timestamp: Date.current, type: type)
        newDiaper.profile = baby
        saveAndPing()
        triggerAnimation(for: baby.id, type: .diaper)
    }
    
    func setDiaperTime(for baby: BabyProfile, to date: Date) {
        if let lastChange = baby.lastDiaperChange {
            lastChange.timestamp = date
        } else {
            let newDiaper = DiaperChange(context: viewContext, timestamp: date, type: .pee)
            newDiaper.profile = baby
        }
        saveAndPing()
    }
    
    func updateProfileName(for baby: BabyProfile, to newName: String) {
        baby.name = newName
        // Update share title via ShareController
        shareController.updateShareTitleIfNeeded(for: baby, newName: newName)
        _ = shareController.refreshShareInfo(for: baby)
        saveAndPing()
    }
    
    // MARK: - Animation Helpers
    private enum AnimationType { case feed, diaper }
    
    private func triggerAnimation(for babyId: UUID, type: AnimationType) {
        if type == .feed {
            feedAnimationStates[babyId] = true
            feedAnimationTimers[babyId]?.invalidate()
            feedAnimationTimers[babyId] = Timer.scheduledTimer(withTimeInterval: 0.31, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.feedAnimationStates[babyId] = false
                }
            }
        } else {
            diaperAnimationStates[babyId] = true
            diaperAnimationTimers[babyId]?.invalidate()
            diaperAnimationTimers[babyId] = Timer.scheduledTimer(withTimeInterval: 0.31, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.diaperAnimationStates[babyId] = false
                }
            }
        }
    }

    // MARK: - Save + Nudge

    private func saveAndPing() {
        try? viewContext.save()
        NearbySyncManager.shared.sendPing()
        // Update widget cache and reload timelines (using shared helper)
        refreshBabyWidgetSnapshots(using: viewContext)
    }
}


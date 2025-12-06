import Foundation
import CoreData

@objc(BabyProfile)
public class BabyProfile: NSManagedObject {}

@objc(FeedSession)
public class FeedSession: NSManagedObject {}

@objc(DiaperChange)
public class DiaperChange: NSManagedObject {}

@objc(CustomEventType)
public class CustomEventType: NSManagedObject {}

@objc(CustomEvent)
public class CustomEvent: NSManagedObject {}

@objc(DailyChecklist)
public class DailyChecklist: NSManagedObject {}

public protocol Hashtagable {
    var memoText: String? { get }
}

public extension Hashtagable {
    var hashtags: [String] {
        guard let memoText, !memoText.isEmpty else { return [] }
        let pattern = #"(?<!\w)#([\p{L}\p{N}_]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsText = memoText as NSString
        let matches = regex.matches(in: memoText, options: [], range: NSRange(location: 0, length: nsText.length))
        var tags: [String] = matches.map { nsText.substring(with: $0.range(at: 0)) }
        var seen = Set<String>()
        tags = tags.filter { seen.insert($0.lowercased()).inserted }
        return tags
    }
}

extension BabyProfile {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BabyProfile> {
        NSFetchRequest<BabyProfile>(entityName: "BabyProfile")
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var feedTerm: TimeInterval
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var customEventTypes: NSSet?  // For CloudKit sharing
    @NSManaged public var customEvents: NSSet?
    @NSManaged public var diaperChanges: NSSet?
    @NSManaged public var feedSessions: NSSet?
    @NSManaged public var dailyChecklist: NSSet?  // DailyChecklist items
}

extension BabyProfile {
    @objc(addDiaperChangesObject:)
    @NSManaged public func addToDiaperChanges(_ value: DiaperChange)

    @objc(removeDiaperChangesObject:)
    @NSManaged public func removeFromDiaperChanges(_ value: DiaperChange)

    @objc(addDiaperChanges:)
    @NSManaged public func addToDiaperChanges(_ values: NSSet)

    @objc(removeDiaperChanges:)
    @NSManaged public func removeFromDiaperChanges(_ values: NSSet)

    @objc(addFeedSessionsObject:)
    @NSManaged public func addToFeedSessions(_ value: FeedSession)

    @objc(removeFeedSessionsObject:)
    @NSManaged public func removeFromFeedSessions(_ value: FeedSession)

    @objc(addFeedSessions:)
    @NSManaged public func addToFeedSessions(_ values: NSSet)

    @objc(removeFeedSessions:)
    @NSManaged public func removeFromFeedSessions(_ values: NSSet)

    @objc(addCustomEventTypesObject:)
    @NSManaged public func addToCustomEventTypes(_ value: CustomEventType)

    @objc(removeCustomEventTypesObject:)
    @NSManaged public func removeFromCustomEventTypes(_ value: CustomEventType)

    @objc(addCustomEventTypes:)
    @NSManaged public func addToCustomEventTypes(_ values: NSSet)

    @objc(removeCustomEventTypes:)
    @NSManaged public func removeFromCustomEventTypes(_ values: NSSet)

    @objc(addCustomEventsObject:)
    @NSManaged public func addToCustomEvents(_ value: CustomEvent)

    @objc(removeCustomEventsObject:)
    @NSManaged public func removeFromCustomEvents(_ value: CustomEvent)

    @objc(addCustomEvents:)
    @NSManaged public func addToCustomEvents(_ values: NSSet)

    @objc(removeCustomEvents:)
    @NSManaged public func removeFromCustomEvents(_ values: NSSet)

    @objc(addDailyChecklistObject:)
    @NSManaged public func addToDailyChecklist(_ value: DailyChecklist)

    @objc(removeDailyChecklistObject:)
    @NSManaged public func removeFromDailyChecklist(_ value: DailyChecklist)

    @objc(addDailyChecklist:)
    @NSManaged public func addToDailyChecklist(_ values: NSSet)

    @objc(removeDailyChecklist:)
    @NSManaged public func removeFromDailyChecklist(_ values: NSSet)
}

extension BabyProfile: Identifiable {}

extension FeedSession {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FeedSession> {
        NSFetchRequest<FeedSession>(entityName: "FeedSession")
    }

    @NSManaged public var amountUnitSymbol: String?
    @NSManaged public var amountValue: Double
    @NSManaged public var endTime: Date?
    @NSManaged public var memoText: String?
    @NSManaged public var startTime: Date
    @NSManaged public var uuid: UUID
    @NSManaged public var profile: BabyProfile?
}

extension FeedSession: Identifiable, Hashtagable {}

extension DiaperChange {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DiaperChange> {
        NSFetchRequest<DiaperChange>(entityName: "DiaperChange")
    }

    @NSManaged public var timestamp: Date
    @NSManaged public var type: String
    @NSManaged public var uuid: UUID
    @NSManaged public var memoText: String?
    @NSManaged public var profile: BabyProfile?
}

extension DiaperChange: Identifiable, Hashtagable {}

public enum DiaperType: String, Codable {
    case pee
    case poo
}

// MARK: - BabyProfile helpers

public extension BabyProfile {
    /// Convenience creator used by legacy call sites; callers must save the context.
    convenience init(context: NSManagedObjectContext, id: UUID = UUID(), name: String) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.feedTerm = 3 * 3600
        self.createdAt = Date.current
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date.current
        if feedTerm == 0 {
            feedTerm = 3 * 3600
        }
    }

    var feedSessionsArray: [FeedSession] {
        guard let set = feedSessions as? Set<FeedSession> else { return [] }
        return Array(set)
    }



    var customEventsArray: [CustomEvent] {
        guard let set = customEvents as? Set<CustomEvent> else { return [] }
        return Array(set)
    }

    var diaperChangesArray: [DiaperChange] {
        guard let set = diaperChanges as? Set<DiaperChange> else { return [] }
        return Array(set)
    }

    var dailyChecklistArray: [DailyChecklist] {
        guard let set = dailyChecklist as? Set<DailyChecklist> else { return [] }
        return Array(set).sorted { $0.order < $1.order }
    }

    var sessionBeforeCurrentInProgressSession: FeedSession? {
        return feedSessionsArray.filter{ $0.endTime != nil }.sorted(by: { $0.startTime > $1.startTime }).last
    }

    var inProgressFeedSession: FeedSession? {
        feedSessionsArray.first(where: { $0.isInProgress })
    }

    var lastFinishedFeedSession: FeedSession? {
        feedSessionsArray
            .filter { !$0.isInProgress && $0.endTime != nil }
            .sorted(by: { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) })
            .first
    }

    var lastFeedSession: FeedSession? {
        feedSessionsArray
            .sorted(by: { $0.startTime > $1.startTime })
            .first
    }

    var lastDiaperChange: DiaperChange? {
        diaperChangesArray.sorted(by: { $0.timestamp > $1.timestamp }).first
    }

    var lastCustomEvent: CustomEvent? {
        customEventsArray.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
}

// MARK: - FeedSession helpers

public extension FeedSession {
    convenience init(context: NSManagedObjectContext, startTime: Date) {
        self.init(context: context)
        self.startTime = startTime
        self.uuid = UUID()
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        uuid = UUID()
        startTime = Date.current
    }

    var amount: Measurement<UnitVolume>? {
        get {
            guard let unitSymbol = amountUnitSymbol else { return nil }
            guard let unit = canonicalUnit(from: unitSymbol) else {
                return Measurement(value: amountValue, unit: .milliliters)
            }
            return Measurement(value: amountValue, unit: unit)
        }
        set {
            guard let newValue else {
                amountValue = 0
                amountUnitSymbol = nil
                return
            }
            let unit = canonicalUnit(from: newValue.unit.symbol) ?? newValue.unit
            amountValue = newValue.converted(to: unit).value
            amountUnitSymbol = unit.symbol
        }
    }

    var isInProgress: Bool {
        endTime == nil
    }



    private func canonicalUnit(from symbol: String) -> UnitVolume? {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        switch lower {
        case "ml", "milliliter", "milliliters":
            return .milliliters
        case "fl oz", "fl oz", "fl. oz", "fluid ounce", "fluid ounces":
            return .fluidOunces
        case "l", "liter", "liters":
            return .liters
        case "cup", "cups":
            return .cups
        default:
            return nil
        }
    }
}

// MARK: - DiaperChange helpers

public extension DiaperChange {
    convenience init(context: NSManagedObjectContext, timestamp: Date, type: DiaperType) {
        self.init(context: context)
        self.timestamp = timestamp
        self.type = type.rawValue
        self.uuid = UUID()
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        timestamp = Date.current
        type = DiaperType.pee.rawValue
        uuid = UUID()
    }

    var diaperType: DiaperType {
        get { DiaperType(rawValue: type) ?? .pee }
        set { type = newValue.rawValue }
    }

}

// MARK: - CustomEventType helpers

public extension CustomEventType {
    convenience init(context: NSManagedObjectContext, name: String, emoji: String) {
        self.init(context: context)
        self.name = name
        self.emoji = emoji
        self.createdAt = Date.current
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date.current
    }

    var eventsArray: [CustomEvent] {
        guard let set = events as? Set<CustomEvent> else { return [] }
        return Array(set)
    }
}

extension CustomEventType {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CustomEventType> {
        NSFetchRequest<CustomEventType>(entityName: "CustomEventType")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var emoji: String
    @NSManaged public var createdAt: Date
    @NSManaged public var profile: BabyProfile?  // For CloudKit sharing
    @NSManaged public var events: NSSet?
    @NSManaged public var dailyChecklists: NSSet?  // DailyChecklist items using this type
}

extension CustomEventType: Identifiable {}

// MARK: - CustomEvent helpers

public extension CustomEvent {
    convenience init(context: NSManagedObjectContext, timestamp: Date, eventType: CustomEventType) {
        self.init(context: context)
        self.uuid = UUID()
        self.timestamp = timestamp
        self.eventType = eventType
    }
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        uuid = UUID()
        timestamp = Date.current
    }
}

extension CustomEvent {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CustomEvent> {
        NSFetchRequest<CustomEvent>(entityName: "CustomEvent")
    }

    @NSManaged public var uuid: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var memoText: String?
    @NSManaged public var profile: BabyProfile?
    @NSManaged public var eventType: CustomEventType?
}

extension CustomEvent: Identifiable, Hashtagable {}

// MARK: - DailyChecklist

extension DailyChecklist {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyChecklist> {
        NSFetchRequest<DailyChecklist>(entityName: "DailyChecklist")
    }

    @NSManaged public var order: Int16
    @NSManaged public var createdAt: Date
    @NSManaged public var baby: BabyProfile
    @NSManaged public var eventType: CustomEventType
}

public extension DailyChecklist {
    convenience init(context: NSManagedObjectContext, baby: BabyProfile, eventType: CustomEventType, order: Int16) {
        self.init(context: context)
        self.baby = baby
        self.eventType = eventType
        self.order = order
        self.createdAt = Date.current
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        createdAt = Date.current
    }
}

extension DailyChecklist: Identifiable {
    public var id: String {
        "\(baby.id.uuidString)-\(eventType.id.uuidString)"
    }
}

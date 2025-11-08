import Foundation
import CoreData

@objc(BabyProfile)
public class BabyProfile: NSManagedObject {}

@objc(FeedSession)
public class FeedSession: NSManagedObject {}

@objc(DiaperChange)
public class DiaperChange: NSManagedObject {}

extension BabyProfile {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BabyProfile> {
        NSFetchRequest<BabyProfile>(entityName: "BabyProfile")
    }

    @NSManaged public var createdAt: Date
    @NSManaged public var feedTerm: TimeInterval
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var diaperChanges: NSSet?
    @NSManaged public var feedSessions: NSSet?
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

extension FeedSession: Identifiable {}

extension DiaperChange {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DiaperChange> {
        NSFetchRequest<DiaperChange>(entityName: "DiaperChange")
    }

    @NSManaged public var timestamp: Date
    @NSManaged public var type: String
    @NSManaged public var uuid: UUID
    @NSManaged public var profile: BabyProfile?
}

extension DiaperChange: Identifiable {}

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
        self.createdAt = Date()
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        if feedTerm == 0 {
            feedTerm = 3 * 3600
        }
    }

    var feedSessionsArray: [FeedSession] {
        guard let set = feedSessions as? Set<FeedSession> else { return [] }
        return Array(set)
    }

    var diaperChangesArray: [DiaperChange] {
        guard let set = diaperChanges as? Set<DiaperChange> else { return [] }
        return Array(set)
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
        startTime = Date()
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
        timestamp = Date()
        type = DiaperType.pee.rawValue
        uuid = UUID()
    }

    var diaperType: DiaperType {
        get { DiaperType(rawValue: type) ?? .pee }
        set { type = newValue.rawValue }
    }
}

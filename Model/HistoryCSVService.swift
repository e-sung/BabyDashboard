import Foundation
import CoreData
import UniformTypeIdentifiers

#if canImport(SwiftUI)
import SwiftUI

public struct CSVDocument: FileDocument, Identifiable {
    public static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    public static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    public let id = UUID()
    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    public static var empty: CSVDocument { CSVDocument(data: Data()) }
}
#endif

public enum HistoryCSVService {
    static let feedsHeader = [
        "babyName",
        "timestamp",
        "amountValue",
        "amountUnit",
        "feedType"
    ]

    static let diapersHeader = [
        "babyName",
        "timestamp",
        "diaperType"
    ]

    public struct ImportReport: Sendable {
        public var createdBabies: Int = 0
        public var insertedFeeds: Int = 0
        public var updatedFeeds: Int = 0
        public var skippedFeeds: Int = 0
        public var insertedDiapers: Int = 0
        public var skippedDiapers: Int = 0
        public var errors: [String] = []
        public var skippedUnknownBabies: Set<String> = []
    }

    // MARK: Feeds

    public static func encodeFeeds(context: NSManagedObjectContext) throws -> Data {
        try context.performAndWaitThrowing {
            let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(FeedSession.startTime), ascending: false)]
            let feeds = try context.fetch(request)

            var rows: [[String]] = [feedsHeader]
            for session in feeds {
            rows.append([
                session.profile?.name ?? "",
                iso8601String(from: session.startTime),
                session.amount == nil ? "" : String(session.amountValue),
                session.amount?.unit.symbol ?? session.amountUnitSymbol ?? "",
                session.feedType?.rawValue ?? ""
            ])
            }

            return encodeCSV(rows: rows)
        }
    }

    public static func decodeFeedsAndImport(data: Data, context: NSManagedObjectContext) async throws -> ImportReport {
        let rows = try decodeCSV(data: data)
        guard !rows.isEmpty else { return ImportReport() }

        return try context.performAndWaitThrowing {
            var report = ImportReport()

            var startIndex = 0
            if let first = rows.first,
               !first.isEmpty,
               first[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "babyname" {
                startIndex = 1
            }

            let babyFetch: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
            let existingBabies = try context.fetch(babyFetch)
            var babiesByName: [String: BabyProfile] = [:]
            for baby in existingBabies {
                let key = baby.name.lowercased()
                if babiesByName[key] == nil {
                    babiesByName[key] = baby
                }
            }

            let feedFetch: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
            let existingFeeds = try context.fetch(feedFetch)
            struct FeedKey: Hashable { let babyId: UUID?; let start: Date }
            var feedIndex: [FeedKey: FeedSession] = [:]
            for feed in existingFeeds {
                let key = FeedKey(babyId: feed.profile?.id, start: feed.startTime)
                if feedIndex[key] == nil {
                    feedIndex[key] = feed
                }
            }

            for (lineNumber, row) in rows[startIndex...].enumerated() {
                let cols = padded(row, to: feedsHeader.count)
                let babyName = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let timestampStr = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let amountValueStr = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let amountUnitStr = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let feedTypeStr = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)

                var baby: BabyProfile?
                var babyId: UUID?
                if !babyName.isEmpty {
                    let key = babyName.lowercased()
                    if let existing = babiesByName[key] {
                        baby = existing
                        babyId = existing.id
                    } else {
                        report.skippedUnknownBabies.insert(babyName)
                        report.skippedFeeds += 1
                        continue
                    }
                } else {
                    baby = nil
                    babyId = nil
                }

                guard let start = parseISO8601(timestampStr) else {
                    report.errors.append("Line \(lineNumber + startIndex + 1): invalid timestamp '\(timestampStr)'")
                    continue
                }

                let key = FeedKey(babyId: babyId, start: start)
                if let existing = feedIndex[key] {
                    var didUpdate = false
                    if !amountValueStr.isEmpty,
                       existing.amountUnitSymbol == nil,
                       let value = Double(amountValueStr) {
                        existing.amountValue = value
                        existing.amountUnitSymbol = normalizedUnitSymbol(amountUnitStr)
                        didUpdate = true
                    }
                    if didUpdate {
                        report.updatedFeeds += 1
                    } else {
                        report.skippedFeeds += 1
                    }
                } else {
                    let session = FeedSession(context: context, startTime: start)
                    session.endTime = start
                    if let value = Double(amountValueStr) {
                        session.amountValue = value
                        session.amountUnitSymbol = normalizedUnitSymbol(amountUnitStr)
                    }
                    // Parse feedType; default to babyFormula if missing or invalid
                    if let parsedFeedType = FeedType(rawValue: feedTypeStr) {
                        session.feedType = parsedFeedType
                    } else {
                        session.feedType = .babyFormula
                    }
                    session.profile = baby
                    feedIndex[key] = session
                    report.insertedFeeds += 1
                }
            }

            if context.hasChanges {
                try context.save()
            }
            return report
        }
    }

    // MARK: Diapers

    public static func encodeDiapers(context: NSManagedObjectContext) throws -> Data {
        try context.performAndWaitThrowing {
            let request: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: #keyPath(DiaperChange.timestamp), ascending: false)]
            let diapers = try context.fetch(request)

            var rows: [[String]] = [diapersHeader]
            for change in diapers {
                rows.append([
                    change.profile?.name ?? "",
                    iso8601String(from: change.timestamp),
                    change.diaperType.rawValue
                ])
            }

            return encodeCSV(rows: rows)
        }
    }

    public static func decodeDiapersAndImport(data: Data, context: NSManagedObjectContext) async throws -> ImportReport {
        let rows = try decodeCSV(data: data)
        guard !rows.isEmpty else { return ImportReport() }

        return try context.performAndWaitThrowing {
            var report = ImportReport()

            var startIndex = 0
            if let first = rows.first,
               !first.isEmpty,
               first[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "babyname" {
                startIndex = 1
            }

            let babyFetch: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
            let existingBabies = try context.fetch(babyFetch)
            var babiesByName: [String: BabyProfile] = [:]
            for baby in existingBabies {
                let key = baby.name.lowercased()
                if babiesByName[key] == nil {
                    babiesByName[key] = baby
                }
            }

            let diaperFetch: NSFetchRequest<DiaperChange> = DiaperChange.fetchRequest()
            let existingDiapers = try context.fetch(diaperFetch)
            struct DiaperKey: Hashable { let babyId: UUID?; let timestamp: Date; let type: DiaperType }
            var diaperIndex: [DiaperKey: DiaperChange] = [:]
            for change in existingDiapers {
                let key = DiaperKey(babyId: change.profile?.id, timestamp: change.timestamp, type: change.diaperType)
                if diaperIndex[key] == nil {
                    diaperIndex[key] = change
                }
            }

            for (lineNumber, row) in rows[startIndex...].enumerated() {
                let cols = padded(row, to: diapersHeader.count)
                let babyName = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let timestampStr = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let diaperTypeStr = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)

                var baby: BabyProfile?
                var babyId: UUID?
                if !babyName.isEmpty {
                    let key = babyName.lowercased()
                    if let existing = babiesByName[key] {
                        baby = existing
                        babyId = existing.id
                    } else {
                        report.skippedUnknownBabies.insert(babyName)
                        report.skippedDiapers += 1
                        continue
                    }
                } else {
                    baby = nil
                    babyId = nil
                }

                guard let timestamp = parseISO8601(timestampStr) else {
                    report.errors.append("Line \(lineNumber + startIndex + 1): invalid timestamp '\(timestampStr)'")
                    continue
                }

                guard let dtype = DiaperType(rawValue: diaperTypeStr) else {
                    report.errors.append("Line \(lineNumber + startIndex + 1): invalid diaperType '\(diaperTypeStr)'")
                    continue
                }

                let key = DiaperKey(babyId: babyId, timestamp: timestamp, type: dtype)
                if diaperIndex[key] != nil {
                    report.skippedDiapers += 1
                } else {
                    let change = DiaperChange(context: context, timestamp: timestamp, type: dtype)
                    change.profile = baby
                    diaperIndex[key] = change
                    report.insertedDiapers += 1
                }
            }

            if context.hasChanges {
                try context.save()
            }
            return report
        }
    }

    // MARK: Helpers

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func parseISO8601(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: value)
    }

    private static func normalizedUnitSymbol(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        switch lower {
        case "milliliter", "milliliters":
            return UnitVolume.milliliters.symbol
        case "fluid ounce", "fluid ounces", "floz":
            return UnitVolume.fluidOunces.symbol
        case "liter", "liters":
            return UnitVolume.liters.symbol
        case "cup", "cups":
            return UnitVolume.cups.symbol
        default:
            return trimmed
        }
    }

    private static func padded(_ row: [String], to count: Int) -> [String] {
        if row.count >= count { return row }
        return row + Array(repeating: "", count: count - row.count)
    }

    private static func encodeCSV(rows: [[String]]) -> Data {
        var output = ""
        for (index, row) in rows.enumerated() {
            output += row.map { csvEscape($0) }.joined(separator: ",")
            if index < rows.count - 1 { output += "\n" }
        }
        return Data(output.utf8)
    }

    private static func csvEscape(_ field: String) -> String {
        var needsQuotes = false
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            needsQuotes = true
        }
        guard needsQuotes else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func decodeCSV(data: Data) throws -> [[String]] {
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) {
            return parseCSV(text)
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var iterator = text.makeIterator()

        while let ch = iterator.next() {
            if inQuotes {
                if ch == "\"" {
                    if let next = peek(iterator: &iterator) {
                        if next == "\"" {
                            _ = iterator.next()
                            currentField.append("\"")
                        } else {
                            inQuotes = false
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if ch == "\n" || ch == "\r" {
                    if ch == "\r", let next = peek(iterator: &iterator), next == "\n" {
                        _ = iterator.next()
                    }
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(ch)
                }
            }
        }

        if inQuotes || !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        return rows
    }

    private static func peek(iterator: inout String.Iterator) -> Character? {
        var copy = iterator
        return copy.next()
    }
}

private extension NSManagedObjectContext {
    func performAndWaitThrowing<T>(_ block: () throws -> T) throws -> T {
        var outcome: Result<T, Error>?
        performAndWait {
            do {
                outcome = .success(try block())
            } catch {
                outcome = .failure(error)
            }
        }
        guard let outcome else {
            fatalError("performAndWaitThrowing executed without producing a result")
        }
        return try outcome.get()
    }
}

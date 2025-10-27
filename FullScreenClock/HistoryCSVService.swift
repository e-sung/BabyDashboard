import Foundation
import SwiftData
import UniformTypeIdentifiers

#if canImport(SwiftUI)
import SwiftUI

// A small FileDocument wrapper so we can use .fileExporter with CSV data.
struct CSVDocument: FileDocument, Identifiable {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    let id = UUID()
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }

    static var empty: CSVDocument { CSVDocument(data: Data()) }
}
#endif

enum HistoryCSVService {
    // Separate headers per event type (single timestamp column).
    static let feedsHeader = [
        "babyName",     // String (optional; empty => orphan)
        "timestamp",    // ISO8601 (feed uses startTime)
        "amountValue",  // Double string (optional)
        "amountUnit"    // e.g., "ml", "fl oz" (optional)
    ]

    static let diapersHeader = [
        "babyName",     // String (optional; empty => orphan)
        "timestamp",    // ISO8601
        "diaperType"    // "pee" | "poo"
    ]

    struct ImportReport: Sendable {
        var createdBabies: Int = 0
        var insertedFeeds: Int = 0
        var updatedFeeds: Int = 0
        var skippedFeeds: Int = 0
        var insertedDiapers: Int = 0
        var skippedDiapers: Int = 0
        var errors: [String] = []
    }

    // MARK: - Public API (Feeds)

    static func encodeFeeds(modelContext: ModelContext) throws -> Data {
        let feeds: [FeedSession] = (try? modelContext.fetch(FetchDescriptor<FeedSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        ))) ?? []

        var rows: [[String]] = []
        rows.append(feedsHeader)

        for s in feeds {
            rows.append([
                s.profile?.name ?? "",
                iso8601String(from: s.startTime),
                s.amountValue.map { String($0) } ?? "",
                s.amountUnitSymbol ?? ""
            ])
        }

        return encodeCSV(rows: rows)
    }

    static func decodeFeedsAndImport(data: Data, modelContext: ModelContext) async throws -> ImportReport {
        var report = ImportReport()

        let rows = try decodeCSV(data: data)
        guard !rows.isEmpty else { return report }

        // Detect header row (first column == "babyName" or full header match)
        var startIndex = 0
        if let first = rows.first, !first.isEmpty,
           first[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "babyname" {
            startIndex = 1
        }

        // Build baby lookup map by lowercased name (case-insensitive resolve)
        let allBabies: [BabyProfile] = (try? modelContext.fetch(FetchDescriptor<BabyProfile>())) ?? []
        var babiesByLowercasedName: [String: BabyProfile] = [:]
        for b in allBabies where babiesByLowercasedName[b.name.lowercased()] == nil {
            babiesByLowercasedName[b.name.lowercased()] = b
        }

        // Preload existing feeds to deduplicate efficiently in-memory.
        let existingFeeds: [FeedSession] = (try? modelContext.fetch(FetchDescriptor<FeedSession>())) ?? []

        struct FeedKey: Hashable { let babyId: UUID?; let start: Date }
        var feedIndex: [FeedKey: FeedSession] = [:]
        for s in existingFeeds {
            let key = FeedKey(babyId: s.profile?.id, start: s.startTime)
            if feedIndex[key] == nil { feedIndex[key] = s }
        }

        for (lineNumber, row) in rows[startIndex...].enumerated() {
            let cols = padded(row, to: feedsHeader.count)

            let babyName = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let timestampStr = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let amountValueStr = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let amountUnitStr = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)

            // Resolve or create baby by name (case-insensitive)
            let resolvedBaby: BabyProfile?
            let resolvedBabyId: UUID?
            if !babyName.isEmpty {
                let keyName = babyName.lowercased()
                if let existing = babiesByLowercasedName[keyName] {
                    resolvedBaby = existing
                    resolvedBabyId = existing.id
                } else {
                    let newBaby = BabyProfile(id: UUID(), name: babyName)
                    modelContext.insert(newBaby)
                    babiesByLowercasedName[keyName] = newBaby
                    resolvedBaby = newBaby
                    resolvedBabyId = newBaby.id
                    report.createdBabies += 1
                }
            } else {
                resolvedBaby = nil
                resolvedBabyId = nil
            }

            guard let start = parseISO8601(timestampStr) else {
                report.errors.append("Line \(lineNumber + startIndex + 1): invalid timestamp '\(timestampStr)'")
                continue
            }

            let key = FeedKey(babyId: resolvedBabyId, start: start)
            if let existing = feedIndex[key] {
                var didUpdate = false
                if !amountValueStr.isEmpty, existing.amountValue == nil, let val = Double(amountValueStr) {
                    existing.amountValue = val
                    if !amountUnitStr.isEmpty {
                        existing.amountUnitSymbol = normalizedUnitSymbol(amountUnitStr)
                    }
                    didUpdate = true
                }
                if didUpdate {
                    report.updatedFeeds += 1
                } else {
                    report.skippedFeeds += 1
                }
            } else {
                let s = FeedSession(startTime: start)
                // As requested: infer endTime same as startTime
                s.endTime = start
                if let val = Double(amountValueStr) {
                    s.amountValue = val
                    s.amountUnitSymbol = normalizedUnitSymbol(amountUnitStr)
                }
                s.profile = resolvedBaby
                modelContext.insert(s)
                feedIndex[key] = s
                report.insertedFeeds += 1
            }
        }

        try modelContext.save()
        NearbySyncManager.shared.sendPing()
        return report
    }

    // MARK: - Public API (Diapers)

    static func encodeDiapers(modelContext: ModelContext) throws -> Data {
        let diapers: [DiaperChange] = (try? modelContext.fetch(FetchDescriptor<DiaperChange>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        ))) ?? []

        var rows: [[String]] = []
        rows.append(diapersHeader)

        for d in diapers {
            rows.append([
                d.profile?.name ?? "",
                iso8601String(from: d.timestamp),
                d.type.rawValue
            ])
        }

        return encodeCSV(rows: rows)
    }

    static func decodeDiapersAndImport(data: Data, modelContext: ModelContext) async throws -> ImportReport {
        var report = ImportReport()

        let rows = try decodeCSV(data: data)
        guard !rows.isEmpty else { return report }

        // Detect header row (first column == "babyName")
        var startIndex = 0
        if let first = rows.first, !first.isEmpty,
           first[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "babyname" {
            startIndex = 1
        }

        // Build baby lookup map by lowercased name (case-insensitive resolve)
        let allBabies: [BabyProfile] = (try? modelContext.fetch(FetchDescriptor<BabyProfile>())) ?? []
        var babiesByLowercasedName: [String: BabyProfile] = [:]
        for b in allBabies where babiesByLowercasedName[b.name.lowercased()] == nil {
            babiesByLowercasedName[b.name.lowercased()] = b
        }

        // Preload existing diapers to deduplicate efficiently in-memory.
        let existingDiapers: [DiaperChange] = (try? modelContext.fetch(FetchDescriptor<DiaperChange>())) ?? []

        struct DiaperKey: Hashable { let babyId: UUID?; let ts: Date; let type: DiaperType }
        var diaperIndex: [DiaperKey: DiaperChange] = [:]
        for d in existingDiapers {
            let key = DiaperKey(babyId: d.profile?.id, ts: d.timestamp, type: d.type)
            if diaperIndex[key] == nil { diaperIndex[key] = d }
        }

        for (lineNumber, row) in rows[startIndex...].enumerated() {
            let cols = padded(row, to: diapersHeader.count)

            let babyName = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let timestampStr = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let diaperTypeStr = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)

            // Resolve or create baby by name (case-insensitive)
            let resolvedBaby: BabyProfile?
            let resolvedBabyId: UUID?
            if !babyName.isEmpty {
                let keyName = babyName.lowercased()
                if let existing = babiesByLowercasedName[keyName] {
                    resolvedBaby = existing
                    resolvedBabyId = existing.id
                } else {
                    let newBaby = BabyProfile(id: UUID(), name: babyName)
                    modelContext.insert(newBaby)
                    babiesByLowercasedName[keyName] = newBaby
                    resolvedBaby = newBaby
                    resolvedBabyId = newBaby.id
                    report.createdBabies += 1
                }
            } else {
                resolvedBaby = nil
                resolvedBabyId = nil
            }

            guard let ts = parseISO8601(timestampStr) else {
                report.errors.append("Line \(lineNumber + startIndex + 1): invalid timestamp '\(timestampStr)'")
                continue
            }
            guard let dtype = DiaperType(rawValue: diaperTypeStr) else {
                report.errors.append("Line \(lineNumber + startIndex + 1): invalid diaperType '\(diaperTypeStr)'")
                continue
            }

            let key = DiaperKey(babyId: resolvedBabyId, ts: ts, type: dtype)
            if diaperIndex[key] != nil {
                report.skippedDiapers += 1
            } else {
                let d = DiaperChange(timestamp: ts, type: dtype)
                d.profile = resolvedBaby
                modelContext.insert(d)
                diaperIndex[key] = d
                report.insertedDiapers += 1
            }
        }

        try modelContext.save()
        NearbySyncManager.shared.sendPing()
        return report
    }

    // MARK: - Helpers

    private static func iso8601String(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }

    private static func parseISO8601(_ s: String) -> Date? {
        guard !s.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: s)
    }

    private static func normalizedUnitSymbol(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        switch lower {
        case "milliliter", "milliliters": return UnitVolume.milliliters.symbol
        case "fluid ounce", "fluid ounces", "floz": return UnitVolume.fluidOunces.symbol
        case "liter", "liters": return UnitVolume.liters.symbol
        case "cup", "cups": return UnitVolume.cups.symbol
        default: return trimmed // "ml", "fl oz", etc.
        }
    }

    private static func padded(_ row: [String], to count: Int) -> [String] {
        if row.count >= count { return row }
        return row + Array(repeating: "", count: count - row.count)
    }

    // CSV encoding with RFC 4180 style quoting
    private static func encodeCSV(rows: [[String]]) -> Data {
        var out = ""
        for (i, row) in rows.enumerated() {
            out += row.map { csvEscape($0) }.joined(separator: ",")
            if i < rows.count - 1 { out += "\n" }
        }
        return Data(out.utf8)
    }

    private static func csvEscape(_ field: String) -> String {
        var needsQuotes = false
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            needsQuotes = true
        }
        if !needsQuotes { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func decodeCSV(data: Data) throws -> [[String]] {
        guard let text = String(data: data, encoding: .utf8) ??
                         String(data: data, encoding: .utf16) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        return parseCSV(text)
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
        if !inQuotes || !currentField.isEmpty || !currentRow.isEmpty {
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


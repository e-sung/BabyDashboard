// WidgetCache.swift
import Foundation

// Minimal snapshot the widget needs (keep it tiny)
public struct WidgetBabySnapshot: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let totalProgress: Double
    public let feedingProgress: Double
    public let updatedAt: Date

    // New: fields to allow static projection in the widget
    public let feedTerm: TimeInterval
    public let isFeeding: Bool

    public init(
        id: UUID,
        name: String,
        totalProgress: Double,
        feedingProgress: Double,
        updatedAt: Date,
        feedTerm: TimeInterval = 3 * 3600,
        isFeeding: Bool = false
    ) {
        self.id = id
        self.name = name
        self.totalProgress = totalProgress
        self.feedingProgress = feedingProgress
        self.updatedAt = updatedAt
        self.feedTerm = max(1, feedTerm) // guard divide-by-zero
        self.isFeeding = isFeeding
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, totalProgress, feedingProgress, updatedAt, feedTerm, isFeeding
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.totalProgress = try c.decode(Double.self, forKey: .totalProgress)
        self.feedingProgress = try c.decode(Double.self, forKey: .feedingProgress)
        self.updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        // Backward compatibility: default to 3h and false if older cache file
        let decodedFeedTerm = try c.decodeIfPresent(TimeInterval.self, forKey: .feedTerm) ?? (3 * 3600)
        self.feedTerm = max(1, decodedFeedTerm)
        self.isFeeding = try c.decodeIfPresent(Bool.self, forKey: .isFeeding) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(totalProgress, forKey: .totalProgress)
        try c.encode(feedingProgress, forKey: .feedingProgress)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(feedTerm, forKey: .feedTerm)
        try c.encode(isFeeding, forKey: .isFeeding)
    }
}

public enum WidgetCache {
    static let appGroupID = "group.sungdoo.babyDashboard"
    static let directoryName = "WidgetCache"

    private static func baseURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func ensureDirectory() -> URL? {
        guard let dir = baseURL() else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(for id: UUID) -> URL? {
        ensureDirectory()?.appendingPathComponent("\(id.uuidString).json")
    }

    public static func writeSnapshot(_ snapshot: WidgetBabySnapshot) {
        guard let url = fileURL(for: snapshot.id) else {
            assertionFailure("No file url to write widget baby snapshot")
            return
        }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Silently ignore in widget contexts
            assertionFailure(error.localizedDescription)
            print("===")
        }
    }

    public static func readSnapshot(for id: UUID) -> WidgetBabySnapshot? {
        guard let url = fileURL(for: id), let data = try? Data(contentsOf: url) else {
            assertionFailure("Faild to read widget baby snapshot for \(id)")
            return nil
        }
        return try? JSONDecoder().decode(WidgetBabySnapshot.self, from: data)
    }
}


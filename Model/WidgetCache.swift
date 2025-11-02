// WidgetCache.swift
import Foundation

// Minimal snapshot the widget needs (keep it tiny)
public struct WidgetBabySnapshot: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let totalProgress: Double
    public let feedingProgress: Double
    public let updatedAt: Date

    public init(id: UUID, name: String, totalProgress: Double, feedingProgress: Double, updatedAt: Date) {
        self.id = id
        self.name = name
        self.totalProgress = totalProgress
        self.feedingProgress = feedingProgress
        self.updatedAt = updatedAt
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

//
//  DashboardWidget.swift
//  DashboardWidget
//
//  Created by 류성두 on 11/3/25.
//

import WidgetKit
import SwiftUI
import AppIntents
import Model

// MARK: - Provider

struct Provider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date.current,
            configuration: .forPreview(id: UUID(), name: "Baby"),
            snapshot: WidgetBabySnapshot(
                id: UUID(),
                name: "Baby",
                totalProgress: 0.5,
                feedingProgress: 0.2,
                updatedAt: Date.current,
                feedTerm: 3 * 3600,
                isFeeding: false
            )
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let baby = configuration.baby
        guard let baby else {
            return placeholder(in: context)
        }
        let now = Date.current
        let snap = WidgetCache.readSnapshot(for: baby.id) ??
                   WidgetBabySnapshot(
                        id: baby.id,
                        name: baby.name,
                        totalProgress: 0,
                        feedingProgress: 0,
                        updatedAt: now,
                        feedTerm: 3 * 3600,
                        isFeeding: false
                   )
        // For snapshot, return the first projected entry (now)
        let projected = project(snapshot: snap, to: now)
        return SimpleEntry(date: now, configuration: configuration, snapshot: projected)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date.current
        let minute: TimeInterval = 60
        let horizonMinutes = 180

        guard let baby = configuration.baby else {
            return Timeline(entries: [placeholder(in: context)], policy: .atEnd)
        }

        let base = WidgetCache.readSnapshot(for: baby.id) ??
                   WidgetBabySnapshot(
                        id: baby.id,
                        name: baby.name,
                        totalProgress: 0,
                        feedingProgress: 0,
                        updatedAt: now,
                        feedTerm: 3 * 3600,
                        isFeeding: false
                   )

        // Build minute-by-minute entries for the next 3 hours
        var entries: [SimpleEntry] = []
        entries.reserveCapacity(horizonMinutes)

        for m in 0..<horizonMinutes {
            let date = now.addingTimeInterval(TimeInterval(m) * minute)
            let projected = project(snapshot: base, to: date)
            entries.append(SimpleEntry(date: date, configuration: configuration, snapshot: projected))
        }

        // Refresh after the last entry
        let policy: TimelineReloadPolicy = .after(now.addingTimeInterval(TimeInterval(horizonMinutes) * minute))
        return Timeline(entries: entries, policy: policy)
    }

    // Project a snapshot forward to a target date using feedTerm and isFeeding.
    private func project(snapshot: WidgetBabySnapshot, to targetDate: Date) -> WidgetBabySnapshot {
        let dt = max(0, targetDate.timeIntervalSince(snapshot.updatedAt))
        let slope = 1.0 / max(1, snapshot.feedTerm)

        let total = snapshot.totalProgress + dt * slope
        let feeding = snapshot.isFeeding ? total : snapshot.feedingProgress

        return WidgetBabySnapshot(
            id: snapshot.id,
            name: snapshot.name,
            totalProgress: total,
            feedingProgress: feeding,
            updatedAt: targetDate,
            feedTerm: snapshot.feedTerm,
            isFeeding: snapshot.isFeeding
        )
    }
}

// MARK: - Model

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let snapshot: WidgetBabySnapshot
}

// MARK: - Views

struct DashboardWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        switch contextFamily {
        case .accessoryCircular:
            AccessoryCircularView(snapshot: entry.snapshot)
        default:
            VStack {
                Text(entry.snapshot.name)
                    .font(.headline)
                    .lineLimit(1)
                ProgressView(value: min(max(entry.snapshot.totalProgress, 0), 1))
            }
            .padding(8)
        }
    }

    @Environment(\.widgetFamily) private var contextFamily
}

private struct AccessoryCircularView: View {
    let snapshot: WidgetBabySnapshot

    private var clamped: Double { min(max(snapshot.totalProgress, 0), 1) }

    var body: some View {
        Gauge(value: clamped) {
            Text(snapshot.name.prefix(3))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(.blue)
        .widgetLabel(snapshot.name)
        .accessibilityLabel(Text("\(snapshot.name) progress"))
        .accessibilityValue(Text("\(Int(clamped * 100)) percent"))
    }
}

// MARK: - Helper for previews/config construction

extension ConfigurationAppIntent {
    static func forPreview(id: UUID, name: String) -> ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.baby = BabyProfileEntity(id: id, name: name)
        return intent
    }
}

// MARK: - Widget

struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            DashboardWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.accessoryCircular])
        .configurationDisplayName("Baby Progress")
        .description("Shows feeding progress for a selected baby.")
    }
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    DashboardWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: .forPreview(id: UUID(), name: "연두"),
        snapshot: .init(id: UUID(), name: "연두", totalProgress: 0.25, feedingProgress: 0.12, updatedAt: .now, feedTerm: 3*3600, isFeeding: false)
    )
    SimpleEntry(
        date: .now.addingTimeInterval(600),
        configuration: .forPreview(id: UUID(), name: "초원"),
        snapshot: .init(id: UUID(), name: "초원", totalProgress: 0.8, feedingProgress: 0.2, updatedAt: .now, feedTerm: 3*3600, isFeeding: true)
    )
}


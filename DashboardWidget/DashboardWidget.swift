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
            date: Date(),
            configuration: .forPreview(id: UUID(), name: "Baby"),
            snapshot: WidgetBabySnapshot(id: UUID(), name: "Baby", totalProgress: 0.5, feedingProgress: 0.2, updatedAt: Date())
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let baby = configuration.baby
        guard let baby else {
            return placeholder(in: context)
        }
        let snap = WidgetCache.readSnapshot(for: baby.id) ??
                   WidgetBabySnapshot(id: baby.id, name: baby.name, totalProgress: 0, feedingProgress: 0, updatedAt: Date())
        return SimpleEntry(date: Date(), configuration: configuration, snapshot: snap)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let now = Date()
        let baby = configuration.baby
        guard let baby else {
            return Timeline(entries: [placeholder(in: context)], policy: .atEnd)
        }
        let snap = WidgetCache.readSnapshot(for: baby.id) ??
                   WidgetBabySnapshot(id: baby.id, name: baby.name, totalProgress: 0, feedingProgress: 0, updatedAt: now)

        let entry = SimpleEntry(date: now, configuration: configuration, snapshot: snap)
        let refresh = Calendar.current.date(byAdding: .minute, value: 10, to: now) ?? now.addingTimeInterval(600)
        return Timeline(entries: [entry], policy: .after(refresh))
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
        snapshot: .init(id: UUID(), name: "연두", totalProgress: 0.25, feedingProgress: 0.12, updatedAt: .now)
    )
    SimpleEntry(
        date: .now.addingTimeInterval(600),
        configuration: .forPreview(id: UUID(), name: "초원"),
        snapshot: .init(id: UUID(), name: "초원", totalProgress: 0.8, feedingProgress: 0.2, updatedAt: .now)
    )
}



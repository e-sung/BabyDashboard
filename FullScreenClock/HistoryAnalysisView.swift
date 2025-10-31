import SwiftUI
import SwiftData
import Model
import Charts

struct HistoryAnalysisView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings

    // Segmented presets for analysis range
    enum RangePreset: Int, CaseIterable, Identifiable {
        case days30 = 30
        case days90 = 90
        case days180 = 180

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .days30: return String(localized: "30 Days")
            case .days90: return String(localized: "90 Days")
            case .days180: return String(localized: "180 Days")
            }
        }

        // Compute a DateInterval ending today (end-exclusive: start of tomorrow)
        func intervalEndingToday(calendar: Calendar = .current) -> DateInterval {
            let endExclusive = calendar.startOfDay(for: Date()).addingTimeInterval(24*60*60)
            let startInclusive = calendar.date(byAdding: .day, value: -(rawValue - 1), to: endExclusive) ?? Date()
            return DateInterval(start: startInclusive, end: endExclusive)
        }
    }

    // Chart mode: daily totals vs per feed (non-aggregated)
    enum ChartMode: String, CaseIterable, Identifiable {
        case daily
        case perFeed

        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: return String(localized: "Daily")
            case .perFeed: return String(localized: "Per Feed")
            }
        }
    }

    // Selected preset (default to 30 days)
    @State private var selectedPreset: RangePreset = .days30
    @State private var mode: ChartMode = .daily

    @State private var availableBabies: [BabyProfile] = []
    @State private var selectedBabyID: UUID? = nil

    // Data
    @State private var feedPoints: [DailyFeedPoint] = []
    @State private var perFeedPoints: [FeedSessionPoint] = []

    // Axis labels cache (avoid formatting inside AxisValueLabel closure)
    @State private var yAxisFormatter: (Double) -> String = { value in String(format: "%.0f", value) }

    private var targetUnit: UnitVolume {
        (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
    }

    var body: some View {
        VStack {
            controls

            Chart {
                switch mode {
                case .daily:
                    ForEach(feedPoints, id: \.id) { point in
                        feedMark(for: point)
                    }
                case .perFeed:
                    ForEach(perFeedPoints, id: \.id) { point in
                        perFeedMark(for: point)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    if let d = value.as(Double.self) {
                        AxisValueLabel(yAxisFormatter(d))
                    }
                }
            }
            .chartLegend(position: .automatic)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                let isEmpty = (mode == .daily) ? feedPoints.isEmpty : perFeedPoints.isEmpty
                if isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Adjust the range or filters.")
                    )
                }
            }
        }
        .navigationTitle("Analysis")
        .task {
            await refreshData()
            loadAvailableBabies()
        }
        .onChange(of: selectedPreset) { _, _ in Task { await refreshData() } }
        .onChange(of: selectedBabyID) { _, _ in Task { await refreshData() } }
        .onChange(of: mode) { _, _ in
            // No fetch required; we already build both datasets in refreshData.
        }
    }

    // Split mark creation to tiny helpers to keep type checking simple.
    private func feedMark(for point: DailyFeedPoint) -> some ChartContent {
        LineMark(
            x: .value("Day", point.day),
            y: .value("Feed", point.feedValue),
            series: .value("Baby", point.babyName)
        )
        .foregroundStyle(by: .value("Baby", point.babyName))
        .interpolationMethod(.catmullRom)
        .symbol(Circle())
        .symbolSize(60)
    }

    private func perFeedMark(for point: FeedSessionPoint) -> some ChartContent {
        LineMark(
            x: .value("Time", point.timestamp),
            y: .value("Feed", point.feedValue),
            series: .value("Baby", point.babyName)
        )
        .foregroundStyle(by: .value("Baby", point.babyName))
        .interpolationMethod(.catmullRom)
        .symbol(Circle())
        .symbolSize(50)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 8) {
            // Segmented range picker
            Picker("Range", selection: $selectedPreset) {
                ForEach(RangePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Mode + Baby filters
            HStack {
                Picker("Mode", selection: $mode) {
                    ForEach(ChartMode.allCases) { m in
                        Text(m.title).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Baby", selection: Binding<UUID?>(
                    get: { selectedBabyID },
                    set: { selectedBabyID = $0 }
                )) {
                    Text("All").tag(UUID?.none)
                    ForEach(availableBabies, id: \.id) { baby in
                        Text(baby.name).tag(UUID?.some(baby.id))
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    // MARK: - Data fetching / aggregation

    @MainActor
    private func refreshData() async {
        let calendar = Calendar.current

        // Determine interval from preset (end-exclusive)
        let interval = selectedPreset.intervalEndingToday(calendar: calendar)

        let feedPredicate: Predicate<FeedSession> = #Predicate { session in
            session.startTime >= interval.start && session.startTime < interval.end
        }

        let feedDescriptor = FetchDescriptor<FeedSession>(
            predicate: feedPredicate,
            sortBy: [SortDescriptor(\FeedSession.startTime, order: .forward)]
        )

        let feeds = (try? modelContext.fetch(feedDescriptor)) ?? []

        let filteredFeeds: [FeedSession] = {
            guard let selectedBabyID else { return feeds }
            return feeds.filter { $0.profile?.id == selectedBabyID }
        }()

        // Daily totals (omit current logical day to avoid partial day)
        let feedPts = aggregateForChart(
            feeds: filteredFeeds,
            unit: targetUnit,
            calendar: calendar,
            startOfDayHour: settings.startOfDayHour,
            startOfDayMinute: settings.startOfDayMinute
        )
        self.feedPoints = feedPts

        // Per-feed (include current logical day so latest finished sessions appear)
        let sessionPts = makePerSessionPoints(
            feeds: filteredFeeds,
            unit: targetUnit,
            calendar: calendar,
            startOfDayHour: settings.startOfDayHour,
            startOfDayMinute: settings.startOfDayMinute,
            omitLogicalToday: false
        )
        self.perFeedPoints = sessionPts

        rebuildYAxisFormatter()
    }

    private func rebuildYAxisFormatter() {
        let unit = targetUnit
        yAxisFormatter = { value in
            let m = Measurement(value: value, unit: unit)
            return m.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
        }
    }

    private func loadAvailableBabies() {
        let descriptor = FetchDescriptor<BabyProfile>(
            sortBy: [SortDescriptor(\BabyProfile.name, order: .forward)]
        )
        if let babies = try? modelContext.fetch(descriptor) {
            availableBabies = babies
            if let selected = selectedBabyID, babies.first(where: { $0.id == selected }) == nil {
                selectedBabyID = nil
            }
        }
    }
}


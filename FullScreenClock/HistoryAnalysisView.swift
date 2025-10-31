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

    // Selected preset (default to 30 days)
    @State private var selectedPreset: RangePreset = .days30

    @State private var availableBabies: [BabyProfile] = []
    @State private var selectedBabyID: UUID? = nil

    // Data
    @State private var feedPoints: [DailyFeedPoint] = []

    // Axis labels cache (avoid formatting inside AxisValueLabel closure)
    @State private var yAxisFormatter: (Double) -> String = { value in String(format: "%.0f", value) }

    private var targetUnit: UnitVolume {
        (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
    }

    var body: some View {
        VStack {
            controls

            Chart {
                ForEach(feedPoints, id: \.id) { point in
                    feedMark(for: point)
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
                if feedPoints.isEmpty {
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

            HStack {
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

        let feedPts = aggregateForChart(
            feeds: filteredFeeds,
            unit: targetUnit,
            calendar: calendar,
            startOfDayHour: settings.startOfDayHour,
            startOfDayMinute: settings.startOfDayMinute
        )

        self.feedPoints = feedPts

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

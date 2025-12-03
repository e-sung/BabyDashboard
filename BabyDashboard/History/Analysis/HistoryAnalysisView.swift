import SwiftUI
import CoreData
import Model
import Charts

struct HistoryAnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: AppSettings

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

        func intervalEndingToday(calendar: Calendar = .current) -> DateInterval {
            let endExclusive = calendar.startOfDay(for: Date.current).addingTimeInterval(24 * 60 * 60)
            let startInclusive = calendar.date(byAdding: .day, value: -(rawValue - 1), to: endExclusive) ?? Date.current
            return DateInterval(start: startInclusive, end: endExclusive)
        }
    }

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

    @State private var selectedPreset: RangePreset = .days30
    @State private var mode: ChartMode = .daily

    @State private var availableBabies: [BabyProfile] = []
    @State private var selectedBabyID: UUID? = nil

    @State private var feedPoints: [DailyFeedPoint] = []
    @State private var perFeedPoints: [FeedSessionPoint] = []
    @State private var yAxisFormatter: (Double) -> String = { value in String(format: "%.0f", value) }

    @State private var selectedPointForMemo: FeedSessionPoint? = nil
    @State private var selectedMemoText: String = ""

    private var targetUnit: UnitVolume {
        UnitUtils.preferredUnit
    }

    var body: some View {
        VStack {
            controls
            chartView
        }
        .navigationTitle("Analysis")
        .task {
            loadAvailableBabies()
            await refreshData()
        }
        .onChange(of: selectedPreset) { _, _ in Task { await refreshData() } }
        .onChange(of: selectedBabyID) { _, _ in Task { await refreshData() } }
    }

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

    @ViewBuilder
    private var chartView: some View {
        switch mode {
        case .daily:
            dailyChart
        case .perFeed:
            perFeedChart
        }
    }

    private var dailyChart: some View {
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

    private var perFeedChart: some View {
        Chart {
            ForEach(perFeedPoints, id: \.id) { point in
                perFeedMark(for: point)
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
            if perFeedPoints.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Adjust the range or filters.")
                )
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let plotFrame = proxy.plotAreaFrame
                        let origin = geo[plotFrame].origin
                        let pointInPlot = CGPoint(x: location.x - origin.x, y: location.y - origin.y)

                        if let date: Date = proxy.value(atX: pointInPlot.x, as: Date.self) {
                            let yDouble: Double? = proxy.value(atY: pointInPlot.y, as: Double.self)
                            if let nearest = nearestPoint(to: date, y: yDouble) {
                                Task { await presentMemo(for: nearest) }
                            }
                        }
                    }
            }
        }
        .popover(item: $selectedPointForMemo) { point in
            VStack(alignment: .leading, spacing: 8) {
                Text(point.babyName)
                    .font(.headline)
                Text(point.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                Divider()
                if selectedMemoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(String(localized: "No memo"))
                        .foregroundColor(.secondary)
                } else {
                    Text(selectedMemoText)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .frame(minWidth: 240)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Range", selection: $selectedPreset) {
                ForEach(RangePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack {
                Picker("Mode", selection: $mode) {
                    ForEach(ChartMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Baby", selection: Binding<UUID?>(
                    get: { selectedBabyID },
                    set: { selectedBabyID = $0 }
                )) {
                    Text("All").tag(UUID?.none)
                    ForEach(availableBabies.map { ( $0.id, $0.name ) }, id: \.0) { id, name in
                        Text(name).tag(UUID?.some(id))
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    @MainActor
    private func refreshData() async {
        let calendar = Calendar.current
        let interval = selectedPreset.intervalEndingToday(calendar: calendar)

        let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
        var predicates: [NSPredicate] = []

        predicates.append(
            NSPredicate(
                format: "startTime >= %@ AND startTime < %@",
                argumentArray: [interval.start as NSDate, interval.end as NSDate]
            )
        )
        if let selectedBabyID {
            predicates.append(NSPredicate(format: "profile.id == %@", argumentArray: [selectedBabyID as CVarArg]))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]

        let feeds: [FeedSession] = (try? viewContext.fetch(request)) ?? []

        let feedPts = aggregateForChart(
            feeds: feeds,
            unit: targetUnit,
            calendar: calendar,
            startOfDayHour: settings.startOfDayHour,
            startOfDayMinute: settings.startOfDayMinute
        )
        feedPoints = feedPts

        let sessionPts = makePerSessionPoints(
            feeds: feeds,
            unit: targetUnit,
            calendar: calendar,
            startOfDayHour: settings.startOfDayHour,
            startOfDayMinute: settings.startOfDayMinute,
            omitLogicalToday: false
        )
        perFeedPoints = sessionPts

        rebuildYAxisFormatter()
    }

    private func rebuildYAxisFormatter() {
        let unit = targetUnit
        yAxisFormatter = { value in
            let measurement = Measurement(value: value, unit: unit)
            return measurement.formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(UnitUtils.baseFractionLength))))
        }
    }

    private func loadAvailableBabies() {
        let request: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        availableBabies = (try? viewContext.fetch(request)) ?? []
        if let selected = selectedBabyID,
           availableBabies.first(where: { $0.id == selected }) == nil {
            selectedBabyID = nil
        }
    }

    private func nearestPoint(to date: Date, y: Double?) -> FeedSessionPoint? {
        guard !perFeedPoints.isEmpty else { return nil }
        var best: (FeedSessionPoint, Double)?
        for point in perFeedPoints {
            let dx = abs(point.timestamp.timeIntervalSince(date))
            let dy = y.map { abs(point.feedValue - $0) } ?? 0
            let score = (dx / 60.0) + dy
            if best == nil || score < (best?.1 ?? .infinity) {
                best = (point, score)
            }
        }
        return best?.0
    }

    @MainActor
    private func presentMemo(for point: FeedSessionPoint) async {
        let memo = (try? viewContext.existingObject(with: point.objectID) as? FeedSession)?.memoText ?? ""
        selectedMemoText = memo
        selectedPointForMemo = point
    }
}

import SwiftUI
import CoreData
import Model
import Charts
import StoreKit

struct TrendView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var settings: AppSettings
    @Environment(\.requestReview) private var requestReview

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

    @State private var selectedPreset: RangePreset = .days30

    @State private var availableBabies: [BabyProfile] = []
    @State private var selectedBabyID: UUID? = nil

    @State private var feedPoints: [DailyFeedPoint] = []
    @State private var yAxisFormatter: (Double) -> String = { value in String(format: "%.0f", value) }

    private var targetUnit: UnitVolume {
        UnitUtils.preferredUnit
    }

    var body: some View {
        VStack {
            controls
            dailyChart
        }
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



    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Menu {
                    ForEach(RangePreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            if selectedPreset == preset {
                                Label(preset.title, systemImage: "checkmark")
                            } else {
                                Text(preset.title)
                            }
                        }
                    }
                } label: {
                    Label(selectedPreset.title, systemImage: "calendar")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                }
                
                Spacer()
                
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


}

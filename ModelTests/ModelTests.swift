//
//  ModelTests.swift
//  ModelTests
//
//  Created by 류성두 on 10/28/25.
//

import CoreData
import Testing
import XCTest
@testable import Model

// MARK: - FeedType Tests

struct FeedTypeTests {
    
    @Test func feedTypeEmoji() {
        #expect(FeedType.babyFormula.emoji == "🍼")
        #expect(FeedType.breastFeed.emoji == "🤱")
        #expect(FeedType.solid.emoji == "🍲")
    }
    
    @Test func feedTypeRawValue() {
        #expect(FeedType.babyFormula.rawValue == "babyFormula")
        #expect(FeedType.breastFeed.rawValue == "breastFeed")
        #expect(FeedType.solid.rawValue == "solid")
    }
    
    @Test func feedTypeCodable() throws {
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(FeedType.breastFeed)
        let jsonString = String(data: data, encoding: .utf8)
        #expect(jsonString == "\"breastFeed\"")
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FeedType.self, from: data)
        #expect(decoded == .breastFeed)
    }
    
    @Test func feedTypeFromRawValue() {
        #expect(FeedType(rawValue: "babyFormula") == .babyFormula)
        #expect(FeedType(rawValue: "breastFeed") == .breastFeed)
        #expect(FeedType(rawValue: "solid") == .solid)
        #expect(FeedType(rawValue: "invalid") == nil)
    }
}

// MARK: - HistoryCSVService Tests

struct HistoryCSVServiceTest {

    let 수유이력csv = """
    babyName,timestamp,amountValue,amountUnit
    초원,2025-11-06T18:34:39.946Z,80.0,mL
    연두,2025-11-06T18:16:34.224Z,100.0,mL
    연두,2025-11-06T15:29:18.554Z,140.0,mL
    초원,2025-11-06T15:03:33.717Z,110.0,mL
    연두,2025-11-06T10:18:51.272Z,125.0,mL
    초원,2025-11-06T10:03:58.241Z,100.0,mL
    초원,2025-11-06T07:40:47.962Z,120.0,mL
    연두,2025-11-06T07:20:20.352Z,150.0,mL
    초원,2025-11-06T04:26:55.740Z,100.0,mL
    연두,2025-11-06T04:06:58.244Z,130.0,mL
    초원,2025-11-06T00:52:24.052Z,130.0,mL
    연두,2025-11-06T00:40:00.000Z,170.0,mL
    초원,2025-11-05T21:53:32.182Z,80.0,mL
    연두,2025-11-05T21:17:11.146Z,100.0,mL
    초원,2025-11-05T18:47:40.160Z,100.0,mL
    연두,2025-11-05T18:12:07.598Z,100.0,mL
    초원,2025-11-05T15:58:35.137Z,90.0,mL
    연두,2025-11-05T14:55:39.507Z,140.0,mL
    초원,2025-11-05T08:41:22.863Z,130.0,mL
    연두,2025-11-05T08:34:54.185Z,170.0,mL
    연두,2025-11-05T05:24:41.373Z,130.0,mL
    초원,2025-11-05T05:23:13.808Z,105.0,mL
    연두,2025-11-05T02:25:29.398Z,130.0,mL
    초원,2025-11-05T02:04:08.935Z,110.0,mL
    연두,2025-11-04T23:12:16.187Z,140.0,mL
    초원,2025-11-04T22:39:53.390Z,120.0,mL
    연두,2025-11-04T19:53:25.090Z,60.0,mL
    초원,2025-11-04T19:26:35.214Z,90.0,mL
    연두,2025-11-04T16:25:36.503Z,140.0,mL
    초원,2025-11-04T15:45:02.980Z,110.0,mL
    연두,2025-11-04T10:29:59.721Z,140.0,mL
    초원,2025-11-04T10:11:04.988Z,140.0,mL
    연두,2025-11-04T07:29:51.011Z,160.0,mL
    초원,2025-11-04T07:08:52.400Z,90.0,mL
    초원,2025-11-04T03:58:23.605Z,120.0,mL
    연두,2025-11-04T03:40:49.562Z,170.0,mL
    초원,2025-11-04T00:56:25.238Z,100.0,mL
    연두,2025-11-04T00:15:47.111Z,170.0,mL
    초원,2025-11-03T21:59:52.583Z,90.0,mL
    연두,2025-11-03T21:40:31.899Z,100.0,mL
    초원,2025-11-03T19:08:19.125Z,60.0,mL
    연두,2025-11-03T18:34:55.402Z,90.0,mL
    초원,2025-11-03T16:01:23.726Z,125.0,mL
    연두,2025-11-03T15:08:11.585Z,140.0,mL
    연두,2025-11-03T09:44:38.246Z,130.0,mL
    초원,2025-11-03T09:31:24.010Z,140.0,mL
    초원,2025-11-03T07:02:31.090Z,85.0,mL
    연두,2025-11-03T06:59:16.749Z,160.0,mL
    초원,2025-11-03T03:37:58.995Z,110.0,mL
    연두,2025-11-03T03:19:22.377Z,170.0,mL
    초원,2025-11-03T00:27:38.997Z,85.0,mL
    연두,2025-11-03T00:03:14.254Z,120.0,mL
    초원,2025-11-02T21:35:28.771Z,60.0,mL
    연두,2025-11-02T21:10:07.624Z,100.0,mL
    초원,2025-11-02T18:36:18.953Z,100.0,mL
    연두,2025-11-02T18:15:13.040Z,100.0,mL
    초원,2025-11-02T14:55:51.777Z,100.0,mL
    연두,2025-11-02T14:29:49.902Z,140.0,mL
    초원,2025-11-02T09:49:43.919Z,120.0,mL
    연두,2025-11-02T08:26:14.917Z,165.0,mL
    초원,2025-11-02T06:58:56.080Z,140.0,mL
    연두,2025-11-02T05:25:18.162Z,160.0,mL
    초원,2025-11-02T03:48:29.982Z,105.0,mL
    연두,2025-11-02T02:09:44.357Z,140.0,mL
    초원,2025-11-02T00:12:24.469Z,90.0,mL
    연두,2025-11-01T22:58:29.125Z,120.0,mL
    초원,2025-11-01T20:46:13.073Z,60.0,mL
    연두,2025-11-01T19:42:05.345Z,90.0,mL
    초원,2025-11-01T17:46:20.574Z,80.0,mL
    연두,2025-11-01T15:45:04.931Z,140.0,mL
    초원,2025-11-01T14:21:13.094Z,100.0,mL
    초원,2025-11-01T09:37:11.662Z,100.0,mL
    연두,2025-11-01T09:19:03.492Z,150.0,mL
    초원,2025-11-01T06:46:58.924Z,135.0,mL
    연두,2025-11-01T05:56:00.892Z,170.0,mL
    초원,2025-11-01T03:16:30.054Z,140.0,mL
    연두,2025-11-01T03:00:26.856Z,110.0,mL
    초원,2025-11-01T00:14:16.594Z,70.0,mL
    연두,2025-10-31T23:41:36.807Z,170.0,mL
    초원,2025-10-31T21:21:53.839Z,100.0,mL
    연두,2025-10-31T20:22:41.958Z,140.0,mL
    초원,2025-10-31T17:30:23.878Z,70.0,mL
    연두,2025-10-31T16:16:26.679Z,140.0,mL
    초원,2025-10-31T14:18:00.000Z,80.0,mL
    초원,2025-10-31T10:07:48.851Z,100.0,mL
    연두,2025-10-31T09:06:17.651Z,180.0,mL
    초원,2025-10-31T07:42:33.262Z,110.0,mL
    연두,2025-10-31T05:21:11.298Z,170.0,mL
    초원,2025-10-31T04:44:42.098Z,110.0,mL
    연두,2025-10-31T02:00:35.618Z,130.0,mL
    초원,2025-10-31T01:40:21.196Z,140.0,mL
    연두,2025-10-30T23:13:32.629Z,90.0,mL
    초원,2025-10-30T22:42:15.576Z,70.0,mL
    연두,2025-10-30T19:40:25.979Z,130.0,mL
    초원,2025-10-30T19:25:37.589Z,80.0,mL
    초원,2025-10-30T16:18:37.953Z,70.0,mL
    연두,2025-10-30T16:18:28.522Z,140.0,mL
    초원,2025-10-30T13:12:22.073Z,140.0,mL
    연두,2025-10-30T09:46:42.480Z,170.0,mL
    초원,2025-10-30T09:30:35.155Z,140.0,mL
    초원,2025-10-30T06:24:35.945Z,90.0,mL
    연두,2025-10-30T06:24:02.781Z,170.0,mL
    초원,2025-10-30T03:03:40.104Z,105.0,mL
    연두,2025-10-30T02:40:00.000Z,170.0,mL
    초원,2025-10-29T23:45:19.631Z,120.0,mL
    연두,2025-10-29T23:40:11.538Z,110.0,mL
    초원,2025-10-29T20:21:36.001Z,80.0,mL
    연두,2025-10-29T20:06:29.742Z,140.0,mL
    초원,2025-10-29T17:00:36.576Z,90.0,mL
    연두,2025-10-29T16:36:03.630Z,100.0,mL
    초원,2025-10-29T13:08:14.566Z,90.0,mL
    연두,2025-10-29T08:17:41.379Z,150.0,mL
    초원,2025-10-29T07:51:17.262Z,100.0,mL
    연두,2025-10-29T05:18:12.933Z,160.0,mL
    초원,2025-10-29T04:50:32.177Z,70.0,mL
    초원,2025-10-29T01:54:40.947Z,120.0,mL
    연두,2025-10-29T01:34:19.024Z,165.0,mL
    초원,2025-10-28T22:47:36.622Z,80.0,mL
    연두,2025-10-28T22:32:56.652Z,110.0,mL
    초원,2025-10-28T19:26:29.158Z,80.0,mL
    연두,2025-10-28T18:51:28.397Z,100.0,mL
    초원,2025-10-28T16:32:44.002Z,100.0,mL
    연두,2025-10-28T16:10:30.168Z,100.0,mL
    초원,2025-10-28T08:57:48.294Z,100.0,mL
    연두,2025-10-28T08:56:50.898Z,130.0,mL
    초원,2025-10-28T06:02:33.422Z,100.0,mL
    연두,2025-10-28T05:32:47.299Z,160.0,mL
    초원,2025-10-28T02:40:36.229Z,110.0,mL
    연두,2025-10-28T01:44:07.003Z,170.0,mL
    초원,2025-10-27T22:58:11.576Z,60.0,mL
    연두,2025-10-27T22:26:33.319Z,140.0,mL
    초원,2025-10-27T19:44:06.193Z,100.0,mL
    연두,2025-10-27T19:10:38.082Z,75.0,mL
    초원,2025-10-27T16:10:46.995Z,80.0,mL
    연두,2025-10-27T15:44:19.058Z,100.0,mL
    연두,2025-10-27T09:06:17.093Z,170.0,mL
    초원,2025-10-27T08:56:02.390Z,110.0,mL
    연두,2025-10-27T05:49:32.873Z,160.0,mL
    초원,2025-10-27T05:42:36.363Z,110.0,mL
    초원,2025-10-27T02:03:00.000Z,100.0,mL
    연두,2025-10-27T01:30:00.000Z,120.0,mL
    초원,2025-10-26T23:10:00.000Z,100.0,mL
    연두,2025-10-26T22:25:00.000Z,110.0,mL
    초원,2025-10-26T19:20:00.000Z,90.0,mL
    연두,2025-10-26T18:01:00.000Z,100.0,mL
    연두,2025-10-26T15:26:00.000Z,100.0,mL
    초원,2025-10-26T15:00:00.000Z,90.0,mL
    산호,2025-10-26T12:00:00.000Z,90.0,mL
    """

    @Test func importDocument() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = await controller.viewContext

        let data = try #require(수유이력csv.data(using: .utf8))

        let allowedBabyNames: Set<String> = ["연두", "초원"]

        var setupError: Error?
        context.performAndWait {
            do {
                _ = BabyProfile(context: context, name: "연두")
                _ = BabyProfile(context: context, name: "초원")
                try context.save()
            } catch {
                setupError = error
            }
        }
        if let setupError {
            throw setupError
        }

        let rows = 수유이력csv
            .split(whereSeparator: \.isNewline)
            .dropFirst()

        let expectedFeedCount = rows.reduce(into: 0) { count, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let components = trimmed.split(separator: ",", omittingEmptySubsequences: false)
            guard let rawName = components.first else { return }
            let name = rawName.trimmingCharacters(in: .whitespaces)
            if allowedBabyNames.contains(name) {
                count += 1
            }
        }

        let expectedSkippedNames: Set<String> = rows.reduce(into: Set<String>()) { set, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            let components = trimmed.split(separator: ",", omittingEmptySubsequences: false)
            guard let rawName = components.first else { return }
            let name = rawName.trimmingCharacters(in: .whitespaces)
            if !allowedBabyNames.contains(name) {
                set.insert(name)
            }
        }

        let report = try await HistoryCSVService.decodeFeedsAndImport(data: data, context: context)

        #expect(report.errors.isEmpty)
        #expect(report.createdBabies == 0)
        #expect(report.insertedFeeds == expectedFeedCount)
        #expect(report.updatedFeeds == 0)
        #expect(report.skippedFeeds == expectedSkippedNames.count)
        #expect(report.skippedUnknownBabies == expectedSkippedNames)

        let feedFetch: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
        let babyFetch: NSFetchRequest<BabyProfile> = BabyProfile.fetchRequest()

        var feedCount = 0
        var babyNames = Set<String>()
        var fetchError: Error?

        context.performAndWait {
            do {
                let feeds = try context.fetch(feedFetch)
                feedCount = feeds.count
                let babies = try context.fetch(babyFetch)
                babyNames = Set(babies.compactMap { $0.name })
            } catch {
                fetchError = error
            }
        }

        if let fetchError {
            throw fetchError
        }

        #expect(feedCount == expectedFeedCount)
        #expect(babyNames == allowedBabyNames)
        
        // Verify that imported feeds default to babyFormula feedType
        context.performAndWait {
            let request: NSFetchRequest<FeedSession> = FeedSession.fetchRequest()
            if let feeds = try? context.fetch(request) {
                for feed in feeds {
                    // All feeds should have feedType set to babyFormula since CSV didn't have feedType column
                    assert(feed.feedType == .babyFormula, "Feed should have babyFormula as default feedType")
                }
            }
        }
    }
}

// MARK: - Performance Stress Tests (XCTest with measure blocks)

/// Performance stress test for HistoryCSVService using XCTest measure blocks.
/// Results will be visible in Xcode's test result bundle with baseline comparisons.
final class HistoryCSVServicePerformanceTests: XCTestCase {
    
    // Shared test data
    private var feedsCSVData: Data!
    private var diapersCSVData: Data!
    private var exportController: PersistenceController!
    
    // Configuration: 3 years, 2 babies, 6 feeds/day, 10 diapers/day
    private let babyNames = ["BabyA", "BabyB"]
    private let daysCount = 365 * 3  // 3 years
    private let feedsPerDayPerBaby = 6
    private let diapersPerDayPerBaby = 10
    
    var expectedFeedsTotal: Int {
        babyNames.count * daysCount * feedsPerDayPerBaby  // 2 * 1095 * 6 = 13,140
    }
    
    var expectedDiapersTotal: Int {
        babyNames.count * daysCount * diapersPerDayPerBaby  // 2 * 1095 * 10 = 21,900
    }
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Generate test data once for all performance tests
        exportController = PersistenceController(inMemory: true)
        let context = await exportController.viewContext
        
        try await context.perform {
            // Create baby profiles
            var babies: [String: BabyProfile] = [:]
            for name in self.babyNames {
                let baby = BabyProfile(context: context, name: name)
                babies[name] = baby
            }
            
            let calendar = Calendar.current
            let now = Date()
            let feedTypes: [FeedType] = [.babyFormula, .breastFeed, .solid]
            let diaperTypes: [DiaperType] = [.pee, .poo]
            
            // Generate feeds: 6 per day per baby
            for dayOffset in 0..<self.daysCount {
                let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
                
                for (_, baby) in babies {
                    for feedIndex in 0..<self.feedsPerDayPerBaby {
                        let hourOffset = feedIndex * 4
                        let feedTime = calendar.date(byAdding: .hour, value: hourOffset, to: calendar.startOfDay(for: dayStart))!
                        
                        let session = FeedSession(context: context, startTime: feedTime)
                        session.endTime = feedTime.addingTimeInterval(900)
                        session.amountValue = Double.random(in: 60...180)
                        session.amountUnitSymbol = "mL"
                        session.feedType = feedTypes[feedIndex % feedTypes.count]
                        session.profile = baby
                    }
                }
                
                // Generate diapers: 10 per day per baby
                for (_, baby) in babies {
                    for diaperIndex in 0..<self.diapersPerDayPerBaby {
                        let minuteOffset = diaperIndex * 144
                        let diaperTime = calendar.date(byAdding: .minute, value: minuteOffset, to: calendar.startOfDay(for: dayStart))!
                        
                        let diaper = DiaperChange(context: context, timestamp: diaperTime, type: diaperTypes[diaperIndex % diaperTypes.count])
                        diaper.profile = baby
                    }
                }
            }
            
            try context.save()
        }
        
        // Pre-export data for import tests
        feedsCSVData = try HistoryCSVService.encodeFeeds(context: await exportController.viewContext)
        diapersCSVData = try HistoryCSVService.encodeDiapers(context: await exportController.viewContext)
    }
    
    override func tearDown() async throws {
        feedsCSVData = nil
        diapersCSVData = nil
        exportController = nil
        try await super.tearDown()
    }
    
    /// Measures feed CSV export performance for 3 years of data (13,140 records)
    func testExportFeedsPerformance() async throws {
        let context = await exportController.viewContext
        
        measure {
            _ = try? HistoryCSVService.encodeFeeds(context: context)
        }
    }
    
    /// Measures diaper CSV export performance for 3 years of data (21,900 records)
    func testExportDiapersPerformance() async throws {
        let context = await exportController.viewContext
        
        measure {
            _ = try? HistoryCSVService.encodeDiapers(context: context)
        }
    }
    
    /// Measures feed CSV import performance for 3 years of data (13,140 records)
    func testImportFeedsPerformance() async throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 3  // Fewer iterations since import is slow
        
        measure(options: options) {
            let importController = PersistenceController(inMemory: true)
            
            let exp = expectation(description: "Import feeds")
            
            Task {
                let importContext = await importController.viewContext
                
                // Set up baby profiles
                await importContext.perform {
                    for name in self.babyNames {
                        _ = BabyProfile(context: importContext, name: name)
                    }
                    try? importContext.save()
                }
                
                // Import feeds
                let report = try? await HistoryCSVService.decodeFeedsAndImport(
                    data: self.feedsCSVData,
                    context: importContext
                )
                
                XCTAssertEqual(report?.insertedFeeds, self.expectedFeedsTotal)
                exp.fulfill()
            }
            
            wait(for: [exp], timeout: 120)
        }
    }
    
    /// Measures diaper CSV import performance for 3 years of data (21,900 records)
    func testImportDiapersPerformance() async throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        
        measure(options: options) {
            let importController = PersistenceController(inMemory: true)
            
            let exp = expectation(description: "Import diapers")
            
            Task {
                let importContext = await importController.viewContext
                
                // Set up baby profiles
                await importContext.perform {
                    for name in self.babyNames {
                        _ = BabyProfile(context: importContext, name: name)
                    }
                    try? importContext.save()
                }
                
                // Import diapers
                let report = try? await HistoryCSVService.decodeDiapersAndImport(
                    data: self.diapersCSVData,
                    context: importContext
                )
                
                XCTAssertEqual(report?.insertedDiapers, self.expectedDiapersTotal)
                exp.fulfill()
            }
            
            wait(for: [exp], timeout: 120)
        }
    }
}

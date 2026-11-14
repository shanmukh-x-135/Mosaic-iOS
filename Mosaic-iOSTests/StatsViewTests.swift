import XCTest
@testable import Mosaic_iOS

final class StatsViewTests: XCTestCase {
    func testPeriodsAreUniqueDescendingWithAllTimeFirst() {
        XCTAssertEqual(StatsCopy.periods([2024, 2026, 2025, 2026]), ["all", "2026", "2025", "2024"])
        XCTAssertEqual(StatsCopy.periods([]), ["all"])
        XCTAssertEqual(StatsCopy.periodTitle("all"), "All time")
        XCTAssertEqual(StatsCopy.periodTitle("2026"), "2026")
        XCTAssertEqual(StatsCopy.periodLabel(.init(kind: .all, year: nil)), "so far")
        XCTAssertEqual(StatsCopy.periodLabel(.init(kind: .year, year: 2026)), "in 2026")
    }

    func testPopulationNotesMatchWeb() {
        XCTAssertEqual(StatsCopy.populationNote(.all, period: .init(kind: .all, year: nil)), "every title you have rated")
        XCTAssertEqual(StatsCopy.populationNote(.loggedInPeriod, period: .init(kind: .year, year: 2026)), "rated films and series you logged in 2026")
    }

    func testQuietCopyAndUnits() {
        XCTAssertEqual(StatsCopy.quiet(unit: "film watches", period: .init(kind: .all, year: nil)), "No film watches recorded so far.")
        XCTAssertEqual(StatsCopy.quiet(unit: "episodes logged", period: .init(kind: .year, year: 2025)), "No episodes logged recorded in 2025.")
        XCTAssertEqual(StatsCopy.unit(1, medium: .movie), "film watch")
        XCTAssertEqual(StatsCopy.unit(2, medium: .movie), "film watches")
        XCTAssertEqual(StatsCopy.unit(1, medium: .tv), "episode logged")
        XCTAssertEqual(StatsCopy.unit(2, medium: .game), "playthroughs completed")
        XCTAssertEqual(StatsCopy.unit(0, medium: .book), "books finished")
    }

    func testAverageIsOptionalAndAlwaysOneDecimal() {
        XCTAssertNil(StatsCopy.average(nil))
        XCTAssertNil(StatsCopy.average(.nan))
        XCTAssertEqual(StatsCopy.average(4), "★ 4.0")
        XCTAssertEqual(StatsCopy.average(4.26), "★ 4.3")
    }

    func testWeekdaysAreSundayFirstAndPreserveUTCCounts() {
        XCTAssertEqual(StatsCopy.weekdayLabels, ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        XCTAssertEqual(StatsCopy.weekdays([7, 6, 5, 4, 3, 2, 1]).map(\.count), [7, 6, 5, 4, 3, 2, 1])
        XCTAssertEqual(StatsCopy.weekdays([]).map(\.count), Array(repeating: 0, count: 7))
    }

    @MainActor func testFixtureJSONDecodesForAllTimeAndYear() async throws {
        for period in ["all", "2026", "2025"] {
            let response = try await MosaicVisualFixtures.services(state: "loaded").profileStats(period)
            XCTAssertEqual(response.years, [2026, 2025])
            XCTAssertEqual(response.stats.period.year, Int(period))
            XCTAssertEqual(response.stats.ratings.population, period == "all" ? .all : .loggedInPeriod)
            XCTAssertEqual(response.stats.ratings.distribution.map(\.value), UserRating.options)
            XCTAssertFalse(response.stats.movie.recent.isEmpty)
            XCTAssertGreaterThan(response.stats.book.statuses.wantToRead, 0)
            XCTAssertFalse(StatsCopy.isEmpty(response.stats))
            XCTAssertEqual(response.stats.activity.movie.buckets.reduce(0) { $0 + $1.count }, response.stats.movie.watchLogs)
        }
        let empty = try await MosaicVisualFixtures.services(state: "empty").profileStats("all")
        XCTAssertTrue(StatsCopy.isEmpty(empty.stats))
        XCTAssertNil(StatsCopy.average(empty.stats.ratings.average))
    }
}

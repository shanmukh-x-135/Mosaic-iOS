import Combine
import XCTest
@testable import Mosaic_iOS

@MainActor
final class PersonalStateStoreTests: XCTestCase {
    func testDecodesFullStateAndSkipsMalformedRows() throws {
        let snapshot = try decodedState()
        let movie = try XCTUnwrap(snapshot.movieWatches.first?.media)
        XCTAssertEqual(snapshot.watchRegion, "IN")
        XCTAssertEqual(snapshot.library.count, 1)
        XCTAssertTrue(snapshot.library[0].isFavorite)
        XCTAssertEqual(snapshot.library[0].updatedAt, "2026-10-11T20:00:00.000Z")
        XCTAssertEqual(snapshot.ratings.first?.value, 4)
        XCTAssertEqual(snapshot.reviews.count, 2)
        XCTAssertEqual(snapshot.reviews(for: movie)?.id, "review-new")
        XCTAssertEqual(snapshot.reviews(for: movie)?.body, "Latest review")
        XCTAssertEqual(snapshot.reviews(for: movie)?.rating, 4.5)
        XCTAssertEqual(snapshot.movieWatches(for: movie).map(\.id), ["watch-new", "watch-old"])
        XCTAssertTrue(snapshot.movieWatches[1].isRewatch)
        XCTAssertEqual(snapshot.movieWatches[1].rating, 4.5)
        XCTAssertEqual(snapshot.movieWatches[1].review, "Still great")
        XCTAssertEqual(snapshot.movieWatches[1].viewingContext, "future-context")
        XCTAssertEqual(snapshot.movieWatches[1].streamingService, "MUBI")
        XCTAssertEqual(snapshot.episodeWatches.first?.id, "episode-1")
        XCTAssertEqual(snapshot.episodeWatches.first?.seasonNumber, 2)
        XCTAssertEqual(snapshot.episodeWatches.first?.episodeNumber, 3)
        XCTAssertEqual(snapshot.episodeWatches.first?.episodeTitle, "Episode three")
        XCTAssertEqual(snapshot.episodeWatches.first?.rating, 4)
        XCTAssertEqual(snapshot.episodeWatches.first?.isRewatch, true)
        XCTAssertEqual(snapshot.list(id: "list-1")?.orderedItems.first?.id, "item-1")
        XCTAssertEqual(snapshot.seasonStates.first?.provenance, "bulk_season")
        XCTAssertEqual(snapshot.seasonStates.first?.completedOn, "2026-10-11")
        XCTAssertEqual(snapshot.tvHistory.first?.targetType, "season")
        XCTAssertEqual(snapshot.tvHistory.first?.tags, ["weekend"])
        XCTAssertEqual(snapshot.gamePlaythroughs.count, 1)
        XCTAssertEqual(snapshot.bookReadings.count, 1)
    }

    func testApplyReplacesSnapshot() throws {
        let store = PersonalStateStore()
        store.seed(try decodedState())
        store.apply(MosaicStateSnapshot(watchRegion: "US"))
        XCTAssertEqual(store.snapshot?.watchRegion, "US")
        XCTAssertTrue(store.snapshot?.reviews.isEmpty == true)
        XCTAssertTrue(store.snapshot?.movieWatches.isEmpty == true)
    }

    func testLoadIsLazyAndIdempotent() async throws {
        var calls = 0
        var resume: CheckedContinuation<MosaicStateSnapshot, Error>?
        var services = MosaicServices.unavailable
        services.stateSnapshot = {
            calls += 1
            return try await withCheckedThrowingContinuation { resume = $0 }
        }
        let store = PersonalStateStore()
        XCTAssertEqual(calls, 0)
        store.load(services)
        store.load(services)
        await waitUntil { resume != nil }
        XCTAssertEqual(calls, 1)
        resume?.resume(returning: MosaicStateSnapshot(watchRegion: "IN"))
        await waitUntil { store.snapshot != nil }
        store.load(services)
        XCTAssertEqual(calls, 1)
    }

    func testFailedRefreshKeepsLastSnapshotAndFirstFailureIsFailed() async throws {
        var calls = 0
        var services = MosaicServices.unavailable
        services.stateSnapshot = { calls += 1; throw TestError.offline }
        let store = PersonalStateStore()
        store.seed(try decodedState())
        store.refresh(services)
        await waitUntil { calls == 1 }
        // A subsequent load remains a no-op because the last good state survives.
        store.load(services)
        XCTAssertEqual(store.snapshot?.watchRegion, "IN")
        XCTAssertEqual(store.snapshot?.reviews.count, 2)
        XCTAssertEqual(calls, 1)
        let empty = PersonalStateStore()
        empty.load(services)
        await waitUntil { if case .failed = empty.state { true } else { false } }
        XCTAssertNil(empty.snapshot)
    }

    func testMutationNotificationAppliesWithoutFetchingState() async throws {
        var calls = 0
        var services = MosaicServices.unavailable
        services.stateSnapshot = { calls += 1; return MosaicStateSnapshot() }
        let store = PersonalStateStore()
        let subscription = NotificationCenter.default.publisher(for: .mosaicStateDidChange).sink { notification in
            MainActor.assumeIsolated { store.handleStateChange(notification, services: services) }
        }
        defer { subscription.cancel() }
        MosaicStateInvalidation.post(snapshot: try decodedState())
        XCTAssertEqual(store.snapshot?.reviews.count, 2)
        XCTAssertEqual(store.snapshot?.watchRegion, "IN")
        await Task.yield()
        XCTAssertEqual(calls, 0)
    }

    func testLegacyNotificationOnlyRefreshesLoadedStore() async {
        var calls = 0
        var services = MosaicServices.unavailable
        services.stateSnapshot = { calls += 1; return MosaicStateSnapshot(watchRegion: "US") }
        let store = PersonalStateStore()
        let notification = Notification(name: .mosaicStateDidChange)
        XCTAssertNil(notification.mosaicStateSnapshot)
        store.handleStateChange(notification, services: services)
        await Task.yield()
        XCTAssertEqual(calls, 0)
        store.seed(MosaicStateSnapshot())
        store.handleStateChange(notification, services: services)
        await waitUntil { store.snapshot?.watchRegion == "US" }
        XCTAssertEqual(calls, 1)
    }

    func testMutationSnapshotWinsOverInFlightLoad() async {
        var resume: CheckedContinuation<MosaicStateSnapshot, Never>?
        var services = MosaicServices.unavailable
        services.stateSnapshot = { await withCheckedContinuation { resume = $0 } }
        let store = PersonalStateStore()
        store.load(services)
        await waitUntil { resume != nil }
        store.apply(MosaicStateSnapshot(watchRegion: "US"))
        resume?.resume(returning: MosaicStateSnapshot(watchRegion: "IN"))
        // Drain the resumed task; cancellation must prevent stale data being applied.
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(store.snapshot?.watchRegion, "US")
    }

    func testRecommendationsKeepExistingFixtureSeeds() {
        let snapshot = MosaicVisualFixtures.snapshot
        XCTAssertEqual(Recommendations.seeds(from: snapshot, type: nil).map(\.mediaKey),
                       [MosaicVisualFixtures.succession.mediaKey, MosaicVisualFixtures.digger.mediaKey])
        XCTAssertEqual(Recommendations.seeds(from: snapshot, type: .movie).map(\.mediaKey), [MosaicVisualFixtures.digger.mediaKey])
        XCTAssertTrue(Recommendations.seeds(from: snapshot, type: .book).isEmpty)
    }

    private enum TestError: Error { case offline }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<1_000 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Store did not settle", file: file, line: line)
    }

    private func decodedState() throws -> MosaicStateSnapshot {
        let movie = #"{"provider":"tmdb","providerId":"1","mediaType":"movie","title":"Arrival","genres":[]}"#
        let series = #"{"provider":"tmdb","providerId":"2","mediaType":"tv","title":"Series","genres":[]}"#
        let game = #"{"provider":"igdb","providerId":"3","mediaType":"game","title":"Game","genres":[]}"#
        let book = #"{"provider":"googlebooks","providerId":"4","mediaType":"book","title":"Book","genres":[]}"#
        return try JSONDecoder.mosaic.decode(MosaicStateSnapshot.self, from: Data("""
        {
          "watchRegion":"IN",
          "library":[{"media":\(movie),"status":"watched","isFavorite":true,"updatedAt":"2026-10-11T20:00:00.000Z"}],
          "ratings":[{"mediaKey":"tmdb:movie:1","value":4,"updatedAt":"2026-10-11T20:00:00.000Z"}],
          "reviews":[
            {"id":"review-old","media":\(movie),"body":"Earlier review","containsSpoilers":false,"updatedAt":"2026-09-01T00:00:00.000Z"},
            {"id":"bad-review","media":\(movie),"body":42,"containsSpoilers":false,"updatedAt":"2026-10-12T00:00:00.000Z"},
            {"id":"review-new","media":\(movie),"body":"Latest review","containsSpoilers":true,"rating":4.5,"updatedAt":"2026-10-11T20:00:00.000Z"}
          ],
          "lists":[{"id":"list-1","title":"Picks","description":"My picks","visibility":"private","updatedAt":"2026-10-11T20:00:00.000Z","items":[{"id":"item-1","media":\(movie),"position":0,"note":"Watch again"}]}],
          "movieWatches":[
            {"id":"watch-old","media":\(movie),"watchedAt":"2026-09-01","isRewatch":false},
            {"id":"watch-new","media":\(movie),"watchedAt":"2026-10-11","isRewatch":true,"rating":4.5,"review":"Still great","viewingContext":"future-context","streamingService":"MUBI"}
          ],
          "episodeWatches":[{"id":"episode-1","series":\(series),"seasonNumber":2,"episodeNumber":3,"episodeTitle":"Episode three","watchedAt":"2026-10-12T20:00:00.000Z","rating":4,"isRewatch":true}],
          "seasonStates":[{"id":"season-1","series":\(series),"seasonNumber":1,"state":"completed","provenance":"bulk_season","completedOn":"2026-10-11","updatedAt":"2026-10-11T20:00:00.000Z"}],
          "seriesStates":[{"id":"series-1","series":\(series),"facts":{"watching":true},"updatedAt":"2026-10-11T20:00:00.000Z"}],
          "tvHistory":[{"id":"tv-1","series":\(series),"targetType":"season","seasonNumber":1,"occurredAt":"2026-10-11T20:00:00.000Z","isRewatch":false,"rating":4,"review":"Good season","containsSpoilers":false,"tags":["weekend"]}],
          "gamePlaythroughs":[{"id":"game-1","media":\(game),"status":"playing","platform":"PC","playtimeMinutes":245,"progressPercent":32,"rating":4,"updatedAt":"2026-10-10T20:00:00.000Z"}],
          "bookReadings":[{"id":"book-1","media":\(book),"status":"reading","currentPage":96,"totalPages":304,"progressPercent":32,"rating":4,"updatedAt":"2026-10-09T09:00:00.000Z"}]
        }
        """.utf8))
    }
}

import XCTest
@testable import Mosaic_iOS

final class ActivityProjectionTests: XCTestCase {
    private func snapshot(_ fields: String) throws -> MosaicStateSnapshot {
        try JSONDecoder().decode(MosaicStateSnapshot.self, from: Data("{\(fields)}".utf8))
    }

    private func media(_ type: String) -> String {
        """
        {"provider":"mock","providerId":"\(type)","mediaType":"\(type)","title":"\(type)","genres":[]}
        """
    }

    // Golden: web "activity projection is chronological, domain-aware, and contains no fabricated events".
    func testChronologicalDomainProjection() throws {
        let state = try snapshot("""
        "movieWatches":[{"id":"movie-watch","media":\(media("movie")),"watchedAt":"2026-01-01","isRewatch":false,"rating":4.5}],
        "episodeWatches":[{"id":"episode-watch","series":\(media("tv")),"seasonNumber":2,"episodeNumber":4,"episodeTitle":"Consequence","watchedAt":"2026-01-04T12:00:00.000Z","rating":3.5}],
        "gamePlaythroughs":[{"id":"game-playthrough","media":\(media("game")),"status":"playing","platform":"PC","playtimeMinutes":180,"progressPercent":25,"updatedAt":"2026-01-03T12:00:00.000Z"}],
        "bookReadings":[{"id":"book-reading","media":\(media("book")),"status":"reading","currentPage":100,"totalPages":400,"progressPercent":25,"updatedAt":"2026-01-02T12:00:00.000Z"}]
        """)
        let events = ActivityProjection.project(state)
        XCTAssertEqual(events.map(\.eventType), ["episode_watch", "game_update", "book_update", "movie_watch"])
        XCTAssertEqual(events.map(\.eventID), ["episode-watch:episode-watch", "game-playthrough:game-playthrough", "book-reading:book-reading", "movie-watch:movie-watch"])
        XCTAssertEqual(events.map(\.targetType), ["episode", "playthrough", "reading", "media"])
        XCTAssertEqual(events.map(\.detail), [nil, "PC", "100 / 400 pages", nil])
        XCTAssertEqual(events.map(\.progressPercent), [nil, 25, 25, nil])
        XCTAssertTrue(events.allSatisfy { $0.repeatKind == nil })
        XCTAssertEqual(events[0].episode, .init(seasonNumber: 2, episodeNumber: 4, title: "Consequence"))
        XCTAssertEqual(events[0].rating, 3.5)
        XCTAssertEqual(events[3].rating, 4.5)
        XCTAssertEqual(events[3].occurredAt, Date(timeIntervalSince1970: 1_767_225_600))
        XCTAssertEqual(events.map(\.label), ["Watched S02E04", "Updated playthrough", "Updated reading", "Watched"])

        for medium in ActivityProjection.Medium.allCases {
            let filtered = ActivityProjection.filtered(events, medium: medium)
            XCTAssertEqual(filtered.count, medium == .all ? 4 : 1)
            if let type = medium.mediaType { XCTAssertTrue(filtered.allSatisfy { $0.media.mediaType == type }) }
            XCTAssertEqual(ActivityProjection.filtered(events, medium: medium, diary: true).map(\.eventID), ["movie-watch:movie-watch"])
        }
    }

    // Golden: historical watches stay separate from current library/rating state.
    func testCurrentStateDoesNotFabricateOrCollapseMovieEvents() throws {
        let state = try snapshot("""
        "library":[{"media":\(media("movie")),"status":"watched","isFavorite":true,"updatedAt":"2026-01-02T00:00:00.000Z"}],
        "ratings":[{"mediaKey":"mock:movie:movie","value":4.5}],
        "movieWatches":[
        {"id":"one","media":\(media("movie")),"watchedAt":"2026-01-01","isRewatch":false},
        {"id":"two","media":\(media("movie")),"watchedAt":"2026-01-02","isRewatch":true}]
        """)
        let events = ActivityProjection.project(state)
        XCTAssertEqual(events.map(\.eventID), ["movie-watch:two", "movie-watch:one"])
        XCTAssertEqual(events.map(\.repeatKind), ["rewatch", nil])
        XCTAssertTrue(events.allSatisfy { $0.rating == nil })
    }

    // Golden: imported completed seasons never invent episode logs.
    func testEpisodeRewatchesAndImportedSeasonStateStayDistinct() throws {
        let state = try snapshot("""
        "episodeWatches":[
        {"id":"first","series":\(media("tv")),"seasonNumber":1,"episodeNumber":1,"watchedAt":"2026-01-04T00:00:00.000Z"},
        {"id":"rewatch","series":\(media("tv")),"seasonNumber":1,"episodeNumber":1,"watchedAt":"2026-01-05T00:00:00.000Z","isRewatch":true}],
        "seasonStates":[{"id":"import","series":\(media("tv")),"seasonNumber":2,"state":"completed","provenance":"imported_state","updatedAt":"2026-01-03T00:00:00.000Z"}]
        """)
        let events = ActivityProjection.project(state)
        XCTAssertEqual(events.map(\.eventID), ["episode-watch:rewatch", "episode-watch:first"])
        XCTAssertEqual(events.map(\.repeatKind), ["rewatch", nil])
        XCTAssertEqual(events.map(\.label), ["Rewatched S01E01", "Watched S01E01"])
    }

    func testSameDayRepeatFirstThenDescendingID() throws {
        let state = try snapshot("""
        "movieWatches":[
        {"id":"z-original","media":\(media("movie")),"watchedAt":"2026-01-01","isRewatch":false},
        {"id":"a-repeat","media":\(media("movie")),"watchedAt":"2026-01-01","isRewatch":true},
        {"id":"b-repeat","media":\(media("movie")),"watchedAt":"2026-01-01","isRewatch":true},
        {"id":"newer","media":\(media("movie")),"watchedAt":"2026-01-02","isRewatch":false}]
        """)
        XCTAssertEqual(ActivityProjection.project(state).map(\.eventID), ["movie-watch:newer", "movie-watch:b-repeat", "movie-watch:a-repeat", "movie-watch:z-original"])
    }

    func testTVTargetsDetailsAndCompletionRepeatRules() throws {
        let state = try snapshot("""
        "movieWatches":[{"id":"context","media":\(media("movie")),"watchedAt":"2026-01-01","isRewatch":false,"viewingContext":"streaming","streamingService":"MUBI","review":"A review"}],
        "tvHistory":[
        {"id":"season","series":\(media("tv")),"targetType":"season","seasonNumber":2,"occurredAt":"2026-01-02T00:00:00Z","isRewatch":true,"rating":4,"containsSpoilers":false,"tags":[]},
        {"id":"series","series":\(media("tv")),"targetType":"series","occurredAt":"2026-01-03T00:00:00Z","isRewatch":false,"containsSpoilers":false,"tags":[]}],
        "gamePlaythroughs":[{"id":"done","media":\(media("game")),"status":"completed","playtimeMinutes":120,"progressPercent":100,"updatedAt":"2026-01-04T00:00:00Z"}],
        "bookReadings":[{"id":"done","media":\(media("book")),"status":"finished","totalPages":400,"progressPercent":100,"updatedAt":"2026-01-05T00:00:00Z"}]
        """)
        let events = ActivityProjection.project(state)
        XCTAssertEqual(events.map(\.eventID), ["book-reading:done", "game-playthrough:done", "tv-history:series", "tv-history:season", "movie-watch:context"])
        XCTAssertEqual(events.map(\.repeatKind), ["reread", "replay", nil, "rewatch", nil])
        XCTAssertEqual(events.map(\.label), ["Finished reading", "Completed playthrough", "Watched series", "Rewatched season 2", "Watched"])
        XCTAssertEqual(events.map(\.detail), ["0 / 400 pages", nil, nil, nil, "streaming · MUBI"])
        XCTAssertEqual(events[3].seasonNumber, 2)
        XCTAssertEqual(events[3].rating, 4)
        XCTAssertEqual(events[2].targetType, "media")
        XCTAssertEqual(events[3].targetType, "season")
        XCTAssertEqual(ActivityProjection.filtered(events, medium: .series).count, 2)
        XCTAssertEqual(ActivityProjection.filtered(events, medium: .all, diary: true).map(\.eventID), ["movie-watch:context"])
    }

    func testMissingDetailsAndNoHistoryCap() throws {
        let state = try snapshot("""
        "movieWatches":[{"id":"blank","media":\(media("movie")),"watchedAt":"2026-01-01","isRewatch":false,"viewingContext":"","streamingService":""}],
        "bookReadings":[{"id":"zero","media":\(media("book")),"status":"reading","totalPages":0,"updatedAt":"2026-01-01T00:00:00Z"}]
        """)
        XCTAssertTrue(ActivityProjection.project(state).allSatisfy { $0.detail == nil })
        let watch = try XCTUnwrap(state.movieWatches.first)
        let watches = (0..<250).map { index in
            var item = watch
            item.id = String(index)
            return item
        }
        let events = ActivityProjection.project(MosaicStateSnapshot(movieWatches: watches))
        XCTAssertEqual(events.count, 250)
        XCTAssertEqual(Set(events.map(\.eventID)).count, 250)
        XCTAssertEqual(ActivityProjection.filtered(events, medium: .all, diary: true).count, 250)
        XCTAssertTrue(ActivityProjection.project(MosaicStateSnapshot()).isEmpty)
        XCTAssertTrue(ActivityProjection.filtered(events, medium: .series).isEmpty)
    }
}

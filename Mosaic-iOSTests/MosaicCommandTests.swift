import XCTest
@testable import Mosaic_iOS

@MainActor
final class MosaicCommandTests: XCTestCase {
    private let id = "11111111-1111-4111-8111-111111111111"
    private let itemID = "22222222-2222-4222-8222-222222222222"
    private let date = Date(timeIntervalSince1970: 1_800_360_000) // 2027-01-19T12:00:00Z

    func testWatchRegionGoldenJSON() throws {
        try assertJSON(.watchRegion("IN"), ["type": "settings.watchRegion", "value": "IN"])
        try assertJSON(.watchRegion(nil), ["type": "settings.watchRegion", "value": NSNull()])
    }

    func testRatingGoldenJSON() throws {
        try assertJSON(.rating(media(), 4.5), ["type": "rating.set", "media": identity(), "value": 4.5])
    }

    func testLibraryGoldenJSON() throws {
        try assertJSON(.library(media(), status: "watched", isFavorite: false), ["type": "library.upsert", "media": identity(), "status": "watched", "isFavorite": false])
    }

    func testRemoveLibraryGoldenJSON() throws {
        try assertJSON(.removeLibrary(media()), ["type": "library.remove", "media": identity()])
    }

    func testReviewSaveGoldenJSON() throws {
        try assertJSON(.reviewSave(id: id, media: media(), body: "A great film.", containsSpoilers: true, rating: 4), ["type": "review.save", "id": id, "media": identity(), "body": "A great film.", "containsSpoilers": true, "rating": 4])
    }

    func testReviewDeleteGoldenJSON() throws {
        try assertJSON(.reviewDelete(id: id), ["type": "review.delete", "id": id])
    }

    func testListCreateGoldenJSON() throws {
        try assertJSON(.listCreate(title: "Picks", description: "", visibility: .private), ["type": "list.create", "title": "Picks", "description": "", "visibility": "private"])
    }

    func testListAddGoldenJSON() throws {
        try assertJSON(.listAdd(listID: id, media: media(), note: "Start here"), ["type": "list.add", "listId": id, "media": identity(), "note": "Start here"])
    }

    func testListUpdateGoldenJSON() throws {
        try assertJSON(.listUpdate(listID: id, title: "Favorites", description: "My picks", visibility: .unlisted), ["type": "list.update", "listId": id, "title": "Favorites", "description": "My picks", "visibility": "unlisted"])
    }

    func testListItemUpdateGoldenJSON() throws {
        try assertJSON(.listItemUpdate(listID: id, itemID: itemID, note: ""), ["type": "list.item.update", "listId": id, "itemId": itemID, "note": ""])
    }

    func testListItemRemoveGoldenJSON() throws {
        try assertJSON(.listItemRemove(listID: id, itemID: itemID), ["type": "list.item.remove", "listId": id, "itemId": itemID])
    }

    func testListReorderGoldenJSON() throws {
        try assertJSON(.listReorder(listID: id, itemIDs: [itemID, id]), ["type": "list.reorder", "listId": id, "itemIds": [itemID, id]])
    }

    func testMovieLogGoldenJSON() throws {
        try assertJSON(.movieLog(media(), watchedAt: date, isRewatch: true, rating: 4.5, review: "Again!", viewingContext: .streaming, streamingService: "  MUBI\n"), ["type": "movie.log", "media": identity(), "watchedAt": calendarDay, "isRewatch": true, "rating": 4.5, "review": "Again!", "viewingContext": "streaming", "streamingService": "MUBI"])
    }

    func testMovieUpdateGoldenJSON() throws {
        try assertJSON(.movieUpdate(watchID: id, media: media(), watchedAt: date, isRewatch: false, rating: 5, review: "Updated", viewingContext: .physical), ["type": "movie.update", "watchId": id, "media": identity(), "watchedAt": calendarDay, "isRewatch": false, "rating": 5, "review": "Updated", "viewingContext": "physical"])
    }

    func testMovieDeleteGoldenJSON() throws {
        try assertJSON(.movieDelete(watchID: id), ["type": "movie.delete", "watchId": id])
    }

    func testEpisodeLogGoldenJSON() throws {
        try assertJSON(.episodeLog(media(.tv), season: 0, episode: 2, watchedAt: date, rating: 3.5, episodeTitle: "Special"), ["type": "episode.log", "series": identity(.tv), "seasonNumber": 0, "episodeNumber": 2, "watchedAt": "2027-01-19T12:00:00Z", "rating": 3.5, "episodeTitle": "Special"])
    }

    func testEpisodeUnwatchGoldenJSON() throws {
        try assertJSON(.episodeUnwatch(media(.tv), season: 1, episode: 2), ["type": "episode.unwatch", "series": identity(.tv), "seasonNumber": 1, "episodeNumber": 2])
    }

    func testSeasonStateGoldenJSON() throws {
        try assertJSON(.seasonState(media(.tv), season: 2, state: "completed", today: date), ["type": "season.state", "series": identity(.tv), "seasonNumber": 2, "state": "completed", "provenance": "bulk_season", "completedOn": calendarDay])
    }

    func testGameGoldenJSON() throws {
        try assertJSON(.game(media(.game), playthroughID: id, status: "playing", platform: "PC", playtimeMinutes: 120, percent: 25, rating: 4), ["type": "game.upsert", "media": identity(.game), "playthroughId": id, "status": "playing", "platform": "PC", "playtimeMinutes": 120, "progressPercent": 25, "rating": 4])
    }

    func testBookGoldenJSON() throws {
        try assertJSON(.book(media(.book), readingID: id, status: "reading", currentPage: 30, totalPages: 300, percent: 10, rating: 4.5), ["type": "book.upsert", "media": identity(.book), "readingId": id, "status": "reading", "currentPage": 30, "totalPages": 300, "progressPercent": 10, "rating": 4.5])
    }

    func testSaveForLaterGoldenJSON() throws {
        try assertJSON(.saveForLater(media()), ["type": "library.upsert", "media": identity(), "status": "watchlist", "onlyIfUntracked": true])
    }

    func testRatingClearGoldenJSON() throws {
        try assertJSON(.rating(media(), nil), ["type": "rating.set", "media": identity(), "value": NSNull()])
    }

    func testCompletedOnOnlyForCompleted() throws {
        for state in ["watchlist", "watching", "paused", "dropped"] {
            try assertJSON(.seasonState(media(.tv), season: 1, state: state, today: date), ["type": "season.state", "series": identity(.tv), "seasonNumber": 1, "state": state, "provenance": "bulk_season"])
        }
        XCTAssertEqual(try json(.seasonState(media(.tv), season: 1, state: "completed", today: date))["completedOn"] as? String, calendarDay)
    }

    func testStreamingServiceRulesForLogAndUpdate() throws {
        let contexts: [MovieViewingContext?] = [nil] + MovieViewingContext.allCases.map { Optional($0) }
        for context in contexts {
            for service in [nil, "", " \n\t", "  MUBI\n"] as [String?] {
                let commands: [DetailMutation] = [
                    .movieLog(try media(), watchedAt: date, isRewatch: false, rating: nil, review: nil, viewingContext: context, streamingService: service),
                    .movieUpdate(watchID: id, media: try media(), watchedAt: date, isRewatch: false, rating: nil, review: nil, viewingContext: context, streamingService: service)
                ]
                for command in commands {
                    let payload = try json(command)
                    XCTAssertEqual(payload["streamingService"] as? String, context == .streaming && service == "  MUBI\n" ? "MUBI" : nil)
                    XCTAssertEqual(payload["viewingContext"] as? String, context?.rawValue)
                    XCTAssertNil(payload["rating"])
                    XCTAssertNil(payload["review"])
                }
            }
        }
    }

    func testReviewSaveOmitsOptionalIDAndRating() throws {
        try assertJSON(.reviewSave(id: nil, media: media(), body: "Worth watching", containsSpoilers: false, rating: nil), ["type": "review.save", "media": identity(), "body": "Worth watching", "containsSpoilers": false])
    }

    func testOptionalFieldsAreOmitted() throws {
        try assertJSON(.library(media(), status: "watchlist"), ["type": "library.upsert", "media": identity(), "status": "watchlist"])
        try assertJSON(.listAdd(listID: id, media: media()), ["type": "list.add", "listId": id, "media": identity()])
        try assertJSON(.movieLog(media(), watchedAt: date, isRewatch: false, rating: nil, review: nil), ["type": "movie.log", "media": identity(), "watchedAt": calendarDay, "isRewatch": false])
        try assertJSON(.movieUpdate(watchID: id, media: media(), watchedAt: date, isRewatch: false, rating: nil, review: nil), ["type": "movie.update", "watchId": id, "media": identity(), "watchedAt": calendarDay, "isRewatch": false])
        try assertJSON(.episodeLog(media(.tv), season: 1, episode: 1, watchedAt: date, rating: nil), ["type": "episode.log", "series": identity(.tv), "seasonNumber": 1, "episodeNumber": 1, "watchedAt": "2027-01-19T12:00:00Z"])
        try assertJSON(.game(media(.game), playthroughID: nil, status: "backlog", platform: nil, playtimeMinutes: 0, percent: nil, rating: nil), ["type": "game.upsert", "media": identity(.game), "status": "backlog", "playtimeMinutes": 0])
        try assertJSON(.book(media(.book), readingID: nil, status: "want_to_read", currentPage: nil, totalPages: nil, percent: nil, rating: nil), ["type": "book.upsert", "media": identity(.book), "status": "want_to_read"])
    }

    func testAffectedRoutesAndMediaIdentity() throws {
        let movie = try media(), series = try media(.tv)
        let scoped: [DetailMutation] = [
            .rating(movie, nil), .library(movie, status: "watched"), .saveForLater(movie), .removeLibrary(movie),
            .reviewSave(media: movie, body: "Review", containsSpoilers: false), .listAdd(listID: id, media: movie),
            .movieLog(movie, watchedAt: date, isRewatch: false, rating: nil, review: nil),
            .movieUpdate(watchID: id, media: movie, watchedAt: date, isRewatch: false, rating: nil, review: nil),
            .episodeLog(series, season: 1, episode: 1, watchedAt: date, rating: nil),
            .episodeUnwatch(series, season: 1, episode: 1), .seasonState(series, season: 1, state: "watching"),
            .game(try media(.game), playthroughID: nil, status: "playing", platform: nil, playtimeMinutes: 0, percent: nil, rating: nil),
            .book(try media(.book), readingID: nil, status: "reading", currentPage: nil, totalPages: nil, percent: nil, rating: nil)
        ]
        for command in scoped { XCTAssertEqual(command.affectedRoute, command.media?.route); XCTAssertNotNil(command.media) }
        let unscoped: [DetailMutation] = [
            .watchRegion(nil), .reviewDelete(id: id), .movieDelete(watchID: id),
            .listCreate(title: "Picks", description: "", visibility: .public),
            .listUpdate(listID: id, title: "Picks", description: "", visibility: .private),
            .listItemUpdate(listID: id, itemID: itemID, note: ""), .listItemRemove(listID: id, itemID: itemID),
            .listReorder(listID: id, itemIDs: [])
        ]
        for command in unscoped { XCTAssertNil(command.affectedRoute); XCTAssertNil(command.media) }
        XCTAssertEqual(DetailMutation.rating(movie, 4), .rating(movie, 4))
        XCTAssertNotEqual(DetailMutation.rating(movie, 4), .rating(movie, nil))
    }

    func testViewingContextLabels() {
        XCTAssertEqual(MovieViewingContext.allCases.map(\.label), ["Theater", "Streaming", "TV / Broadcast", "Blu-ray / DVD", "Digital purchase/rental", "Other"])
    }

    private var calendarDay: String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    private func identity(_ type: CatalogMediaType = .movie) -> [String: Any] {
        var result: [String: Any] = ["provider": type == .game ? "igdb" : type == .book ? "googlebooks" : "tmdb", "providerId": "1", "mediaType": type.rawValue, "title": "Title", "genres": [String]()]
        if type == .game { result["platforms"] = [String]() }
        if type == .book { result["authors"] = [String]() }
        return result
    }

    private func media(_ type: CatalogMediaType = .movie) throws -> CatalogMedia {
        try JSONDecoder().decode(CatalogMedia.self, from: JSONSerialization.data(withJSONObject: identity(type)))
    }

    private func json(_ command: DetailMutation) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as? [String: Any])
    }

    private func assertJSON(_ command: DetailMutation, _ expected: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws {
        let actual = try json(command)
        XCTAssertEqual(actual as NSDictionary, expected as NSDictionary, file: file, line: line)
        XCTAssertEqual(command.type, expected["type"] as? String, file: file, line: line)
    }
}

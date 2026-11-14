import Foundation
import XCTest
@testable import Mosaic_iOS

final class ContractDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.mosaic.decode(type, from: Data(json.utf8))
    }
    private let mediaJSON = #"{"provider":"tmdb","providerId":"438631","mediaType":"movie","title":"Dune","genres":["Science Fiction"],"releaseYear":2021}"#

    private let seriesJSON = #"{"provider":"tmdb","providerId":"71912","mediaType":"tv","title":"The Witcher","genres":["Fantasy"]}"#

    func testWatchAvailabilityAndNull() throws {
        let availability = try decode(WatchAvailability?.self, #"""
        {"country":"IN","link":"https://www.themoviedb.org/movie/438631/watch?locale=IN","providers":[
          {"id":8,"name":"Netflix","logoUrl":"https://image.tmdb.org/t/p/w92/netflix.jpg","kind":"flatrate"},
          {"id":2,"name":"Apple TV","kind":"rent"},
          {"id":3,"name":"Free channel","kind":"free"},
          {"id":4,"name":"Ad channel","kind":"ads"},
          {"id":5,"name":"Store","kind":"buy"}
        ]}
        """#)
        XCTAssertEqual(availability?.country, "IN")
        XCTAssertEqual(availability?.providers.map(\.kind), [.flatrate, .rent, .free, .ads, .buy])
        XCTAssertNotNil(availability?.providers.first?.logoURL)
        XCTAssertNil(try decode(WatchAvailability?.self, "null"))
        XCTAssertEqual(try decode(WatchAvailability.self, #"{"country":"US","providers":[]}"#).providers.count, 0)
    }

    func testEpisodeRatings() throws {
        let response = try decode(EpisodeRatings.self, #"""
        {"seasons":[[],[{"id":"tmdb:tv:71912:1:1","seasonNumber":1,"episodeNumber":1,"title":"The End’s Beginning","overview":"Geralt arrives in Blaviken.","stillUrl":"https://image.tmdb.org/t/p/w300/still.jpg","airDate":"2019-12-20","runtimeMinutes":61,"publicRating":8.1,"publicRatingCount":245},{"id":"tmdb:tv:71912:1:2","seasonNumber":1,"episodeNumber":2,"title":"Four Marks"}]]}
        """#)
        XCTAssertEqual(response.seasons.count, 2)
        XCTAssertEqual(response.seasons[1][0].publicRating, 8.1)
        XCTAssertNotNil(response.seasons[1][0].stillURL)
        XCTAssertNil(response.seasons[1][1].publicRating)
    }

    func testMosaicSnapshotAndProviderKeyWithColons() throws {
        let snapshot = try decode(MosaicSnapshot.self, #"""
        {"period":{"kind":"month","year":2026,"month":2,"label":"February 2026"},"generatedAt":"2026-02-20T00:00:00.000Z",
         "totals":{"storiesRepresented":2,"byMediaType":{"movie":0,"series":1,"game":0,"book":1},"movieWatchLogs":2},
         "tiles":[
          {"key":"mock:tv:series:part:one","mediaType":"series","providerId":"series:part:one","title":"Series","artwork":"https://example.com/poster.jpg","href":"/series/mock%3Atv%3Aseries%3Apart%3Aone","activity":{"firstActivityAt":"2026-02-01","lastActivityAt":"2026-02-02","eventCount":2},"userSignals":{"rating":4.5,"favorite":true,"rewatchCount":1},"providerMetadata":{"year":2025,"genres":["Mystery"]},"visualWeight":1.44},
          {"key":"mock:book:book","mediaType":"book","providerId":"book","title":"Book","href":"/book/mock%3Abook%3Abook","activity":{"eventCount":1,"progress":10,"completed":false},"userSignals":{},"providerMetadata":{},"visualWeight":1}
         ]}
        """#)
        XCTAssertEqual(snapshot.period.kind, .month)
        XCTAssertEqual(snapshot.period.month, 2)
        XCTAssertEqual(snapshot.totals.byMediaType.series, 1)
        XCTAssertEqual(snapshot.tiles[0].catalogMediaType, .tv)
        XCTAssertEqual(snapshot.tiles[0].route, MediaDetailRoute(provider: "mock", mediaType: .tv, providerID: "series:part:one"))
        XCTAssertEqual(snapshot.tiles[1].activity.progress, 10)
        XCTAssertNil(snapshot.tiles[1].userSignals.rating)
        for (json, kind) in [(#"{"kind":"all","label":"All time"}"#, MosaicPeriod.Kind.all), (#"{"kind":"year","year":2026,"label":"2026"}"#, .year)] {
            XCTAssertEqual(try decode(MosaicPeriod.self, json).kind, kind)
        }
    }

    func testProfileStatsFixedKeysAndOptionalFields() throws {
        // Same populations and separate activity units as profile-stats.test.ts.
        let json = #"""
        {"years":[2026,2025],"stats":{
          "period":{"kind":"year","year":2026},
          "movie":{"watchLogs":4,"uniqueTitles":4,"rewatchLogs":1,"recent":[\#(mediaJSON)],"mostRewatched":{"media":\#(mediaJSON),"count":1}},
          "series":{"episodeLogs":3,"uniqueEpisodes":2,"rewatchLogs":1,"shows":1,"recent":[],"mostLogged":[{"media":\#(seriesJSON),"count":3}],"status":{"watching":1,"paused":0,"completed":0,"dropped":0,"watchlist":0}},
          "game":{"completedPlaythroughs":1,"statuses":{"playing":1,"paused":0,"completed":1,"dropped":0,"backlog":0},"recordedPlaytimeMinutes":690,"completed":[]},
          "book":{"finished":1,"statuses":{"reading":1,"paused":0,"finished":1,"dnf":0,"want_to_read":7},"finishedTitles":[],"authors":[{"name":"Ursula K. Le Guin","count":2}]},
          "ratings":{"population":"logged-in-period","count":2,"average":4.75,"distribution":[{"value":0.5,"count":0},{"value":1,"count":0},{"value":1.5,"count":0},{"value":2,"count":0},{"value":2.5,"count":0},{"value":3,"count":0},{"value":3.5,"count":0},{"value":4,"count":0},{"value":4.5,"count":1},{"value":5,"count":1}],"byMedium":{"movie":{"count":1,"average":4.5},"series":{"count":1,"average":5},"game":{"count":0},"book":{"count":0}},"top":[{"media":\#(mediaJSON),"value":4.5}]},
          "genres":{"movie":{"titles":4,"withGenres":3,"top":[{"name":"Drama","count":3}]},"series":{"titles":1,"withGenres":1,"top":[]},"game":{"titles":2,"withGenres":2,"top":[]},"book":{"titles":2,"withGenres":0,"top":[]}},
          "activity":{"movie":{"unit":"film watches","granularity":"month","buckets":[{"key":"2026-02","label":"Feb","count":3}],"total":4,"peak":{"key":"2026-02","label":"Feb","count":3},"weekdays":[0,1,0,0,1,0,2]},"series":{"unit":"episodes logged","granularity":"year","buckets":[],"total":0,"weekdays":[0,0,0,0,0,0,0]}}
        }}
        """#
        let response = try decode(ProfileStatsResponse.self, json)
        XCTAssertEqual(response.years, [2026, 2025])
        XCTAssertEqual(response.stats.book.statuses.wantToRead, 7)
        XCTAssertEqual(response.stats.movie.mostRewatched?.media.providerID, "438631")
        XCTAssertEqual(response.stats.ratings.byMedium.series.average, 5)
        XCTAssertNil(response.stats.ratings.byMedium.book.average)
        XCTAssertEqual(response.stats.activity.movie.peak?.count, 3)
        XCTAssertNil(response.stats.activity.series.peak)
        XCTAssertEqual(try decode(StatsPeriod.self, #"{"kind":"all"}"#).kind, .all)
    }

    func testImportPreviewPreservesDictionaryKeysAndRoundTripsRows() throws {
        let json = #"""
        {"jobId":"89b6d86b-8f14-4be7-b197-778dac24dba6","source":"serializd_normalized_v1","filename":"serializd.json",
         "rows":[{"record":{"source":"serializd_normalized_v1","sourceRecordKey":"serializd:event:1","mediaType":"tv","title":"The Witcher","providerIdentity":{"provider":"tmdb","mediaType":"tv","providerId":"71912"},"sourceMetadata":{"exact_resolved_records":"1","source_record_id":"s1"},"recordKind":"event","targetType":"episode","tmdbSeasonId":100,"seasonState":"completed","stateFacts":{"watched_any":true,"currently_watching":null},"isFavorite":true,"defaultImport":true,"isRewatch":false,"isLog":true,"containsSpoilers":false,"tags":["imported"],"sourceCreatedAt":"2026-01-01T00:00:00Z","seasonNumber":1,"episodeNumber":1,"episodeTitle":"Pilot","episodeProviderId":"123","watchedDate":"2026-01-01"},"match":{"confidence":"exact","resolved":\#(seriesJSON),"candidates":[{"media":\#(seriesJSON),"score":1,"reasons":["Exact provider identity"]}]},"decision":"accepted","selected":\#(seriesJSON)}],
         "counts":{"total":1,"automaticMatches":1,"needsReview":0,"unmatched":0,"libraryEntries":0,"ratings":0,"reviews":0,"movieWatches":0,"episodeWatches":1,"gamePlaythroughs":0,"bookReadings":0,"lists":0,"duplicates":0,"invalid":0,"skipped":0},
         "errors":[{"row":2,"field":"title","message":"Title is required."},{"row":3,"message":"Invalid record."}],"warnings":["One invalid row"],"normalizedSummary":{"exact_resolved_records":1}}
        """#
        let preview = try JSONDecoder().decode(ImportPreview.self, from: Data(json.utf8))
        XCTAssertEqual(preview.normalizedSummary?["exact_resolved_records"], 1)
        XCTAssertNil(preview.normalizedSummary?["exactResolvedRecords"])
        XCTAssertEqual(preview.rows[0].record.sourceMetadata["source_record_id"], "s1")
        XCTAssertEqual(preview.rows[0].record.sourceMetadata["exact_resolved_records"], "1")
        XCTAssertEqual(preview.rows[0].record.stateFacts?["watched_any"], true)
        XCTAssertTrue(preview.rows[0].record.stateFacts?.keys.contains("currently_watching") == true)
        XCTAssertEqual(preview.rows[0].record.providerIdentity?.providerID, "71912")
        let row = try JSONDecoder().decode(ReconciliationRow.self, from: JSONEncoder().encode(preview.rows[0]))
        XCTAssertEqual(row.record.sourceMetadata, preview.rows[0].record.sourceMetadata)
        XCTAssertEqual(row.selected?.providerID, "71912")
        XCTAssertEqual(row.match.candidates[0].reasons, ["Exact provider identity"])
    }

    func testAllNormalizedRecordKinds() throws {
        let records = try JSONDecoder().decode([NormalizedImportRecord].self, from: Data(#"""
        [
         {"source":"letterboxd","sourceRecordKey":"diary:1","mediaType":"movie","title":"Dune","originalTitle":"Dune","year":2021,"rating":4.5,"review":"Desert worlds","sourceMetadata":{"letterboxd_uri":"https://letterboxd.com/film/dune-2021/"},"recordKind":"list_item","status":"watched","watchedDate":"2026-02-01","isRewatch":true,"tags":["sci-fi"],"list":{"sourceListKey":"list:1","title":"Favorites","description":"My list","position":0,"note":"Revisit"}},
         {"source":"generic_series","sourceRecordKey":"show:1","mediaType":"tv","title":"Series","sourceMetadata":{},"recordKind":"show_state","status":"watching"},
         {"source":"backloggd","sourceRecordKey":"game:1","mediaType":"game","title":"Game","sourceMetadata":{},"status":"playing","platform":"PC","startedAt":"2026-01-01","completedAt":"2026-02-01","playtimeMinutes":90,"progressPercent":30},
         {"source":"fable","sourceRecordKey":"book:1","mediaType":"book","title":"Book","sourceMetadata":{},"status":"reading","author":"Ursula K. Le Guin","startedAt":"2026-01-01","finishedAt":"2026-03-01","currentPage":40,"totalPages":200}
        ]
        """#.utf8))
        XCTAssertEqual(records.map(\.mediaType), [.movie, .tv, .game, .book])
        XCTAssertEqual(records[0].list?.sourceListKey, "list:1")
        XCTAssertEqual(records[2].progressPercent, 30)
        XCTAssertEqual(records[3].totalPages, 200)
        XCTAssertNil(records[1].rating)
        XCTAssertEqual(ImportSource.allCases.count, 9)
        XCTAssertEqual(ImportSource.sources.map(\.value), [.letterboxd, .genericMovies, .serializdNormalizedV1, .serializd, .backloggd, .fable])
        let base = URL(string: "https://example.com")!
        XCTAssertEqual([CatalogMediaType.movie, .tv, .game, .book].map { ImportSource.templateURL(for: $0, baseURL: base).path }, ["/templates/movies.csv", "/templates/series.csv", "/templates/games.csv", "/templates/books.csv"])
    }

    func testImportHistoryResultsAndApplyEncoding() throws {
        let history = try decode(ImportHistoryResponse.self, #"""
        {"jobs":[{"id":"job-1","source":"generic_books","filename":"books.csv","status":"partially_undone","totalRecords":4,"importedRecords":3,"skippedRecords":0,"failedRecords":1,"createdAt":"2026-02-01T00:00:00Z","completedAt":"2026-02-01T00:01:00Z","errorSummary":"One record failed."}]}
        """#)
        XCTAssertEqual(history.jobs[0].status, .partiallyUndone)
        XCTAssertEqual(try decode(ImportUndoResult.self, #"{"removed":2,"preserved":1,"missing":0}"#).preserved, 1)
        let result = try decode(ImportApplyResult.self, #"{"imported":3,"skipped":1,"conflicts":0,"wasReimport":true,"failed":1}"#)
        XCTAssertTrue(result.wasReimport)
        XCTAssertEqual(result.failed, 1)
        let media = try decode(CatalogMedia.self, mediaJSON)
        let request = ImportApplyRequest(conflictPolicy: .keepMosaic, resolutions: [
            .init(sourceRecordKey: "a", decision: .accepted, selected: media),
            .init(sourceRecordKey: "b", decision: .skipped),
        ])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(object["conflictPolicy"] as? String, "keep_mosaic")
        XCTAssertEqual(object["importFavorites"] as? Bool, true)
        let resolutions = try XCTUnwrap(object["resolutions"] as? [[String: Any]])
        XCTAssertEqual((resolutions[0]["selected"] as? [String: Any])?["providerId"] as? String, "438631")
        XCTAssertNil(resolutions[1]["selected"])
    }

    func testAssistantRequestsEventsAndLooseFacts() throws {
        let request = AssistantRequest(message: "What should I watch?", about: "")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertNil(object["history"])
        XCTAssertNil(object["about"])
        let full = AssistantRequest(message: "More like this", history: [.init(role: .user, text: "I enjoyed Dune")], about: "tmdb:movie:438631")
        let fullObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(full)) as? [String: Any])
        XCTAssertEqual((fullObject["history"] as? [[String: String]])?.first?["role"], "user")
        if case .unknown = try decode(AssistantEvent.self, #"{"type":"future_event","payload":{"a":1}}"#) {} else { XCTFail("Expected unknown event") }
        if case let .status(tool, label) = try decode(AssistantEvent.self, #"{"type":"status","tool":"library","label":"Checking your library"}"#) {
            XCTAssertEqual(tool, "library"); XCTAssertEqual(label, "Checking your library")
        } else { XCTFail("Expected status") }
        if case let .text(delta) = try decode(AssistantEvent.self, #"{"type":"text","delta":"Try [[r1]]"}"#) { XCTAssertEqual(delta, "Try [[r1]]") } else { XCTFail("Expected text") }
        let refs = try decode(AssistantEvent.self, #"""
        {"type":"refs","refs":[
         {"id":"r1","origin":"your_mosaic","media":{"provider":"tmdb","mediaType":"movie","providerId":"438631","title":"Dune","posterUrl":"https://example.com/dune.jpg","releaseYear":2021},"facts":{"status":"watched","userRating":4.5,"isFavorite":true,"extra":null}},
         {"id":"r2","origin":"catalog","media":{"provider":"mock","mediaType":"book","providerId":"dune","title":"Dune"},"reason":"Another desert world","seed":"r1","facts":{"status":false,"userRating":"unknown","isFavorite":null}}
        ]}
        """#)
        if case let .refs(items) = refs {
            XCTAssertEqual(items[0].facts?.userRating, 4.5)
            XCTAssertEqual(items[0].facts?.isFavorite, true)
            XCTAssertEqual(items[0].media.route.providerID, "438631")
            XCTAssertNil(items[1].facts?.status)
            XCTAssertNil(items[1].facts?.userRating)
            XCTAssertEqual(items[1].seed, "r1")
        } else { XCTFail("Expected refs") }
        if case let .scope(items) = try decode(AssistantEvent.self, #"{"type":"scope","items":[{"tool":"library","summary":"14 titles"}]}"#) { XCTAssertEqual(items[0].summary, "14 titles") } else { XCTFail("Expected scope") }
        if case let .done(truncated, cited, usage) = try decode(AssistantEvent.self, #"{"type":"done","truncated":false,"cited":["r1"],"usage":{"inputTokens":100,"outputTokens":50,"modelCalls":1,"toolCalls":2}}"#) {
            XCTAssertFalse(truncated); XCTAssertEqual(cited, ["r1"]); XCTAssertEqual(usage?.toolCalls, 2)
        } else { XCTFail("Expected done") }
        if case let .done(_, _, usage) = try decode(AssistantEvent.self, #"{"type":"done","truncated":true,"cited":[]}"#) { XCTAssertNil(usage) } else { XCTFail("Expected done") }
        if case let .error(code, _, retryable) = try decode(AssistantEvent.self, #"{"type":"error","code":"RATE_LIMITED","message":"Try later","retryable":true}"#) {
            XCTAssertEqual(code, "RATE_LIMITED"); XCTAssertTrue(retryable)
        } else { XCTFail("Expected error") }
    }

    func testFranchiseMirrorAndLookups() throws {
        // Ordered identities copied from the web's complete five-entry curated catalog.
        let expected = [
            ["mock:book:dune", "mock:movie:dune-part-two", "tmdb:movie:438631", "tmdb:movie:693134"],
            ["tmdb:tv:71912", "tmdb:movie:1203329", "igdb:game:1942"],
            ["tmdb:movie:671", "tmdb:movie:674", "tmdb:tv:224377", "igdb:game:136625"],
            ["tmdb:movie:11", "tmdb:movie:140607", "tmdb:tv:4194", "igdb:game:74701"],
            ["tmdb:movie:120", "tmdb:movie:122", "tmdb:tv:84773", "igdb:game:3025"],
        ]
        XCTAssertEqual(Franchises.all.count, 5)
        XCTAssertEqual(Franchises.all.map(\.slug), ["dune", "the-witcher", "wizarding-world", "star-wars", "middle-earth"])
        XCTAssertEqual(Franchises.all.map { $0.items.map { "\($0.provider):\($0.mediaType.rawValue):\($0.providerID)" } }, expected)
        XCTAssertEqual(Franchises.all.first?.items.first?.providerID, "dune")
        XCTAssertEqual(Franchises.all.last?.items.last?.providerID, "3025")
        XCTAssertEqual(Franchises.forMedia(try decode(CatalogMedia.self, mediaJSON))?.slug, "dune")
        XCTAssertEqual(Franchises.bySlug("the-witcher")?.title, "The Witcher")
        XCTAssertNil(Franchises.bySlug("unknown"))
    }

    @MainActor func testExistingMemberwiseInitializerCanOmitNewClosures() async {
        let failure = MosaicAPIError.notFound("Unavailable.")
        let services = MosaicServices(
            continueItems: { [] }, library: { [] }, activity: { _ in [] }, stats: { throw failure }, lists: { [] },
            stateSnapshot: { MosaicStateSnapshot() }, seriesState: { _ in throw failure }, mutate: { _ in }, updateProfile: { _ in throw failure },
            discover: { _ in throw failure }, genre: { _, _ in throw failure }, theme: { _, _ in throw failure }, related: { _ in throw failure },
            search: { _, _ in throw failure }, detail: { _ in throw failure }, season: { _ in throw failure }
        )
        do { _ = try await services.importHistory(); XCTFail("Default should throw") }
        catch { XCTAssertEqual(error as? MosaicAPIError, failure) }
    }
}

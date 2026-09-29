import XCTest
@testable import Mosaic_iOS

@MainActor
final class MosaicFoundationTests: XCTestCase {
    func testConfigurationKeepsProductionAPIBaseURL() {
        let configuration = AppConfiguration(apiBaseURL: URL(string: "https://mosaic-eight-theta.vercel.app")!, supabaseURL: nil, supabasePublishableKey: "")
        XCTAssertEqual(configuration.apiBaseURL.absoluteString, "https://mosaic-eight-theta.vercel.app")
        XCTAssertFalse(configuration.hasSupabaseCredentials)
    }

    func testNativeOAuthCallbackIsStable() {
        XCTAssertEqual(OAuthCallback.url.absoluteString, "mosaic://auth/callback")
    }

    func testOAuthFailureMessagesAreSpecificAndSafe() {
        XCTAssertEqual(OAuthFailure.couldNotStart.message, "Google sign-in could not be started. Please try again.")
        XCTAssertEqual(OAuthFailure.cancelled.message, "Google sign-in was cancelled.")
        XCTAssertEqual(OAuthFailure.completionFailed.message, "Google sign-in could not be completed. Please try again.")
    }

    func testRequestBuildsEndpointAndBearerHeader() throws {
        let client = MosaicAPIClient(baseURL: URL(string: "https://mosaic-eight-theta.vercel.app")!)
        let request = try client.makeRequest(path: "/api/me", token: "access-token")
        XCTAssertEqual(request.url?.absoluteString, "https://mosaic-eight-theta.vercel.app/api/me")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testNormalizedErrorDecoding() throws {
        let data = Data(#"{"error":{"code":"VALIDATION_ERROR","message":"Invalid value"}}"#.utf8)
        let envelope = try JSONDecoder.mosaic.decode(MosaicErrorEnvelope.self, from: data)
        XCTAssertEqual(MosaicAPIError.from(code: envelope.error.code, message: envelope.error.message, statusCode: 422), .validation("Invalid value"))
        XCTAssertEqual(MosaicAPIError.from(code: nil, message: "Nope", statusCode: 401), .unauthorized("Nope"))
    }

    func testMeResponseDecodingAndSessionStates() throws {
        let data = Data(#"{"id":"user-1","profile":{"display_name":"Ada","username":"ada","avatar_url":"https://example.com/ada.png"}}"#.utf8)
        let user = try JSONDecoder.mosaic.decode(CurrentUser.self, from: data)
        XCTAssertEqual(user.id, "user-1")
        XCTAssertEqual(user.profile?.displayName, "Ada")
        XCTAssertEqual(SessionState.signedOut, .signedOut)
        XCTAssertEqual(SessionState.signedIn, .signedIn)
    }

    func testContinueDTOMapsSeriesProgressWithoutInventingDenominator() throws {
        let response = try decodeContinueResponse(#"""
        {"items":[{"id":"tmdb:tv:1","media_type":"series","provider":"tmdb","provider_id":"1","title":"Orbit","status":"watching","last_activity_at":"2026-09-21T18:22:00.000Z","progress":{"watched_episodes":14,"total_episodes":null,"percent":null,"next_season_number":2,"next_episode_number":1},"next_action":{"type":"log_episode","season_number":2,"episode_number":1}}]}
        """#)
        let story = try XCTUnwrap(response.items.first.map(ContinueStory.init(dto:)))
        XCTAssertEqual(story.progress.detailLines, ["Next: S2E1", "14 episodes"])
        XCTAssertNil(story.progress.progressFraction)
    }

    func testContinueDTOMapsBookAndGameProgress() throws {
        let response = try decodeContinueResponse(#"""
        {"items":[
          {"id":"googlebooks:book:2","media_type":"book","provider":"googlebooks","provider_id":"2","title":"Dune","status":"reading","last_activity_at":null,"progress":{"current_page":312,"total_pages":688,"percent":45},"next_action":{"type":"update_book_progress"}},
          {"id":"igdb:game:3","media_type":"game","provider":"igdb","provider_id":"3","title":"Hades","status":"playing","last_activity_at":null,"progress":{"percent":null,"playtime_minutes":245},"next_action":{"type":"update_game_playthrough"}}
        ]}
        """#)
        let stories = response.items.map(ContinueStory.init(dto:))
        XCTAssertEqual(stories[0].progress.detailLines, ["312 / 688 pages"])
        XCTAssertEqual(stories[0].progress.progressFraction, 0.45)
        XCTAssertEqual(stories[1].progress.detailLines, ["4h 5m played"])
        XCTAssertNil(stories[1].progress.progressFraction)
    }

    func testContinueStoryBuildsStableCatalogDetailRoute() throws {
        let story = try XCTUnwrap(decodeContinueResponse(#"{"items":[{"id":"tmdb:tv:1396","media_type":"series","provider":"tmdb","provider_id":"1396","title":"Breaking Bad","status":"watching","last_activity_at":null,"progress":{"watched_episodes":14,"total_episodes":62,"percent":23},"next_action":{"type":"log_episode"}}]}"#).items.first.map(ContinueStory.init(dto:)))

        XCTAssertEqual(story.detailRoute, MediaDetailRoute(provider: "tmdb", mediaType: .tv, providerID: "1396"))
        XCTAssertEqual(story.detailRoute.catalogPath, "/api/catalog/tmdb/tv/1396")
    }

    func testCatalogSearchDecodesEveryMediaTypeAndUsesStableIdentity() throws {
        let response = try decodeCatalogSearch(#"{"items":[{"provider":"tmdb","providerId":"1","mediaType":"movie","title":"Dune","posterUrl":"https://example.com/movie.jpg","genres":["Science Fiction"],"runtimeMinutes":155},{"provider":"tmdb","providerId":"2","mediaType":"tv","title":"The Last of Us","genres":[],"seasonCount":1,"episodeCount":9},{"provider":"igdb","providerId":"3","mediaType":"game","title":"Hades","genres":["Roguelike"],"platforms":["Switch"],"developer":"Supergiant"},{"provider":"googlebooks","providerId":"4","mediaType":"book","title":"Dune","genres":[],"authors":["Frank Herbert"],"pageCount":688}],"failures":[]}"#)
        XCTAssertEqual(response.items.map(\.mediaType), [.movie, .tv, .game, .book])
        XCTAssertEqual(response.items[0].route, MediaDetailRoute(provider: "tmdb", mediaType: .movie, providerID: "1"))
        XCTAssertEqual(response.items[0].artworkURL?.absoluteString, "https://example.com/movie.jpg")
        XCTAssertEqual(response.items[2].resultMetadata, "Game · Switch")
        XCTAssertEqual(response.items[3].resultMetadata, "Book · Frank Herbert")
    }

    func testCatalogDetailOptionalFieldsAndArtworkFallback() throws {
        let media = try JSONDecoder.mosaic.decode(CatalogMedia.self, from: Data(#"{"provider":"googlebooks","providerId":"book-1","mediaType":"book","title":"A Long Book","genres":[],"authors":[]}"#.utf8))
        XCTAssertNil(media.backdropURL)
        XCTAssertNil(media.posterURL)
        XCTAssertNil(media.artworkURL)
        XCTAssertNil(media.pageCount)
        XCTAssertEqual(media.authors, [])
    }

    func testSearchFilterMapsToDocumentedCatalogTypes() {
        XCTAssertNil(CatalogFilter.all.catalogType)
        XCTAssertEqual(CatalogFilter.movies.catalogType, "movie")
        XCTAssertEqual(CatalogFilter.series.catalogType, "tv")
        XCTAssertEqual(CatalogFilter.games.catalogType, "game")
        XCTAssertEqual(CatalogFilter.books.catalogType, "book")
    }

    func testSearchNormalizesWhitespaceAndHandlesEmptyResults() async throws {
        let empty = try decodeCatalogSearch(#"{"items":[],"failures":[]}"#)
        let model = SearchViewModel(search: { query, filter in
            XCTAssertEqual(query, "Dune")
            XCTAssertEqual(filter, .all)
            return empty
        })
        model.query = "  Dune  "
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertEqual(model.state, .empty(partialFailure: nil))
        model.query = " "
        XCTAssertEqual(model.state, .noQuery)
    }

    func testSearchProtectsAgainstStaleResults() async throws {
        let responder = SearchResponder()
        let model = SearchViewModel(search: { query, _ in await responder.response(for: query) })
        model.query = "Du"
        try await Task.sleep(for: .milliseconds(375))
        model.query = "Dune"
        try await Task.sleep(for: .milliseconds(950))
        guard case let .results(items, _) = model.state else { return XCTFail("Expected current results") }
        XCTAssertEqual(items.first?.title, "Dune")
    }

    func testSearchErrorAndDetailErrorPresentation() {
        XCTAssertEqual(SearchErrorPresentation.from(MosaicAPIError.network("offline")), .offline)
        XCTAssertEqual(SearchErrorPresentation.from(MosaicAPIError.providerUnavailable("down")), .unavailable)
        XCTAssertEqual(DetailErrorPresentation.from(MosaicAPIError.notFound("gone")), .notFound)
        XCTAssertEqual(DetailErrorPresentation.from(MosaicAPIError.decoding("bad")), .unreadable)
    }

    func testLibraryEntryMapsIdentityProgressAndRating() throws {
        let response = try JSONDecoder.mosaic.decode(LibraryResponseDTO.self, from: Data(#"{"items":[{"id":"tmdb:tv:1396","mediaType":"tv","provider":"tmdb","providerId":"1396","title":"Breaking Bad","status":"watching","userRating":4.5,"isFavorite":true,"updatedAt":"2026-09-19T10:00:00.000Z","progress":{"watchedEpisodes":14,"totalEpisodes":62,"percent":23}}]}"#.utf8))
        let item = try XCTUnwrap(response.items.first)
        XCTAssertEqual(item.route, MediaDetailRoute(provider: "tmdb", mediaType: .tv, providerID: "1396"))
        XCTAssertEqual(item.progress?.displayText, "14 / 62 episodes")
        XCTAssertEqual(item.ratingText, "4.5 ★")
    }

    func testLibraryProgressOmitsZeroAndUnknownValues() throws {
        let progress = try JSONDecoder.mosaic.decode(LibraryProgressDTO.self, from: Data(#"{"watchedEpisodes":0,"totalEpisodes":null,"percent":null}"#.utf8))
        XCTAssertNil(progress.displayText)
    }

    func testLibraryFiltersAndSortsLocallyWithoutDetailFanout() async throws {
        let items = try JSONDecoder.mosaic.decode(LibraryResponseDTO.self, from: Data(#"{"items":[{"id":"tmdb:movie:1","mediaType":"movie","provider":"tmdb","providerId":"1","title":"Zulu","releaseYear":2020,"status":"watched","userRating":3,"isFavorite":false,"updatedAt":"2026-09-18T10:00:00.000Z"},{"id":"igdb:game:2","mediaType":"game","provider":"igdb","providerId":"2","title":"Alpha","releaseYear":2024,"status":"playing","userRating":5,"isFavorite":false,"updatedAt":"2026-09-19T10:00:00.000Z"}]}"#.utf8)).items
        let model = LibraryViewModel(request: { items })
        model.load(); await waitForHomeLoad()
        model.mediaFilter = .games
        XCTAssertEqual(model.visibleItems.map(\.title), ["Alpha"])
        model.mediaFilter = .all; model.sort = .title
        XCTAssertEqual(model.visibleItems.map(\.title), ["Alpha", "Zulu"])
    }

    func testHomeErrorPresentationMapsAPIError() {
        XCTAssertEqual(HomeErrorPresentation.from(MosaicAPIError.network("offline")), .offline)
        XCTAssertEqual(HomeErrorPresentation.from(MosaicAPIError.unauthorized("expired")), .sessionExpired)
        XCTAssertEqual(HomeErrorPresentation.from(MosaicAPIError.decoding("bad")), .unreadable)
    }

    func testHomeViewModelLoadsAndRetries() async {
        let story = try! decodeContinueResponse(#"{"items":[{"id":"igdb:game:3","media_type":"game","provider":"igdb","provider_id":"3","title":"Hades","status":"playing","last_activity_at":null,"progress":{"percent":null,"playtime_minutes":0},"next_action":{"type":"update_game_playthrough"}}]}"#).items.map(ContinueStory.init(dto:))[0]
        var attempts = 0
        let model = HomeViewModel(requestStories: {
            attempts += 1
            if attempts == 1 { throw MosaicAPIError.network("offline") }
            return [story]
        })
        model.load()
        await waitForHomeLoad()
        XCTAssertEqual(model.state, .error(.offline))
        model.retry()
        await waitForHomeLoad()
        XCTAssertEqual(model.state, .loaded([story]))
    }

    private func decodeContinueResponse(_ json: String) throws -> ContinueResponseDTO {
        try JSONDecoder.mosaic.decode(ContinueResponseDTO.self, from: Data(json.utf8))
    }

    private func decodeCatalogSearch(_ json: String) throws -> CatalogSearchResponse {
        try JSONDecoder.mosaic.decode(CatalogSearchResponse.self, from: Data(json.utf8))
    }

    private func waitForHomeLoad() async {
        for _ in 0..<8 { await Task.yield() }
    }
}

private actor SearchResponder {
    func response(for query: String) async -> CatalogSearchResponse {
        if query == "Du" { try? await Task.sleep(for: .milliseconds(700)) }
        let title = query == "Du" ? "Stale" : "Dune"
        return try! JSONDecoder.mosaic.decode(CatalogSearchResponse.self, from: Data("{\"items\":[{\"provider\":\"tmdb\",\"providerId\":\"1\",\"mediaType\":\"movie\",\"title\":\"\(title)\",\"genres\":[]}],\"failures\":[]}".utf8))
    }
}

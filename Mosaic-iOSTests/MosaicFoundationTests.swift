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

    private func waitForHomeLoad() async {
        for _ in 0..<8 { await Task.yield() }
    }
}

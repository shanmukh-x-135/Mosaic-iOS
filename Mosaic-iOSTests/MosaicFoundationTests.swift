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
}

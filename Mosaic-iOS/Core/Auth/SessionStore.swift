import AuthenticationServices
import Foundation
import Observation
import Supabase

enum SessionState: Equatable, Sendable { case launching, signedOut, signedIn, error(String) }

enum OAuthCallback {
    static let url = URL(string: "mosaic://auth/callback")!
}

enum OAuthFailure: Equatable {
    case couldNotStart
    case cancelled
    case completionFailed

    var message: String {
        switch self {
        case .couldNotStart: "Google sign-in could not be started. Please try again."
        case .cancelled: "Google sign-in was cancelled."
        case .completionFailed: "Google sign-in could not be completed. Please try again."
        }
    }
}

@MainActor @Observable
final class SessionStore {
    private let configuration: AppConfiguration
    private var client: SupabaseClient?
    private let api: MosaicAPIClient
    private(set) var state: SessionState = .launching
    private(set) var currentUser: CurrentUser?
    private(set) var backendError: String?

    init(configuration: AppConfiguration) {
        self.configuration = configuration
        api = MosaicAPIClient(baseURL: configuration.apiBaseURL)
        if let url = configuration.supabaseURL, !configuration.supabasePublishableKey.isEmpty {
            client = SupabaseClient(supabaseURL: url, supabaseKey: configuration.supabasePublishableKey)
        }
    }

    func restoreSession() async {
        guard let client else { state = .error("Supabase configuration is required before sign-in can be enabled."); return }
        guard let session = try? await client.auth.session else { state = .signedOut; return }
        await completeAuthentication(session)
    }

    func signInWithGoogle() async {
        guard let client else { state = .error("Supabase configuration is required before sign-in can be enabled."); return }
        do {
            // Supabase owns ASWebAuthenticationSession and returns the exchanged session.
            // Do not exchange the same callback again through SwiftUI's onOpenURL.
            let session = try await client.auth.signInWithOAuth(provider: .google, redirectTo: OAuthCallback.url)
            await completeAuthentication(session)
        } catch {
            state = .error(oauthFailure(for: error).message)
            debugLog(error, context: "Google OAuth")
        }
    }

    func signOut() async {
        guard let client else { state = .signedOut; return }
        do { try await client.auth.signOut() } catch { /* Local root flow remains signed out. */ }
        currentUser = nil; state = .signedOut
    }

    func currentAccessToken() async throws -> String {
        guard let client else { throw MosaicAPIError.unauthorized("Sign in to load your stories.") }
        return try await client.auth.session.accessToken
    }

    private func completeAuthentication(_ session: Session) async {
        guard !session.accessToken.isEmpty else {
            state = .error(OAuthFailure.completionFailed.message)
            return
        }

        // A valid Supabase session always enters the authenticated shell. A temporary
        // Mosaic API failure must not discard it or send the user back to sign-in.
        state = .signedIn
        backendError = nil
        do {
            currentUser = try await api.request("/api/me", token: session.accessToken, as: CurrentUser.self)
        } catch {
            backendError = "You are signed in, but Mosaic could not load your account. Please try again later."
            debugLog(error, context: "GET /api/me")
        }
    }

    private func oauthFailure(for error: Error) -> OAuthFailure {
        let error = error as NSError
        guard error.domain == ASWebAuthenticationSessionErrorDomain else { return .completionFailed }
        return switch error.code {
        case 1: .cancelled // ASWebAuthenticationSessionErrorCodeCanceledLogin
        case 2, 3: .couldNotStart // Missing or invalid presentation context
        default: .completionFailed
        }
    }

    private func debugLog(_ error: Error, context: String) {
        #if DEBUG
        print("[Mosaic] \(context) failed: \(type(of: error)): \(error.localizedDescription)")
        #endif
    }
}

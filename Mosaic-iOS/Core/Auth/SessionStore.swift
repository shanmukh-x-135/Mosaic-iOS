import Foundation
import Observation
import Supabase

enum SessionState: Equatable, Sendable { case launching, signedOut, signedIn, error(String) }

@MainActor @Observable
final class SessionStore {
    private let configuration: AppConfiguration
    private var client: SupabaseClient?
    private let api: MosaicAPIClient
    private(set) var state: SessionState = .launching
    private(set) var currentUser: CurrentUser?

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
        do {
            try await loadCurrentUser(accessToken: session.accessToken)
            state = .signedIn
        } catch {
            state = .error("Your session was restored, but Mosaic could not load your account.")
        }
    }

    func signInWithGoogle() async {
        guard let client else { state = .error("Supabase configuration is required before sign-in can be enabled."); return }
        do {
            try await client.auth.signInWithOAuth(provider: .google, redirectTo: URL(string: "mosaic://login-callback"))
        } catch {
            state = .error("Could not start sign-in. Please try again.")
        }
    }

    func handleOpenURL(_ url: URL) async {
        guard let client else { return }
        do {
            try await client.auth.session(from: url)
            await restoreSession()
        } catch { state = .error("Sign-in could not be completed.") }
    }

    func signOut() async {
        guard let client else { state = .signedOut; return }
        do { try await client.auth.signOut() } catch { /* Local root flow remains signed out. */ }
        currentUser = nil; state = .signedOut
    }

    private func loadCurrentUser(accessToken: String) async throws {
        currentUser = try await api.request("/api/me", token: accessToken, as: CurrentUser.self)
    }
}

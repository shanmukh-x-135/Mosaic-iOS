import Foundation
import SwiftUI

/// Every server call a screen can make, as injectable functions. Views and
/// view models depend on this value rather than on `MosaicAPIClient` or the
/// session, so the shipped screens can also render DEBUG fixtures without any
/// network writes. The live value is a thin adapter over the existing client.
nonisolated struct MosaicServices {
    // Private, authenticated (`/api/me/*`).
    var continueItems: @MainActor () async throws -> [ContinueStory]
    var library: @MainActor () async throws -> [LibraryItemDTO]
    var activity: @MainActor (_ limit: Int) async throws -> [ProfileActivity]
    var stats: @MainActor () async throws -> ProfileStatsDTO
    var lists: @MainActor () async throws -> [UserList]
    var stateSnapshot: @MainActor () async throws -> MosaicStateSnapshot
    var seriesState: @MainActor (_ route: MediaDetailRoute) async throws -> SeriesPersonalState
    /// Applies one validated command. Callers refresh their own projections when
    /// `mosaicStateDidChange` is posted after success.
    var mutate: @MainActor (_ mutation: DetailMutation) async throws -> Void
    /// Replaces the signed-in user's editable profile (`PATCH /api/me/profile`).
    var updateProfile: @MainActor (_ update: ProfileUpdateRequest) async throws -> Profile

    // Public catalog.
    var discover: @MainActor (_ region: String?) async throws -> CatalogDiscoverResponse
    var genre: @MainActor (_ type: CatalogMediaType, _ genreID: Int) async throws -> CatalogSearchResponse
    var theme: @MainActor (_ themeID: String, _ type: CatalogMediaType?) async throws -> CatalogSearchResponse
    var related: @MainActor (_ route: MediaDetailRoute) async throws -> CatalogSearchResponse
    var search: @Sendable (_ query: String, _ filter: CatalogFilter) async throws -> CatalogSearchResponse
    var detail: @Sendable (_ route: MediaDetailRoute) async throws -> CatalogMedia
    var season: @Sendable (_ route: SeriesSeasonRoute) async throws -> CatalogSeasonResponse
}

extension MosaicServices {
    @MainActor static func live(session: SessionStore, client: MosaicAPIClient? = nil) -> MosaicServices {
        let client = client ?? MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL)
        func authed<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
            try await client.request(path, token: try await session.currentAccessToken(), as: type)
        }
        func encoded(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? value }
        return MosaicServices(
            continueItems: { try await authed("/api/me/continue?limit=8", as: ContinueResponseDTO.self).items.map(ContinueStory.init(dto:)) },
            library: { try await authed("/api/me/library", as: LibraryResponseDTO.self).items },
            activity: { limit in try await authed("/api/me/activity?limit=\(min(max(limit, 1), 100))", as: ProfileActivityResponse.self).items.values },
            stats: { try await authed("/api/me/stats") },
            lists: { try await authed("/api/me/lists", as: UserListsResponse.self).items.values },
            stateSnapshot: { try await authed("/api/me/state") },
            seriesState: { route in
                var components = URLComponents()
                components.queryItems = [URLQueryItem(name: "provider", value: route.provider), URLQueryItem(name: "providerId", value: route.providerID)]
                return try await authed("/api/me/series-state?\(components.percentEncodedQuery ?? "")")
            },
            mutate: { mutation in
                try await client.mutate(path: "/api/me/state", body: mutation, token: try await session.currentAccessToken())
                if let route = mutation.affectedRoute, route.mediaType == .tv { await SeriesPersonalStateCache.shared.invalidate(route) }
                // Region lives on the profile, not in the media state snapshot.
                if mutation.type == "settings.watchRegion" { await session.refreshCurrentUser(); MosaicStateInvalidation.postProfileChange() }
                MosaicStateInvalidation.post()
            },
            updateProfile: { update in
                let response: ProfileUpdateResponse = try await client.send(method: "PATCH", path: "/api/me/profile", body: update, token: try await session.currentAccessToken())
                await session.apply(profile: response.profile)
                MosaicStateInvalidation.postProfileChange()
                return response.profile
            },
            discover: { region in
                try await client.publicRequest(path: "/api/catalog/discover", queryItems: region.map { [URLQueryItem(name: "region", value: $0)] } ?? [], as: CatalogDiscoverResponse.self)
            },
            genre: { type, id in
                try await client.publicRequest(path: "/api/catalog/genres", queryItems: [URLQueryItem(name: "type", value: type.rawValue), URLQueryItem(name: "genre", value: String(id))], as: CatalogSearchResponse.self)
            },
            theme: { id, type in
                var items = [URLQueryItem(name: "theme", value: id)]
                if let type { items.append(URLQueryItem(name: "type", value: type.rawValue)) }
                return try await client.publicRequest(path: "/api/catalog/themes", queryItems: items, as: CatalogSearchResponse.self)
            },
            related: { route in
                try await client.publicRequest(path: "/api/catalog/\(route.provider)/\(route.mediaType.rawValue)/\(encoded(route.providerID))/related", as: CatalogSearchResponse.self)
            },
            search: { query, filter in
                var items = [URLQueryItem(name: "q", value: query)]
                if let type = filter.catalogType { items.append(URLQueryItem(name: "type", value: type)) }
                return try await client.publicRequest(path: "/api/catalog/search", queryItems: items, as: CatalogSearchResponse.self)
            },
            detail: { route in
                if let cached = await CatalogDetailCache.shared.value(for: route) { return cached }
                let media = try await client.publicRequest(path: route.catalogPath, as: CatalogMedia.self)
                await CatalogDetailCache.shared.store(media, for: route)
                return media
            },
            season: { route in
                if let cached = await SeriesSeasonCache.shared.episodes(for: route) { return CatalogSeasonResponse(episodes: cached) }
                let response = try await client.publicRequest(path: route.catalogPath, as: CatalogSeasonResponse.self)
                await SeriesSeasonCache.shared.store(response.episodes, for: route)
                return response
            }
        )
    }

    /// Used when no services were injected (e.g. a view rendered in isolation).
    static let unavailable: MosaicServices = {
        let failure = MosaicAPIError.unauthorized("Sign in to Mosaic.")
        return MosaicServices(
            continueItems: { throw failure }, library: { throw failure }, activity: { _ in throw failure }, stats: { throw failure },
            lists: { throw failure }, stateSnapshot: { throw failure }, seriesState: { _ in throw failure }, mutate: { _ in throw failure },
            updateProfile: { _ in throw failure },
            discover: { _ in throw failure }, genre: { _, _ in throw failure }, theme: { _, _ in throw failure }, related: { _ in throw failure },
            search: { _, _ in throw failure }, detail: { _ in throw failure }, season: { _ in throw failure }
        )
    }()
}

extension EnvironmentValues {
    @Entry var mosaicServices: MosaicServices = .unavailable
}

actor CatalogDetailCache {
    static let shared = CatalogDetailCache()
    private var values: [MediaDetailRoute: CatalogMedia] = [:]
    func value(for route: MediaDetailRoute) -> CatalogMedia? { values[route] }
    func store(_ media: CatalogMedia, for route: MediaDetailRoute) { values[route] = media }
}

/// A small loading state shared by simple read-only screens.
enum Loadable<Value> {
    case idle, loading, loaded(Value), failed(Error)
    var value: Value? { if case let .loaded(value) = self { value } else { nil } }
    var isLoading: Bool { if case .loading = self { true } else { false } }
}

/// The user-facing explanation for a failed read, shared by every screen.
enum MosaicErrorCopy {
    static func title(for error: Error, subject: String) -> String {
        switch error as? MosaicAPIError {
        case .unauthorized: "Your session needs attention"
        case .network, .timedOut: "Mosaic can’t reach the internet"
        case .decoding, .invalidResponse: "Mosaic couldn’t read \(subject)"
        default: "\(subject.prefix(1).uppercased() + subject.dropFirst()) is unavailable right now"
        }
    }
    static func message(for error: Error) -> String {
        switch error as? MosaicAPIError {
        case .unauthorized: "Sign in again from Profile → Settings, then retry."
        case .network: "Check your connection and try again."
        case .timedOut: "Mosaic took too long to respond. Try again."
        case .decoding, .invalidResponse: "Try again. If this continues, update Mosaic."
        default: "Nothing has been lost. Try again in a moment."
        }
    }
}

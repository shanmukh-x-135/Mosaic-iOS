import Foundation
import Observation

enum LibraryViewState: Equatable { case idle, loading, loaded, empty, error(LibraryErrorPresentation) }
enum LibraryErrorPresentation: Equatable {
    case offline, sessionExpired, unavailable, unreadable
    var title: String { switch self { case .offline: "Mosaic can’t reach the internet"; case .sessionExpired: "Your session needs attention"; case .unavailable: "Your Library is unavailable right now"; case .unreadable: "Mosaic couldn’t read your Library" } }
    var message: String { switch self { case .offline: "Check your connection and try again."; case .sessionExpired: "Return to Account and sign in again, then retry."; case .unavailable: "Try again in a moment."; case .unreadable: "Try again. If this continues, update Mosaic." } }
    static func from(_ error: Error) -> Self { switch error { case let error as MosaicAPIError: switch error { case .network: .offline; case .unauthorized: .sessionExpired; case .internalError, .providerUnavailable: .unavailable; default: .unreadable }; default: .unavailable } }
}

@MainActor @Observable
final class LibraryViewModel {
    private let request: @MainActor () async throws -> [LibraryItemDTO]
    private var task: Task<Void, Never>?
    private(set) var state: LibraryViewState = .idle
    private(set) var items: [LibraryItemDTO] = []
    var mediaFilter: LibraryMediaFilter = .all
    var sort: LibrarySort = .updated

    init(client: MosaicAPIClient, accessToken: @escaping @MainActor () async throws -> String) {
        request = { let token = try await accessToken(); return try await client.request("/api/me/library", token: token, as: LibraryResponseDTO.self).items }
    }
    init(request: @escaping @MainActor () async throws -> [LibraryItemDTO]) { self.request = request }
    var visibleItems: [LibraryItemDTO] {
        let filtered = mediaFilter.mediaType.map { type in items.filter { $0.mediaType == type } } ?? items
        switch sort {
        case .updated: return filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .title: return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .rating: return filtered.sorted { ($0.userRating ?? -1) > ($1.userRating ?? -1) }
        case .release: return filtered.sorted { ($0.releaseYear ?? -1) > ($1.releaseYear ?? -1) }
        }
    }
    func load(force: Bool = false) {
        guard task == nil, force || state == .idle else { return }
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }; defer { self.task = nil }
            do { self.items = try await self.request(); self.state = self.items.isEmpty ? .empty : .loaded }
            catch is CancellationError { self.state = .idle }
            catch { self.state = .error(LibraryErrorPresentation.from(error)) }
        }
    }
    func refresh() { load(force: true) }
}

import Foundation
import Observation

enum CatalogFilter: String, CaseIterable, Identifiable, Sendable {
    case all, movies, series, games, books

    var id: String { rawValue }
    var title: String {
        switch self { case .all: "All"; case .movies: "Movies"; case .series: "Series"; case .games: "Games"; case .books: "Books" }
    }
    var catalogType: String? {
        switch self { case .all: nil; case .movies: "movie"; case .series: "tv"; case .games: "game"; case .books: "book" }
    }
}

enum SearchViewState: Equatable {
    case noQuery
    case minimumQuery
    case loading
    case results([CatalogMedia], partialFailure: String?)
    case empty(partialFailure: String?)
    case error(SearchErrorPresentation)
}

enum SearchErrorPresentation: Equatable {
    case offline, unavailable, unreadable, invalidQuery

    var title: String {
        switch self { case .offline: "Mosaic can’t reach the internet"; case .unavailable: "Search is unavailable right now"; case .unreadable: "Mosaic couldn’t read these results"; case .invalidQuery: "Try a different search" }
    }
    var message: String {
        switch self { case .offline: "Check your connection and try again."; case .unavailable: "Try again in a moment."; case .unreadable: "Try again. If this continues, update Mosaic."; case .invalidQuery: "Use between 2 and 100 characters." }
    }
    static func from(_ error: Error) -> SearchErrorPresentation {
        switch error {
        case let error as MosaicAPIError:
            switch error {
            case .network: .offline
            case .providerUnavailable, .internalError: .unavailable
            case .validation: .invalidQuery
            case .decoding, .invalidResponse: .unreadable
            default: .unavailable
            }
        default: .unavailable
        }
    }
}

@MainActor @Observable
final class SearchViewModel {
    private let search: @Sendable (String, CatalogFilter) async throws -> CatalogSearchResponse
    private var searchTask: Task<Void, Never>?
    private var requestedKey: String?
    var query = "" { didSet { scheduleSearch() } }
    var filter: CatalogFilter = .all { didSet { scheduleSearch() } }
    private(set) var state: SearchViewState = .noQuery

    init(client: MosaicAPIClient) {
        search = { query, filter in
            func request(type: String?) async throws -> CatalogSearchResponse {
                var items = [URLQueryItem(name: "q", value: query)]
                if let type { items.append(URLQueryItem(name: "type", value: type)) }
                return try await client.publicRequest(path: "/api/catalog/search", queryItems: items, as: CatalogSearchResponse.self)
            }
            func result(for type: String) async -> Result<CatalogSearchResponse, Error> {
                do { return .success(try await request(type: type)) }
                catch { return .failure(error) }
            }

            guard filter == .all else { return try await request(type: filter.catalogType) }

            async let movies = result(for: "movie")
            async let series = result(for: "tv")
            async let games = result(for: "game")
            async let books = result(for: "book")
            let responses = await [("movies", movies), ("series", series), ("games", games), ("books", books)]

            var items = [CatalogMedia]()
            var failures = [CatalogFailure]()
            for response in responses {
                switch response.1 {
                case let .success(value):
                    items += value.items
                    failures += value.failures
                case .failure:
                    failures.append(CatalogFailure(provider: response.0, message: "This catalog source is unavailable."))
                }
            }
            return CatalogSearchResponse(items: items, failures: failures)
        }
    }

    init(search: @escaping @Sendable (String, CatalogFilter) async throws -> CatalogSearchResponse) {
        self.search = search
    }

    func retry() { requestedKey = nil; scheduleSearch() }

    private func scheduleSearch() {
        searchTask?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { state = .noQuery; requestedKey = nil; return }
        guard (2...100).contains(normalized.count) else { state = .minimumQuery; requestedKey = nil; return }
        let key = "\(filter.rawValue)|\(normalized.lowercased())"
        guard key != requestedKey else { return }
        requestedKey = key
        state = .loading
        searchTask = Task { [weak self, search] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                try Task.checkCancellation()
                let response = try await search(normalized, self?.filter ?? .all)
                try Task.checkCancellation()
                guard let self, self.requestedKey == key else { return }
                let warning = response.failures.isEmpty ? nil : "Some catalog sources are unavailable."
                self.state = response.items.isEmpty ? .empty(partialFailure: warning) : .results(response.items, partialFailure: warning)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.requestedKey == key else { return }
                self.state = .error(SearchErrorPresentation.from(error))
            }
        }
    }
}

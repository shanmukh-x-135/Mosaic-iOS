import Foundation
import Observation

enum HomeViewState: Equatable {
    case idle
    case loading
    case loaded([ContinueStory])
    case empty
    case error(HomeErrorPresentation)
}

enum HomeErrorPresentation: Equatable {
    case sessionExpired
    case offline
    case unavailable
    case unreadable

    var title: String {
        switch self {
        case .sessionExpired: "Your session needs attention"
        case .offline: "Mosaic can’t reach the internet"
        case .unavailable: "Your stories are unavailable right now"
        case .unreadable: "Mosaic couldn’t read your stories"
        }
    }

    var message: String {
        switch self {
        case .sessionExpired: "Return to Profile and sign in again, then retry."
        case .offline: "Check your connection and try again."
        case .unavailable: "Try again in a moment."
        case .unreadable: "Try again. If this continues, update Mosaic."
        }
    }

    static func from(_ error: Error) -> HomeErrorPresentation {
        switch error {
        case is CancellationError: .offline
        case let error as MosaicAPIError:
            switch error {
            case .unauthorized: .sessionExpired
            case .network: .offline
            case .providerUnavailable, .internalError: .unavailable
            case .decoding, .invalidResponse: .unreadable
            default: .unavailable
            }
        default: .unavailable
        }
    }
}

@MainActor @Observable
final class HomeViewModel {
    private let requestStories: @MainActor () async throws -> [ContinueStory]
    private var loadTask: Task<Void, Never>?
    private(set) var state: HomeViewState = .idle

    init(client: MosaicAPIClient, accessToken: @escaping @MainActor () async throws -> String) {
        requestStories = {
            let token = try await accessToken()
            let response = try await client.request("/api/me/continue?limit=8", token: token, as: ContinueResponseDTO.self)
            return response.items.map(ContinueStory.init(dto:))
        }
    }

    init(requestStories: @escaping @MainActor () async throws -> [ContinueStory]) {
        self.requestStories = requestStories
    }

    func load() {
        guard loadTask == nil else { return }
        state = .loading
        loadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.loadTask = nil }
            do {
                let stories = try await self.requestStories()
                self.state = stories.isEmpty ? .empty : .loaded(stories)
            } catch is CancellationError {
                self.state = .idle
            } catch {
                self.state = .error(HomeErrorPresentation.from(error))
            }
        }
    }

    func retry() { load() }
}

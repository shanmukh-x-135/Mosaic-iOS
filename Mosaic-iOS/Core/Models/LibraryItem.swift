import Foundation

struct LibraryResponseDTO: Decodable, Sendable { let items: [LibraryItemDTO] }

struct LibraryItemDTO: Identifiable, Decodable, Equatable, Sendable {
    let id: String
    let mediaType: CatalogMediaType
    let provider: String
    let providerID: String
    let title: String
    let posterURL: URL?
    let backdropURL: URL?
    let releaseYear: Int?
    let status: String
    let userRating: Double?
    let isFavorite: Bool
    let updatedAt: Date
    let progress: LibraryProgressDTO?

    private enum CodingKeys: String, CodingKey {
        case id, mediaType, provider, providerID = "providerId", title, releaseYear, status, userRating, isFavorite, updatedAt, progress
        case posterURL = "posterUrl", backdropURL = "backdropUrl"
    }

    var route: MediaDetailRoute { MediaDetailRoute(provider: provider, mediaType: mediaType, providerID: providerID) }
    var artworkURL: URL? { posterURL ?? backdropURL }
    var statusLabel: String { status.replacingOccurrences(of: "_", with: " ").capitalized }
    var ratingText: String? { userRating.map { "\($0.formatted(.number.precision(.fractionLength(1)))) ★" } }
}

struct LibraryProgressDTO: Decodable, Equatable, Sendable {
    let watchedEpisodes: Int?
    let totalEpisodes: Int?
    let currentPage: Int?
    let totalPages: Int?
    let playtimeMinutes: Int?
    let percent: Double?

    var displayText: String? {
        if let watchedEpisodes, watchedEpisodes > 0 { return totalEpisodes.map { "\(watchedEpisodes) / \($0) episodes" } ?? "\(watchedEpisodes) episodes" }
        if let currentPage, currentPage > 0 { return totalPages.map { "\(currentPage) / \($0) pages" } ?? "Page \(currentPage)" }
        if let playtimeMinutes, playtimeMinutes > 0 { let hours = playtimeMinutes / 60; return hours > 0 ? "\(hours)h played" : "\(playtimeMinutes)m played" }
        if let percent, percent > 0 { return "\(Int(percent.rounded()))%" }
        return nil
    }
}

enum LibraryMediaFilter: String, CaseIterable, Identifiable, Sendable {
    case all, movies, series, games, books
    var id: String { rawValue }
    var title: String { switch self { case .all: "All"; case .movies: "Movies"; case .series: "Series"; case .games: "Games"; case .books: "Books" } }
    var mediaType: CatalogMediaType? { switch self { case .all: nil; case .movies: .movie; case .series: .tv; case .games: .game; case .books: .book } }
}

enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case updated, title, rating, release
    var id: String { rawValue }
    var title: String { switch self { case .updated: "Recently updated"; case .title: "Title A–Z"; case .rating: "Your rating"; case .release: "Release date" } }
}

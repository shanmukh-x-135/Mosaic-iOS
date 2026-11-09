import Foundation

nonisolated struct LibraryResponseDTO: Decodable, Sendable { let items: [LibraryItemDTO] }

nonisolated struct LibraryItemDTO: Identifiable, Decodable, Hashable, Sendable {
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
    /// The persisted playthrough/reading this entry reports progress for, when
    /// one exists. Logging must update this record instead of starting a new one.
    let progressID: String?
    /// Number of logged movie watches. Movies have no `progress` object.
    let watchCount: Int?
    let progress: LibraryProgressDTO?

    private enum CodingKeys: String, CodingKey {
        case id, mediaType, provider, providerID = "providerId", title, releaseYear, status, userRating, isFavorite, updatedAt, progress
        case posterURL = "posterUrl", backdropURL = "backdropUrl", progressID = "progressId", watchCount
    }

    var route: MediaDetailRoute { MediaDetailRoute(provider: provider, mediaType: mediaType, providerID: providerID) }
    var mediaKey: String { "\(provider):\(mediaType.rawValue):\(providerID)" }
    var artworkURL: URL? { posterURL ?? backdropURL }
    var libraryStatus: LibraryStatus? { LibraryStatus(rawValue: status) }
    var statusLabel: String { LibraryStatus.label(for: status) }
    var ratingText: String? { userRating.map { "★ \(UserRating.format($0))" } }

    /// One honest line of progress per medium, built only from stored fields
    /// (`progressFor` in the web `library-card.tsx`).
    var progressLine: (text: String, fraction: Double?)? {
        if mediaType == .movie {
            guard let watchCount, watchCount > 0 else { return nil }
            return ("\(watchCount) \(watchCount == 1 ? "watch" : "watches") logged", nil)
        }
        guard let progress else { return nil }
        let fraction = progress.percent.flatMap { $0 > 0 ? min($0 / 100, 1) : nil }
        switch mediaType {
        case .movie:
            return nil
        case .tv:
            guard let watched = progress.watchedEpisodes, watched > 0 else { return nil }
            var text = "\(watched)\(progress.totalEpisodes.map { " / \($0)" } ?? "") episodes"
            if libraryStatus == .watching, let season = progress.nextSeasonNumber, let episode = progress.nextEpisodeNumber {
                text += " · next \(EpisodeCode.format(season: season, episode: episode))"
            }
            return (text, fraction)
        case .book:
            if let current = progress.currentPage, current > 0, let total = progress.totalPages { return ("Page \(current) of \(total)", fraction) }
            if let percent = progress.percent, percent > 0 { return ("\(Int(percent.rounded()))% read", fraction) }
            return nil
        case .game:
            let parts = [progress.percent.flatMap { $0 > 0 ? "\(Int($0.rounded()))%" : nil }, progress.playtimeMinutes.flatMap { $0 > 0 ? "\(MosaicDuration.playtime($0)) recorded" : nil }].compactMap { $0 }
            return parts.isEmpty ? nil : (parts.joined(separator: " · "), fraction)
        }
    }
}

nonisolated struct LibraryProgressDTO: Decodable, Hashable, Sendable {
    let watchedEpisodes: Int?
    let totalEpisodes: Int?
    let currentPage: Int?
    let totalPages: Int?
    let playtimeMinutes: Int?
    let percent: Double?
    let nextSeasonNumber: Int?
    let nextEpisodeNumber: Int?
    /// The platform recorded on a game playthrough.
    let platform: String?
}

nonisolated enum LibraryMediaFilter: String, CaseIterable, Identifiable, Sendable {
    case all, movies, series, games, books
    var id: String { rawValue }
    var title: String { switch self { case .all: "All"; case .movies: "Movies"; case .series: "Series"; case .games: "Games"; case .books: "Books" } }
    var mediaType: CatalogMediaType? { switch self { case .all: nil; case .movies: .movie; case .series: .tv; case .games: .game; case .books: .book } }
}

nonisolated enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case updated, title, rating, release
    var id: String { rawValue }
    var title: String { switch self { case .updated: "Recently updated"; case .title: "Title A–Z"; case .rating: "Your rating"; case .release: "Release year" } }
}

nonisolated enum LibraryLayout: String, CaseIterable, Identifiable, Sendable {
    case grid, list
    var id: String { rawValue }
    var title: String { self == .grid ? "Grid" : "List" }
    var systemImage: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

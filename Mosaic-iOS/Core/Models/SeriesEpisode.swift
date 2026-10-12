import Foundation

/// Provider-qualified identities keep Season and Episode navigation independent
/// from localized titles and from any provider-specific integer assumptions.
nonisolated struct SeriesSeasonRoute: Hashable, Sendable {
    let provider: String
    let seriesProviderID: String
    let seasonNumber: Int

    init(provider: String, seriesProviderID: String, seasonNumber: Int) {
        self.provider = provider
        self.seriesProviderID = seriesProviderID
        self.seasonNumber = seasonNumber
    }

    init(series: CatalogMedia, seasonNumber: Int) {
        self.init(provider: series.provider, seriesProviderID: series.providerID, seasonNumber: seasonNumber)
    }

    var catalogPath: String { "/api/catalog/\(provider)/tv/\(seriesProviderID)/season/\(seasonNumber)" }
}

nonisolated struct SeriesEpisodeRoute: Hashable, Sendable {
    let season: SeriesSeasonRoute
    let episodeNumber: Int

    init(season: SeriesSeasonRoute, episodeNumber: Int) {
        self.season = season
        self.episodeNumber = episodeNumber
    }
}

nonisolated struct CatalogSeasonResponse: Decodable, Sendable {
    let episodes: [CatalogEpisode]
}

nonisolated struct CatalogEpisode: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let overview: String?
    let stillURL: URL?
    let airDate: String?
    let runtimeMinutes: Int?
    let publicRating: Double?
    let publicRatingCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, seasonNumber, episodeNumber, title, overview, airDate, runtimeMinutes, publicRating, publicRatingCount
        case stillURL = "stillUrl"
    }
}

actor SeriesSeasonCache {
    static let shared = SeriesSeasonCache()
    private var values: [SeriesSeasonRoute: [CatalogEpisode]] = [:]

    func episodes(for route: SeriesSeasonRoute) -> [CatalogEpisode]? { values[route] }
    func store(_ episodes: [CatalogEpisode], for route: SeriesSeasonRoute) { values[route] = episodes }
    func invalidate(_ route: SeriesSeasonRoute) { values[route] = nil }
}

nonisolated struct SeriesPersonalState: Decodable, Equatable, Sendable {
    let status: String?
    let isFavorite: Bool
    let userRating: Double?
    let episodes: [WatchedEpisode]
    let seasons: [PersonalSeasonState]

    struct WatchedEpisode: Decodable, Equatable, Hashable, Sendable {
        let seasonNumber: Int
        let episodeNumber: Int
        let watchedAt: Date
        let rating: Double?
    }

    struct PersonalSeasonState: Decodable, Equatable, Sendable {
        let seasonNumber: Int
        let state: String
        let completedOn: String?
        let updatedAt: Date
    }

    var watchedCoordinates: Set<String> { Set(episodes.map { "\($0.seasonNumber):\($0.episodeNumber)" }) }
    func watched(_ episode: CatalogEpisode) -> Bool { watchedCoordinates.contains("\(episode.seasonNumber):\(episode.episodeNumber)") }
}

actor SeriesPersonalStateCache {
    static let shared = SeriesPersonalStateCache()
    private var values: [MediaDetailRoute: SeriesPersonalState] = [:]

    func value(for route: MediaDetailRoute) -> SeriesPersonalState? { values[route] }
    func store(_ state: SeriesPersonalState, for route: MediaDetailRoute) { values[route] = state }
    func invalidate(_ route: MediaDetailRoute) { values[route] = nil }
}

import Foundation

nonisolated struct CatalogSearchResponse: Decodable, Sendable {
    let items: [CatalogMedia]
    let failures: [CatalogFailure]
}

nonisolated struct CatalogDiscoverResponse: Decodable, Sendable {
    let items: [CatalogMedia]
    let failures: [CatalogFailure]
    let sections: [CatalogDiscoverySection]
}

nonisolated struct CatalogDiscoverySection: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let label: String
    let mediaType: CatalogMediaType
    let items: [CatalogMedia]
}

nonisolated struct CatalogFailure: Decodable, Hashable, Sendable {
    let provider: String
    let message: String

    init(provider: String, message: String) {
        self.provider = provider
        self.message = message
    }
}

/// The documented provider-normalized catalog union. Type-specific properties
/// are omitted by the API when they are not meaningful for a media domain.
nonisolated struct CatalogMedia: Identifiable, Codable, Hashable, Sendable {
    let provider: String
    let providerID: String
    let mediaType: CatalogMediaType
    let title: String
    let originalTitle: String?
    let description: String?
    let posterURL: URL?
    let backdropURL: URL?
    let releaseDate: String?
    let releaseYear: Int?
    let genres: [String]
    let communityRating: Double?
    let communityRatingCount: Int?

    let runtimeMinutes: Int?
    let director: String?
    let studio: String?
    let studioLogoURL: URL?

    let seasonCount: Int?
    let episodeCount: Int?
    let seasonNumbers: [Int]?
    let seasonEpisodeCounts: [String: Int]?
    let eligibleEpisodeCounts: [String: Int]?
    let eligibleEpisodeCount: Int?
    let network: String?
    let networkLogoURL: URL?

    let platforms: [String]?
    let developer: String?
    let publisher: String?

    let subtitle: String?
    let authors: [String]?
    let pageCount: Int?
    let isbn: String?

    private enum CodingKeys: String, CodingKey {
        case provider, providerID = "providerId", mediaType, title, originalTitle, description
        case posterURL = "posterUrl", backdropURL = "backdropUrl", releaseDate, releaseYear, genres, communityRating, communityRatingCount
        case runtimeMinutes, director, studio, studioLogoURL = "studioLogoUrl"
        case seasonCount, episodeCount, seasonNumbers, seasonEpisodeCounts, eligibleEpisodeCounts, eligibleEpisodeCount, network, networkLogoURL = "networkLogoUrl"
        case platforms, developer, publisher, subtitle, authors, pageCount, isbn
    }

    var id: MediaDetailRoute { route }
    /// Provider-qualified identity, `provider:mediaType:providerId` (web `mediaKey`).
    var mediaKey: String { "\(provider):\(mediaType.rawValue):\(providerID)" }
    var route: MediaDetailRoute { MediaDetailRoute(provider: provider, mediaType: mediaType, providerID: providerID) }
    var artworkURL: URL? { backdropURL ?? posterURL }

    var releaseContext: String? {
        if let releaseYear { return String(releaseYear) }
        return releaseDate
    }

    var resultMetadata: String {
        var values: [String] = []
        if let releaseYear { values.append(String(releaseYear)) }
        if mediaType == .book, let authors, !authors.isEmpty { values.append(authors.joined(separator: ", ")) }
        else if mediaType == .game, let platforms, let platform = platforms.first { values.append(platform) }
        else if let genre = genres.first { values.append(genre) }
        return values.joined(separator: " · ")
    }
}

nonisolated extension CatalogMedia {
    /// The identity of an already-tracked Library entry, valid for the shared
    /// mutation schema. The server resolves an existing `media_items` row by
    /// provider identity and never overwrites its stored snapshot
    /// (`upsertMedia`), so this thin value cannot erase catalog metadata.
    init(identity item: LibraryItemDTO) {
        self.init(
            provider: item.provider, providerID: item.providerID, mediaType: item.mediaType, title: item.title,
            originalTitle: nil, description: nil, posterURL: item.posterURL, backdropURL: item.backdropURL,
            releaseDate: nil, releaseYear: item.releaseYear, genres: [], communityRating: nil, communityRatingCount: nil,
            runtimeMinutes: nil, director: nil, studio: nil, studioLogoURL: nil,
            seasonCount: nil, episodeCount: nil, seasonNumbers: nil, seasonEpisodeCounts: nil, eligibleEpisodeCounts: nil, eligibleEpisodeCount: nil, network: nil, networkLogoURL: nil,
            platforms: item.mediaType == .game ? [] : nil, developer: nil, publisher: nil,
            subtitle: nil, authors: item.mediaType == .book ? [] : nil, pageCount: nil, isbn: nil
        )
    }
}

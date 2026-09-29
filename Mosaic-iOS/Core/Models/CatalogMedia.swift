import Foundation

struct CatalogSearchResponse: Decodable, Sendable {
    let items: [CatalogMedia]
    let failures: [CatalogFailure]
}

struct CatalogFailure: Decodable, Equatable, Sendable {
    let provider: String
    let message: String

    init(provider: String, message: String) {
        self.provider = provider
        self.message = message
    }
}

/// The documented provider-normalized catalog union. Type-specific properties
/// are omitted by the API when they are not meaningful for a media domain.
struct CatalogMedia: Identifiable, Decodable, Equatable, Sendable {
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

    let runtimeMinutes: Int?
    let director: String?
    let studio: String?
    let studioLogoURL: URL?

    let seasonCount: Int?
    let episodeCount: Int?
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
        case posterURL = "posterUrl", backdropURL = "backdropUrl", releaseDate, releaseYear, genres, communityRating
        case runtimeMinutes, director, studio, studioLogoURL = "studioLogoUrl"
        case seasonCount, episodeCount, network, networkLogoURL = "networkLogoUrl"
        case platforms, developer, publisher, subtitle, authors, pageCount, isbn
    }

    var id: MediaDetailRoute { route }
    var route: MediaDetailRoute { MediaDetailRoute(provider: provider, mediaType: mediaType, providerID: providerID) }
    var artworkURL: URL? { backdropURL ?? posterURL }

    var releaseContext: String? {
        if let releaseYear { return String(releaseYear) }
        return releaseDate
    }

    var resultMetadata: String {
        var values = [mediaType.displayName]
        if let releaseContext { values.append(releaseContext) }
        if mediaType == .book, let authors, !authors.isEmpty { values.append(authors.joined(separator: ", ")) }
        else if mediaType == .game, let platforms, let platform = platforms.first { values.append(platform) }
        else if let genre = genres.first { values.append(genre) }
        return values.joined(separator: " · ")
    }
}

import Foundation

/// A provider-qualified catalog identity. This deliberately carries no title- or
/// artwork-derived lookup data: catalog detail routes must always address the
/// server with the stable identity it supplied.
struct MediaDetailRoute: Hashable, Sendable {
    let provider: String
    let mediaType: CatalogMediaType
    let providerID: String

    init(provider: String, mediaType: CatalogMediaType, providerID: String) {
        self.provider = provider
        self.mediaType = mediaType
        self.providerID = providerID
    }

    var catalogPath: String {
        "/api/catalog/\(provider)/\(mediaType.catalogPathComponent)/\(providerID)"
    }
}

enum CatalogMediaType: String, Hashable, Decodable, Sendable {
    case movie
    case tv
    case game
    case book

    var catalogPathComponent: String { rawValue }

    var displayName: String { self == .tv ? "Series" : rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .movie: "film"
        case .tv: "tv"
        case .game: "gamecontroller"
        case .book: "book.closed"
        }
    }
}

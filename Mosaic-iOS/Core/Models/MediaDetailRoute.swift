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

enum CatalogMediaType: String, Hashable, Sendable {
    case movie
    case series
    case game
    case book

    /// The catalog contract calls television series `tv` in URL paths.
    var catalogPathComponent: String { self == .series ? "tv" : rawValue }

    var displayName: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .movie: "film"
        case .series: "tv"
        case .game: "gamecontroller"
        case .book: "book.closed"
        }
    }
}

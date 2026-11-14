import Foundation

nonisolated enum MosaicMediaType: String, Decodable, Sendable {
    case movie, series, game, book
    var catalogMediaType: CatalogMediaType { self == .series ? .tv : CatalogMediaType(rawValue: rawValue)! }
}

nonisolated struct MosaicPeriod: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable { case all, year, month }
    let kind: Kind
    let label: String
    let year: Int?
    let month: Int?
}

nonisolated struct MosaicMediaCounts: Decodable, Sendable { let movie, series, game, book: Int }

nonisolated struct MosaicTile: Decodable, Identifiable, Sendable {
    struct Activity: Decodable, Sendable {
        let firstActivityAt, lastActivityAt: String?
        let eventCount: Int
        let progress: Double?
        let completed: Bool?
    }
    struct UserSignals: Decodable, Sendable { let rating: Double?; let favorite: Bool?; let rewatchCount: Int? }
    struct ProviderMetadata: Decodable, Sendable { let year: Int?; let genres: [String]? }
    let key: String
    let mediaType: MosaicMediaType
    let providerID: String
    let title: String
    let artwork: URL?
    let href: String
    let activity: Activity
    let userSignals: UserSignals
    let providerMetadata: ProviderMetadata
    let visualWeight: Double
    private enum CodingKeys: String, CodingKey {
        case key, mediaType, title, artwork, href, activity, userSignals, providerMetadata, visualWeight
        case providerID = "providerId"
    }
    var id: String { key }
    var catalogMediaType: CatalogMediaType { mediaType.catalogMediaType }
    var route: MediaDetailRoute? {
        let parts = key.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, !parts[0].isEmpty, !parts[2].isEmpty,
              let type = CatalogMediaType(rawValue: String(parts[1])) else { return nil }
        return MediaDetailRoute(provider: String(parts[0]), mediaType: type, providerID: String(parts[2]))
    }
}

nonisolated struct MosaicSnapshot: Decodable, Sendable {
    struct Totals: Decodable, Sendable {
        let storiesRepresented: Int
        let byMediaType: MosaicMediaCounts
        let movieWatchLogs: Int
    }
    let period: MosaicPeriod
    let generatedAt: String
    let totals: Totals
    let tiles: [MosaicTile]
}

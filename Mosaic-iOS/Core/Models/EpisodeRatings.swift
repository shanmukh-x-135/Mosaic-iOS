import Foundation

nonisolated struct EpisodeRatings: Decodable, Sendable {
    let seasons: [[CatalogEpisode]]
}

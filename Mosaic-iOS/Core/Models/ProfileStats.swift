import Foundation

nonisolated struct StatsPeriod: Decodable, Sendable {
    enum Kind: String, Decodable, Sendable { case all, year }
    let kind: Kind
    let year: Int?
}
nonisolated struct CountedMedia: Decodable, Sendable { let media: CatalogMedia; let count: Int }
nonisolated struct ActivityBucket: Decodable, Sendable { let key, label: String; let count: Int }
nonisolated struct ActivitySeries: Decodable, Sendable {
    enum Granularity: String, Decodable, Sendable { case month, year }
    let unit: String
    let granularity: Granularity
    let buckets: [ActivityBucket]
    let total: Int
    let peak: ActivityBucket?
    let weekdays: [Int]
}
nonisolated struct StatsByMedium<Value: Decodable & Sendable>: Decodable, Sendable { let movie, series, game, book: Value }

nonisolated struct ProfileStatsResponse: Decodable, Sendable { let stats: ProfileStats; let years: [Int] }

nonisolated struct ProfileStats: Decodable, Sendable {
    struct Movie: Decodable, Sendable {
        let watchLogs, uniqueTitles, rewatchLogs: Int
        let recent: [CatalogMedia]
        let mostRewatched: CountedMedia?
    }
    struct SeriesStatus: Decodable, Sendable { let watching, paused, completed, dropped, watchlist: Int }
    struct Series: Decodable, Sendable {
        let episodeLogs, uniqueEpisodes, rewatchLogs, shows: Int
        let recent: [CatalogMedia]
        let mostLogged: [CountedMedia]
        let status: SeriesStatus
    }
    struct GameStatus: Decodable, Sendable { let playing, paused, completed, dropped, backlog: Int }
    struct Game: Decodable, Sendable {
        let completedPlaythroughs: Int
        let statuses: GameStatus
        let recordedPlaytimeMinutes: Int
        let completed: [CatalogMedia]
    }
    struct BookStatus: Decodable, Sendable {
        let reading, paused, finished, dnf, wantToRead: Int
        // JSONDecoder.mosaic converts the wire key `want_to_read` before matching CodingKeys.
        private enum CodingKeys: String, CodingKey { case reading, paused, finished, dnf, wantToRead }
    }
    struct NamedCount: Decodable, Sendable { let name: String; let count: Int }
    struct Book: Decodable, Sendable {
        let finished: Int
        let statuses: BookStatus
        let finishedTitles: [CatalogMedia]
        let authors: [NamedCount]
    }
    struct RatingCount: Decodable, Sendable { let count: Int; let average: Double? }
    struct RatingBucket: Decodable, Sendable { let value: Double; let count: Int }
    struct RatedMedia: Decodable, Sendable { let media: CatalogMedia; let value: Double }
    struct Ratings: Decodable, Sendable {
        enum Population: String, Decodable, Sendable { case all; case loggedInPeriod = "logged-in-period" }
        let population: Population
        let count: Int
        let average: Double?
        let distribution: [RatingBucket]
        let byMedium: StatsByMedium<RatingCount>
        let top: [RatedMedia]
    }
    struct Genre: Decodable, Sendable { let titles, withGenres: Int; let top: [NamedCount] }
    struct Activity: Decodable, Sendable { let movie, series: ActivitySeries }
    let period: StatsPeriod
    let movie: Movie
    let series: Series
    let game: Game
    let book: Book
    let ratings: Ratings
    let genres: StatsByMedium<Genre>
    let activity: Activity
}

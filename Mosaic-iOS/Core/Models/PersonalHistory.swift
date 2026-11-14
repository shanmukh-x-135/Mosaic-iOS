import Foundation

/// Decodes an array, skipping any element that does not match the expected
/// shape, so one legacy row never hides a user's whole history.
nonisolated struct LossyArray<Element: Decodable>: Decodable {
    let values: [Element]
    init(_ values: [Element]) { self.values = values }
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values: [Element] = []
        while !container.isAtEnd {
            if let value = try? container.decode(Element.self) { values.append(value) }
            else { _ = try? container.decode(SkippedElement.self) }
        }
        self.values = values
    }
    private struct SkippedElement: Decodable {}
}

// MARK: - Activity (`GET /api/me/activity`)

nonisolated struct ProfileActivityResponse: Decodable { let items: LossyArray<ProfileActivity> }

nonisolated struct ProfileActivity: Decodable, Identifiable, Hashable {
    struct Episode: Decodable, Hashable { let seasonNumber: Int; let episodeNumber: Int; let title: String? }
    let eventID: String
    let media: CatalogMedia
    let occurredAt: Date
    let eventType: String
    let targetType: String?
    let rating: Double?
    let repeatKind: String?
    let detail: String?
    let episode: Episode?
    let seasonNumber: Int?
    let progressPercent: Double?

    private enum CodingKeys: String, CodingKey { case eventID = "eventId", media, occurredAt, eventType, targetType, rating, repeatKind, detail, episode, seasonNumber, progressPercent }
    var id: String { eventID }

    var label: String {
        ActivityLabel.text(eventType: eventType, repeatKind: repeatKind, targetType: targetType, seasonNumber: seasonNumber, episode: episode.map { ($0.seasonNumber, $0.episodeNumber) }, progressPercent: progressPercent)
    }
}

// MARK: - Stats (`GET /api/me/stats`)

nonisolated struct ProfileStatsDTO: Decodable {
    struct MediaMix: Decodable { let movie, tv, game, book: Int }
    struct Movie: Decodable { let watches, rewatches, uniqueMovies: Int }
    struct TV: Decodable { let uniqueEpisodesWatched, episodeWatchLogs, episodeRewatches, completedSeasons, showsInProgress: Int }
    struct Game: Decodable { let completedPlaythroughs, playtimeMinutes: Int }
    struct Book: Decodable { let finished, pagesRead: Int }
    let mediaMix: MediaMix
    let movie: Movie
    let tv: TV
    let game: Game
    let book: Book
}

// MARK: - Lists (`GET /api/me/lists`)

nonisolated struct UserListsResponse: Decodable { let items: LossyArray<UserList> }

nonisolated struct UserList: Decodable, Identifiable, Hashable {
    struct Item: Decodable, Identifiable, Hashable {
        let id: String
        let media: CatalogMedia
        let position: Int
        let note: String?
    }
    enum Visibility: String, Decodable, Hashable {
        case `public`, unlisted, `private`
        var label: String { switch self { case .public: "Public"; case .unlisted: "Unlisted"; case .private: "Private" } }
        var systemImage: String { switch self { case .public: "globe"; case .unlisted: "link"; case .private: "lock" } }
    }
    let id: String
    let title: String
    let description: String
    let visibility: Visibility
    let items: [Item]
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey { case id, title, description, visibility, items, updatedAt }
    init(id: String, title: String, description: String, visibility: Visibility, items: [Item], updatedAt: Date) {
        self.id = id; self.title = title; self.description = description; self.visibility = visibility; self.items = items; self.updatedAt = updatedAt
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        visibility = try container.decode(Visibility.self, forKey: .visibility)
        items = try container.decode(LossyArray<Item>.self, forKey: .items).values
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    /// List order is the item `position`, the same order the web shows.
    var orderedItems: [Item] { items.sorted { $0.position < $1.position } }
    var mediaTypes: [CatalogMediaType] {
        var seen: [CatalogMediaType] = []
        for item in orderedItems where !seen.contains(item.media.mediaType) { seen.append(item.media.mediaType) }
        return seen
    }
}

// MARK: - Personal records from the state snapshot (`GET /api/me/state`)

/// Personal state returned by both GET and POST `/api/me/state`.
/// Arrays decode independently and skip malformed legacy rows.
nonisolated struct MosaicStateSnapshot: Decodable {
    struct LibraryRow: Decodable {
        let media: CatalogMedia
        let status: String
        var isFavorite: Bool = false
        var updatedAt: String = ""
    }
    struct MovieWatch: Decodable {
        let media: CatalogMedia
        let watchedAt: String
        var id: String = ""
        var isRewatch: Bool = false
        var rating: Double? = nil
        var review: String? = nil
        var viewingContext: String? = nil
        var streamingService: String? = nil
    }
    struct EpisodeWatch: Decodable {
        let series: CatalogMedia
        let watchedAt: String
        var id: String = ""
        var seasonNumber: Int = 0
        var episodeNumber: Int = 0
        var episodeTitle: String? = nil
        var rating: Double? = nil
        var isRewatch: Bool? = nil
    }
    struct Rating: Decodable { let mediaKey: String; let value: Double }
    struct Review: Decodable, Identifiable {
        let id: String
        let media: CatalogMedia
        let body: String
        let containsSpoilers: Bool
        let rating: Double?
        let updatedAt: String
    }
    struct SeasonStateRow: Decodable, Identifiable {
        let id: String
        let series: CatalogMedia
        let seasonNumber: Int
        let state: String
        let provenance: String
        let completedOn: String?
        let updatedAt: String
    }
    struct TVHistoryRow: Decodable, Identifiable {
        let id: String
        let series: CatalogMedia
        let targetType: String
        let seasonNumber: Int?
        let occurredAt: String
        let isRewatch: Bool
        let rating: Double?
        let review: String?
        let containsSpoilers: Bool
        let tags: [String]
    }

    let watchRegion: String?
    let library: [LibraryRow]
    let ratings: [Rating]
    let reviews: [Review]
    let lists: [UserList]
    let movieWatches: [MovieWatch]
    let episodeWatches: [EpisodeWatch]
    let seasonStates: [SeasonStateRow]
    let tvHistory: [TVHistoryRow]
    let gamePlaythroughs: [GamePlaythrough]
    let bookReadings: [BookReading]

    private enum CodingKeys: String, CodingKey { case watchRegion, library, ratings, reviews, lists, movieWatches, episodeWatches, seasonStates, tvHistory, gamePlaythroughs, bookReadings }
    init(watchRegion: String? = nil, library: [LibraryRow] = [], ratings: [Rating] = [], reviews: [Review] = [], lists: [UserList] = [], movieWatches: [MovieWatch] = [], episodeWatches: [EpisodeWatch] = [], seasonStates: [SeasonStateRow] = [], tvHistory: [TVHistoryRow] = [], gamePlaythroughs: [GamePlaythrough] = [], bookReadings: [BookReading] = []) {
        self.watchRegion = watchRegion; self.library = library; self.ratings = ratings; self.reviews = reviews; self.lists = lists
        self.movieWatches = movieWatches; self.episodeWatches = episodeWatches; self.seasonStates = seasonStates; self.tvHistory = tvHistory
        self.gamePlaythroughs = gamePlaythroughs; self.bookReadings = bookReadings
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func lossy<T: Decodable>(_ key: CodingKeys) -> [T] { (try? container.decodeIfPresent(LossyArray<T>.self, forKey: key))??.values ?? [] }
        watchRegion = try container.decodeIfPresent(String.self, forKey: .watchRegion)
        library = lossy(.library); ratings = lossy(.ratings); reviews = lossy(.reviews); lists = lossy(.lists)
        movieWatches = lossy(.movieWatches); episodeWatches = lossy(.episodeWatches)
        seasonStates = lossy(.seasonStates); tvHistory = lossy(.tvHistory)
        gamePlaythroughs = lossy(.gamePlaythroughs); bookReadings = lossy(.bookReadings)
    }

    /// The record an update should edit: the most recently updated one, the
    /// same record `LibraryEntry.progress` reports.
    func playthrough(for media: CatalogMedia) -> GamePlaythrough? {
        gamePlaythroughs.filter { $0.media.mediaKey == media.mediaKey }.max { $0.updatedAt < $1.updatedAt }
    }
    func reading(for media: CatalogMedia) -> BookReading? {
        bookReadings.filter { $0.media.mediaKey == media.mediaKey }.max { $0.updatedAt < $1.updatedAt }
    }
    func reviews(for media: CatalogMedia) -> Review? {
        reviews.filter { $0.media.mediaKey == media.mediaKey }.max { $0.updatedAt < $1.updatedAt }
    }
    func movieWatches(for media: CatalogMedia) -> [MovieWatch] {
        movieWatches.filter { $0.media.mediaKey == media.mediaKey }.sorted { $0.watchedAt > $1.watchedAt }
    }
    func list(id: String) -> UserList? { lists.first { $0.id == id } }
}

nonisolated struct GamePlaythrough: Decodable, Hashable {
    let id: String
    let media: CatalogMedia
    let status: String
    let platform: String?
    let playtimeMinutes: Int
    let progressPercent: Double?
    let rating: Double?
    let updatedAt: String
}

nonisolated struct BookReading: Decodable, Hashable {
    let id: String
    let media: CatalogMedia
    let status: String
    let currentPage: Int?
    let totalPages: Int?
    let progressPercent: Double?
    let rating: Double?
    let updatedAt: String
}

// MARK: - Recommendations ("Because you watched")

/// `recommendationSeeds` / `buildRecommendations` in `src/lib/media/recommendations.ts`.
nonisolated enum Recommendations {
    static let maxSeeds = 3
    static let perSeed = 12
    static let dislikedAtOrBelow = 2.0

    static func seeds(from snapshot: MosaicStateSnapshot, type: CatalogMediaType?) -> [CatalogMedia] {
        if type == .game || type == .book { return [] }
        let disliked = Set(snapshot.ratings.filter { $0.value <= dislikedAtOrBelow }.map(\.mediaKey))
        typealias Event = (media: CatalogMedia, watchedAt: String)
        let movies: [Event] = snapshot.movieWatches.map { ($0.media, $0.watchedAt) }
        let episodes: [Event] = snapshot.episodeWatches.map { ($0.series, $0.watchedAt) }
        let events = (movies + episodes).filter { event in
            let media = event.media
            let recommendable = (media.provider == "tmdb" || media.provider == "mock") && (media.mediaType == .movie || media.mediaType == .tv)
            return recommendable && (type == nil || media.mediaType == type) && !disliked.contains(media.mediaKey)
        }
        .sorted { $0.watchedAt > $1.watchedAt }
        var seen = Set<String>(), seeds: [CatalogMedia] = []
        for event in events where !seen.contains(event.media.mediaKey) { seen.insert(event.media.mediaKey); seeds.append(event.media) }
        return Array(seeds.prefix(maxSeeds))
    }

    struct Row: Identifiable, Hashable { let seed: CatalogMedia; let items: [CatalogMedia]; var id: String { seed.mediaKey } }

    static func build(seeds: [CatalogMedia], results: [[CatalogMedia]?], snapshot: MosaicStateSnapshot) -> [Row] {
        var excluded = Set(snapshot.library.map(\.media.mediaKey))
        excluded.formUnion(snapshot.movieWatches.map(\.media.mediaKey))
        excluded.formUnion(snapshot.episodeWatches.map(\.series.mediaKey))
        excluded.formUnion(seeds.map(\.mediaKey))
        return seeds.enumerated().compactMap { index, seed in
            var items: [CatalogMedia] = []
            for item in (index < results.count ? results[index] : nil) ?? [] where !excluded.contains(item.mediaKey) {
                excluded.insert(item.mediaKey)
                items.append(item)
                if items.count == perSeed { break }
            }
            return items.isEmpty ? nil : Row(seed: seed, items: items)
        }
    }
}

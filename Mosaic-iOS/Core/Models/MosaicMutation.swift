import Foundation

/// One `PersistenceMutation` for `POST /api/me/state`. The server validates
/// every command (`src/lib/persistence/validation.ts`); this type only builds
/// documented shapes. Optional fields are omitted when nil, except where the
/// schema requires an explicit `null` (`rating.set` clearing a rating).
nonisolated struct DetailMutation: Encodable, Equatable {
    let type: String
    let media: CatalogMedia?
    var series: CatalogMedia?
    var status: String?
    var state: String?
    var provenance: String?
    var isFavorite: Bool?
    var onlyIfUntracked: Bool?
    var value: Double?
    var region: String?
    var rating: Double?
    var watchedAt: String?
    var isRewatch: Bool?
    var review: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var episodeTitle: String?
    var playthroughID: String?
    var readingID: String?
    var platform: String?
    var playtimeMinutes: Int?
    var progressPercent: Double?
    var currentPage: Int?
    var totalPages: Int?

    private enum CodingKeys: String, CodingKey {
        case type, media, series, status, state, provenance, isFavorite, onlyIfUntracked, value, rating, watchedAt, isRewatch, review
        case seasonNumber, episodeNumber, episodeTitle, playthroughID = "playthroughId", readingID = "readingId", platform, playtimeMinutes, progressPercent, currentPage, totalPages
    }
    /// `settings.watchRegion` shares no media identity and has a string `value`.
    private enum RegionCodingKeys: String, CodingKey { case type, value }

    func encode(to encoder: Encoder) throws {
        if type == "settings.watchRegion" {
            var container = encoder.container(keyedBy: RegionCodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(region, forKey: .value)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(media, forKey: .media)
        try container.encodeIfPresent(series, forKey: .series)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(provenance, forKey: .provenance)
        try container.encodeIfPresent(isFavorite, forKey: .isFavorite)
        try container.encodeIfPresent(onlyIfUntracked, forKey: .onlyIfUntracked)
        if type == "rating.set" { try container.encode(value, forKey: .value) }
        else { try container.encodeIfPresent(value, forKey: .value) }
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(watchedAt, forKey: .watchedAt)
        try container.encodeIfPresent(isRewatch, forKey: .isRewatch)
        try container.encodeIfPresent(review, forKey: .review)
        try container.encodeIfPresent(seasonNumber, forKey: .seasonNumber)
        try container.encodeIfPresent(episodeNumber, forKey: .episodeNumber)
        try container.encodeIfPresent(episodeTitle, forKey: .episodeTitle)
        try container.encodeIfPresent(playthroughID, forKey: .playthroughID)
        try container.encodeIfPresent(readingID, forKey: .readingID)
        try container.encodeIfPresent(platform, forKey: .platform)
        try container.encodeIfPresent(playtimeMinutes, forKey: .playtimeMinutes)
        try container.encodeIfPresent(progressPercent, forKey: .progressPercent)
        try container.encodeIfPresent(currentPage, forKey: .currentPage)
        try container.encodeIfPresent(totalPages, forKey: .totalPages)
    }

    private init(type: String, media: CatalogMedia?) { self.type = type; self.media = media }

    /// The identity whose personal state this command changes.
    var affectedRoute: MediaDetailRoute? { (series ?? media)?.route }

    /// `settings.watchRegion` is not media-scoped; it only carries the region.
    static func watchRegion(_ region: String?) -> Self {
        with(.init(type: "settings.watchRegion", media: nil)) { $0.region = region }
    }

    static func rating(_ media: CatalogMedia, _ value: Double?) -> Self { with(.init(type: "rating.set", media: media)) { $0.value = value } }

    /// A status change. `isFavorite` is only sent when the favourite itself changes,
    /// so a status edit never resets it.
    static func library(_ media: CatalogMedia, status: String, isFavorite: Bool? = nil) -> Self {
        with(.init(type: "library.upsert", media: media)) { $0.status = status; $0.isFavorite = isFavorite }
    }

    /// Save for later: inserts the medium's planned status only when untracked
    /// (`addIfUntracked`), so a stale client can never reset a tracked entry.
    static func saveForLater(_ media: CatalogMedia) -> Self {
        with(.init(type: "library.upsert", media: media)) { $0.status = LibraryStatus.saveForLater(for: media.mediaType).rawValue; $0.onlyIfUntracked = true }
    }

    static func removeLibrary(_ media: CatalogMedia) -> Self { .init(type: "library.remove", media: media) }

    static func movieLog(_ media: CatalogMedia, watchedAt: Date, isRewatch: Bool, rating: Double?, review: String?) -> Self {
        with(.init(type: "movie.log", media: media)) { $0.watchedAt = day.string(from: watchedAt); $0.isRewatch = isRewatch; $0.rating = rating; $0.review = review }
    }

    static func episodeLog(_ media: CatalogMedia, season: Int, episode: Int, watchedAt: Date, rating: Double?, episodeTitle: String? = nil) -> Self {
        with(.init(type: "episode.log", media: media)) { $0.series = media; $0.seasonNumber = season; $0.episodeNumber = episode; $0.watchedAt = instant.string(from: watchedAt); $0.rating = rating; $0.episodeTitle = episodeTitle }
    }

    static func episodeUnwatch(_ media: CatalogMedia, season: Int, episode: Int) -> Self {
        with(.init(type: "episode.unwatch", media: media)) { $0.series = media; $0.seasonNumber = season; $0.episodeNumber = episode }
    }

    static func seasonState(_ media: CatalogMedia, season: Int, state: String) -> Self {
        with(.init(type: "season.state", media: media)) { $0.series = media; $0.seasonNumber = season; $0.state = state; $0.provenance = "bulk_season" }
    }

    /// Updates `playthroughID` when one exists; otherwise starts a new playthrough.
    static func game(_ media: CatalogMedia, playthroughID: String?, status: String, platform: String?, playtimeMinutes: Int, percent: Double?, rating: Double?) -> Self {
        with(.init(type: "game.upsert", media: media)) { $0.playthroughID = playthroughID; $0.status = status; $0.platform = platform; $0.playtimeMinutes = playtimeMinutes; $0.progressPercent = percent; $0.rating = rating }
    }

    /// Updates `readingID` when one exists; otherwise starts a new reading.
    static func book(_ media: CatalogMedia, readingID: String?, status: String, currentPage: Int?, totalPages: Int?, percent: Double?, rating: Double?) -> Self {
        with(.init(type: "book.upsert", media: media)) { $0.readingID = readingID; $0.status = status; $0.currentPage = currentPage; $0.totalPages = totalPages; $0.progressPercent = percent; $0.rating = rating }
    }

    private static func with(_ base: Self, _ apply: (inout Self) -> Void) -> Self { var value = base; apply(&value); return value }
    private static let day: DateFormatter = { let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .iso8601); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; return formatter }()
    private static let instant = ISO8601DateFormatter()
}

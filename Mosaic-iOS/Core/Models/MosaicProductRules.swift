import Foundation

// Product semantics shared with the web app. Each rule names the web source it
// mirrors (Tracking App `bc49972`) so the two clients can be kept in step.

/// Library statuses per medium — `mediaStatuses` in `src/lib/persistence/validation.ts`.
nonisolated enum LibraryStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case watchlist, watched, watching, completed, paused, dropped, backlog, playing
    case wantToRead = "want_to_read", reading, finished, dnf

    static func statuses(for mediaType: CatalogMediaType) -> [LibraryStatus] {
        switch mediaType {
        case .movie: [.watchlist, .watched]
        case .tv: [.watchlist, .watching, .completed, .paused, .dropped]
        case .game: [.backlog, .playing, .paused, .completed, .dropped]
        case .book: [.wantToRead, .reading, .paused, .finished, .dnf]
        }
    }

    /// `saveForLaterStatus`: the medium's planned state. Saving never starts a series.
    static func saveForLater(for mediaType: CatalogMediaType) -> LibraryStatus { statuses(for: mediaType)[0] }

    /// Labels from `statusLabels` in `library-card.tsx`.
    var label: String {
        switch self {
        case .watchlist: "Watchlist"
        case .watched: "Watched"
        case .watching: "Watching"
        case .completed: "Completed"
        case .paused: "Paused"
        case .dropped: "Dropped"
        case .backlog: "Backlog"
        case .playing: "Playing"
        case .wantToRead: "Want to read"
        case .reading: "Reading"
        case .finished: "Finished"
        case .dnf: "Did not finish"
        }
    }

    var systemImage: String {
        switch self {
        case .watchlist, .backlog, .wantToRead: "bookmark"
        case .watching, .playing, .reading: "play.circle"
        case .watched, .completed, .finished: "checkmark.circle"
        case .paused: "pause.circle"
        case .dropped, .dnf: "xmark.circle"
        }
    }

    var isPlanned: Bool { self == .watchlist || self == .backlog || self == .wantToRead }
    var isActive: Bool { self == .watching || self == .playing || self == .reading }

    func applies(to mediaType: CatalogMediaType) -> Bool { Self.statuses(for: mediaType).contains(self) }

    /// A label for an unknown wire value, never a crash or a capitalised code.
    static func label(for rawValue: String) -> String {
        LibraryStatus(rawValue: rawValue)?.label ?? rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

nonisolated enum CatalogProvider: String, Sendable {
    case tmdb, igdb, googlebooks, mock

    /// `communityRatingSources` in `src/lib/media/ratings.ts`.
    var label: String {
        switch self { case .tmdb: "TMDB"; case .igdb: "IGDB"; case .googlebooks: "Google Books"; case .mock: "the sample catalog" }
    }
    var shortLabel: String {
        switch self { case .tmdb: "TMDB"; case .igdb: "IGDB"; case .googlebooks: "Google"; case .mock: "Sample" }
    }
    /// Scale of `communityRating` as each adapter stores it (`storedScale`).
    var storedRatingScale: Double {
        switch self { case .tmdb: 10; case .igdb, .googlebooks, .mock: 5 }
    }
}

/// A provider's community score on Mosaic's /10 display scale. Never the user's own rating.
nonisolated struct CommunityRating: Equatable, Sendable {
    let value: Double
    let source: CatalogProvider
    let count: Int?

    /// `normalizeCommunityRating`: invalid or out-of-range values give no rating,
    /// and 0 is only a real score when at least one rating was counted.
    init?(raw: Double?, provider: String, count: Int? = nil) {
        guard let raw, let source = CatalogProvider(rawValue: provider), raw.isFinite, raw >= 0, raw <= source.storedRatingScale else { return nil }
        let ratings = count.flatMap { $0 > 0 ? $0 : nil }
        if raw == 0 && ratings == nil { return nil }
        self.value = ((raw * 10) / source.storedRatingScale * 10).rounded() / 10
        self.source = source
        self.count = ratings
    }

    var formattedValue: String { value.formatted(.number.precision(.fractionLength(1))) }

    var accessibilityDescription: String {
        let countText = count.map { " from \($0.formatted()) \($0 == 1 ? "rating" : "ratings")" } ?? ""
        return "Community rating \(formattedValue) out of 10 on \(source.label)\(countText)"
    }
}

nonisolated extension CatalogMedia {
    var community: CommunityRating? { CommunityRating(raw: communityRating, provider: provider, count: communityRatingCount) }
}

/// The user's Mosaic rating: 0.5–5.0 in half-star steps (`rating` in validation.ts).
nonisolated enum UserRating {
    static let options: [Double] = stride(from: 0.5, through: 5, by: 0.5).map { $0 }
    static func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
    static func isValid(_ value: Double) -> Bool { value >= 0.5 && value <= 5 && (value * 2).rounded() == value * 2 }
}

/// `activityLabel` in `src/lib/activity/projection.ts`.
nonisolated enum ActivityLabel {
    static func text(eventType: String, repeatKind: String?, targetType: String?, seasonNumber: Int?, episode: (season: Int, episode: Int)?, progressPercent: Double?) -> String {
        let verb = repeatKind == nil ? "Watched" : "Rewatched"
        switch eventType {
        case "movie_watch": return verb
        case "episode_watch":
            guard let episode else { return "\(verb) an episode" }
            return "\(verb) \(EpisodeCode.format(season: episode.season, episode: episode.episode))"
        case "tv_watch": return targetType == "season" ? "\(verb) season \(seasonNumber.map(String.init) ?? "")".trimmingCharacters(in: .whitespaces) : "\(verb) series"
        case "game_update": return progressPercent == 100 ? "Completed playthrough" : "Updated playthrough"
        case "book_update": return progressPercent == 100 ? "Finished reading" : "Updated reading"
        default: return "Updated"
        }
    }
}

nonisolated enum EpisodeCode {
    static func format(season: Int, episode: Int) -> String { String(format: "S%02dE%02d", season, episode) }
}

nonisolated enum MosaicDuration {
    /// "4h 5m", "45m", "12h" — playtime is recorded in minutes.
    static func playtime(_ minutes: Int) -> String {
        let hours = minutes / 60, remainder = minutes % 60
        if hours == 0 { return "\(minutes)m" }
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

nonisolated enum Plural {
    /// "1 film", "3 films", "2 rewatches".
    static func count(_ value: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(value.formatted()) \(value == 1 ? singular : plural ?? singular + "s")"
    }
}

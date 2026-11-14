import Foundation

/// Rebuildable history from domain records, mirroring web activity/projection.ts.
nonisolated enum ActivityProjection {
    enum Medium: String, CaseIterable {
        case all, movies, series, games, books

        var title: String {
            switch self {
            case .all: "All"
            case .movies: "Movies"
            case .series: "Series"
            case .games: "Games"
            case .books: "Books"
            }
        }

        var mediaType: CatalogMediaType? {
            switch self {
            case .all: nil
            case .movies: .movie
            case .series: .tv
            case .games: .game
            case .books: .book
            }
        }
    }

    static func filtered(_ events: [ProfileActivity], medium: Medium, diary: Bool = false) -> [ProfileActivity] {
        events.filter { event in
            diary ? event.eventType == "movie_watch" : medium.mediaType.map { event.media.mediaType == $0 } ?? true
        }
    }

    static func project(_ snapshot: MosaicStateSnapshot) -> [ProfileActivity] {
        let instant = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func date(_ value: String) -> Date {
            let normalized = value.contains("T") ? value : "\(value)T00:00:00.000Z"
            // A malformed legacy timestamp remains deterministic, never a fabricated recent event.
            return fractional.date(from: normalized) ?? instant.date(from: normalized) ?? .distantPast
        }
        func event(_ id: String, _ media: CatalogMedia, _ timestamp: String, _ type: String,
                   target: String, rating: Double?, repeatKind: String? = nil, detail: String? = nil,
                   episode: ProfileActivity.Episode? = nil, season: Int? = nil, progress: Double? = nil) -> ProfileActivity {
            ProfileActivity(eventID: id, media: media, occurredAt: date(timestamp), eventType: type,
                            targetType: target, rating: rating, repeatKind: repeatKind, detail: detail,
                            episode: episode, seasonNumber: season, progressPercent: progress)
        }
        var events = snapshot.movieWatches.map { watch in
            let detail = [watch.viewingContext, watch.streamingService].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            return event("movie-watch:\(watch.id)", watch.media, watch.watchedAt, "movie_watch", target: "media",
                         rating: watch.rating, repeatKind: watch.isRewatch ? "rewatch" : nil, detail: detail.isEmpty ? nil : detail)
        }
        events += snapshot.episodeWatches.map { watch in
            event("episode-watch:\(watch.id)", watch.series, watch.watchedAt, "episode_watch", target: "episode",
                  rating: watch.rating, repeatKind: watch.isRewatch == true ? "rewatch" : nil,
                  episode: .init(seasonNumber: watch.seasonNumber, episodeNumber: watch.episodeNumber, title: watch.episodeTitle))
        }
        events += snapshot.tvHistory.map { watch in
            event("tv-history:\(watch.id)", watch.series, watch.occurredAt, "tv_watch",
                  target: watch.targetType == "season" ? "season" : "media", rating: watch.rating,
                  repeatKind: watch.isRewatch ? "rewatch" : nil, season: watch.seasonNumber)
        }
        events += snapshot.gamePlaythroughs.map { playthrough in
            event("game-playthrough:\(playthrough.id)", playthrough.media, playthrough.updatedAt, "game_update",
                  target: "playthrough", rating: playthrough.rating, repeatKind: playthrough.status == "completed" ? "replay" : nil,
                  detail: playthrough.platform, progress: playthrough.progressPercent)
        }
        events += snapshot.bookReadings.map { reading in
            event("book-reading:\(reading.id)", reading.media, reading.updatedAt, "book_update", target: "reading",
                  rating: reading.rating, repeatKind: reading.status == "finished" ? "reread" : nil,
                  detail: reading.totalPages.flatMap { $0 != 0 ? "\(reading.currentPage ?? 0) / \($0) pages" : nil },
                  progress: reading.progressPercent)
        }
        return events.sorted {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
            if ($0.repeatKind != nil) != ($1.repeatKind != nil) { return $0.repeatKind != nil }
            return $0.eventID.compare($1.eventID, locale: Locale(identifier: "en_US")) == .orderedDescending
        }
    }
}

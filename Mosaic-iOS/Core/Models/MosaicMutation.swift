import Foundation

nonisolated enum MovieViewingContext: String, CaseIterable {
    case theater, streaming, television, physical, digital, other

    var label: String {
        switch self {
        case .theater: "Theater"
        case .streaming: "Streaming"
        case .television: "TV / Broadcast"
        case .physical: "Blu-ray / DVD"
        case .digital: "Digital purchase/rental"
        case .other: "Other"
        }
    }
}

/// One server command for `POST /api/me/state`. Optional fields are omitted,
/// except the nullable values used to clear a rating or watch region.
nonisolated struct DetailMutation: Encodable, Equatable {
    let media: CatalogMedia?
    private let payload: Payload

    private enum Payload: Equatable {
        case watchRegion(String?)
        case rating(Double?)
        case library(status: String, isFavorite: Bool?, onlyIfUntracked: Bool?)
        case removeLibrary
        case reviewSave(id: String?, body: String, containsSpoilers: Bool, rating: Double?)
        case reviewDelete(id: String)
        case listCreate(title: String, description: String, visibility: UserList.Visibility)
        case listAdd(listID: String, note: String?)
        case listUpdate(listID: String, title: String, description: String, visibility: UserList.Visibility)
        case listItemUpdate(listID: String, itemID: String, note: String)
        case listItemRemove(listID: String, itemID: String)
        case listReorder(listID: String, itemIDs: [String])
        case movieLog(MovieFields)
        case movieUpdate(watchID: String, MovieFields)
        case movieDelete(watchID: String)
        case episodeLog(season: Int, episode: Int, watchedAt: String, rating: Double?, episodeTitle: String?)
        case episodeUnwatch(season: Int, episode: Int)
        case seasonState(season: Int, state: String, completedOn: String?)
        case game(playthroughID: String?, status: String, platform: String?, playtimeMinutes: Int, percent: Double?, rating: Double?)
        case book(readingID: String?, status: String, currentPage: Int?, totalPages: Int?, percent: Double?, rating: Double?)
    }

    private struct MovieFields: Equatable {
        let watchedAt: String
        let isRewatch: Bool
        let rating: Double?
        let review: String?
        let viewingContext: MovieViewingContext?
        let streamingService: String?
    }

    var type: String {
        switch payload {
        case .watchRegion: "settings.watchRegion"
        case .rating: "rating.set"
        case .library: "library.upsert"
        case .removeLibrary: "library.remove"
        case .reviewSave: "review.save"
        case .reviewDelete: "review.delete"
        case .listCreate: "list.create"
        case .listAdd: "list.add"
        case .listUpdate: "list.update"
        case .listItemUpdate: "list.item.update"
        case .listItemRemove: "list.item.remove"
        case .listReorder: "list.reorder"
        case .movieLog: "movie.log"
        case .movieUpdate: "movie.update"
        case .movieDelete: "movie.delete"
        case .episodeLog: "episode.log"
        case .episodeUnwatch: "episode.unwatch"
        case .seasonState: "season.state"
        case .game: "game.upsert"
        case .book: "book.upsert"
        }
    }

    /// The identity whose personal state this command changes, including series.
    var affectedRoute: MediaDetailRoute? { media?.route }

    private enum CodingKeys: String, CodingKey {
        case type, media, series, value, status, isFavorite, onlyIfUntracked, rating, review
        case id, body, containsSpoilers, title, description, visibility, note
        case listID = "listId", itemID = "itemId", itemIDs = "itemIds", watchID = "watchId"
        case watchedAt, isRewatch, viewingContext, streamingService
        case seasonNumber, episodeNumber, episodeTitle, state, provenance, completedOn
        case playthroughID = "playthroughId", readingID = "readingId", platform, playtimeMinutes, progressPercent, currentPage, totalPages
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch payload {
        case .episodeLog, .episodeUnwatch, .seasonState:
            try container.encodeIfPresent(media, forKey: .series)
        default:
            try container.encodeIfPresent(media, forKey: .media)
        }
        switch payload {
        case .watchRegion(let region):
            try container.encode(region, forKey: .value)
        case .rating(let value):
            try container.encode(value, forKey: .value)
        case let .library(status, isFavorite, onlyIfUntracked):
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(isFavorite, forKey: .isFavorite)
            try container.encodeIfPresent(onlyIfUntracked, forKey: .onlyIfUntracked)
        case .removeLibrary:
            break
        case let .reviewSave(id, body, containsSpoilers, rating):
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(body, forKey: .body)
            try container.encode(containsSpoilers, forKey: .containsSpoilers)
            try container.encodeIfPresent(rating, forKey: .rating)
        case .reviewDelete(let id):
            try container.encode(id, forKey: .id)
        case let .listCreate(title, description, visibility):
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
            try container.encode(visibility.rawValue, forKey: .visibility)
        case let .listAdd(listID, note):
            try container.encode(listID, forKey: .listID)
            try container.encodeIfPresent(note, forKey: .note)
        case let .listUpdate(listID, title, description, visibility):
            try container.encode(listID, forKey: .listID)
            try container.encode(title, forKey: .title)
            try container.encode(description, forKey: .description)
            try container.encode(visibility.rawValue, forKey: .visibility)
        case let .listItemUpdate(listID, itemID, note):
            try container.encode(listID, forKey: .listID)
            try container.encode(itemID, forKey: .itemID)
            try container.encode(note, forKey: .note)
        case let .listItemRemove(listID, itemID):
            try container.encode(listID, forKey: .listID)
            try container.encode(itemID, forKey: .itemID)
        case let .listReorder(listID, itemIDs):
            try container.encode(listID, forKey: .listID)
            try container.encode(itemIDs, forKey: .itemIDs)
        case .movieLog(let fields), .movieUpdate(_, let fields):
            if case .movieUpdate(let watchID, _) = payload { try container.encode(watchID, forKey: .watchID) }
            try container.encode(fields.watchedAt, forKey: .watchedAt)
            try container.encode(fields.isRewatch, forKey: .isRewatch)
            try container.encodeIfPresent(fields.rating, forKey: .rating)
            try container.encodeIfPresent(fields.review, forKey: .review)
            try container.encodeIfPresent(fields.viewingContext?.rawValue, forKey: .viewingContext)
            if fields.viewingContext == .streaming,
               let service = fields.streamingService?.trimmingCharacters(in: .whitespacesAndNewlines), !service.isEmpty {
                try container.encode(service, forKey: .streamingService)
            }
        case .movieDelete(let watchID):
            try container.encode(watchID, forKey: .watchID)
        case let .episodeLog(season, episode, watchedAt, rating, episodeTitle):
            try container.encode(season, forKey: .seasonNumber)
            try container.encode(episode, forKey: .episodeNumber)
            try container.encode(watchedAt, forKey: .watchedAt)
            try container.encodeIfPresent(rating, forKey: .rating)
            try container.encodeIfPresent(episodeTitle, forKey: .episodeTitle)
        case let .episodeUnwatch(season, episode):
            try container.encode(season, forKey: .seasonNumber)
            try container.encode(episode, forKey: .episodeNumber)
        case let .seasonState(season, state, completedOn):
            try container.encode(season, forKey: .seasonNumber)
            try container.encode(state, forKey: .state)
            try container.encode("bulk_season", forKey: .provenance)
            try container.encodeIfPresent(completedOn, forKey: .completedOn)
        case let .game(playthroughID, status, platform, playtimeMinutes, percent, rating):
            try container.encodeIfPresent(playthroughID, forKey: .playthroughID)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(platform, forKey: .platform)
            try container.encode(playtimeMinutes, forKey: .playtimeMinutes)
            try container.encodeIfPresent(percent, forKey: .progressPercent)
            try container.encodeIfPresent(rating, forKey: .rating)
        case let .book(readingID, status, currentPage, totalPages, percent, rating):
            try container.encodeIfPresent(readingID, forKey: .readingID)
            try container.encode(status, forKey: .status)
            try container.encodeIfPresent(currentPage, forKey: .currentPage)
            try container.encodeIfPresent(totalPages, forKey: .totalPages)
            try container.encodeIfPresent(percent, forKey: .progressPercent)
            try container.encodeIfPresent(rating, forKey: .rating)
        }
    }

    private init(_ payload: Payload, media: CatalogMedia? = nil) { self.payload = payload; self.media = media }

    static func watchRegion(_ region: String?) -> Self { .init(.watchRegion(region)) }
    static func rating(_ media: CatalogMedia, _ value: Double?) -> Self { .init(.rating(value), media: media) }

    /// Omitting `isFavorite` keeps the existing favourite when changing status.
    static func library(_ media: CatalogMedia, status: String, isFavorite: Bool? = nil) -> Self {
        .init(.library(status: status, isFavorite: isFavorite, onlyIfUntracked: nil), media: media)
    }

    static func saveForLater(_ media: CatalogMedia) -> Self {
        .init(.library(status: LibraryStatus.saveForLater(for: media.mediaType).rawValue, isFavorite: nil, onlyIfUntracked: true), media: media)
    }

    static func removeLibrary(_ media: CatalogMedia) -> Self { .init(.removeLibrary, media: media) }

    static func reviewSave(id: String? = nil, media: CatalogMedia, body: String, containsSpoilers: Bool, rating: Double? = nil) -> Self {
        .init(.reviewSave(id: id, body: body, containsSpoilers: containsSpoilers, rating: rating), media: media)
    }

    static func reviewDelete(id: String) -> Self { .init(.reviewDelete(id: id)) }

    static func listCreate(title: String, description: String, visibility: UserList.Visibility) -> Self {
        .init(.listCreate(title: title, description: description, visibility: visibility))
    }

    static func listAdd(listID: String, media: CatalogMedia, note: String? = nil) -> Self {
        .init(.listAdd(listID: listID, note: note), media: media)
    }

    static func listUpdate(listID: String, title: String, description: String, visibility: UserList.Visibility) -> Self {
        .init(.listUpdate(listID: listID, title: title, description: description, visibility: visibility))
    }

    static func listItemUpdate(listID: String, itemID: String, note: String) -> Self {
        .init(.listItemUpdate(listID: listID, itemID: itemID, note: note))
    }

    static func listItemRemove(listID: String, itemID: String) -> Self { .init(.listItemRemove(listID: listID, itemID: itemID)) }
    static func listReorder(listID: String, itemIDs: [String]) -> Self { .init(.listReorder(listID: listID, itemIDs: itemIDs)) }

    static func movieLog(_ media: CatalogMedia, watchedAt: Date, isRewatch: Bool, rating: Double?, review: String?, viewingContext: MovieViewingContext? = nil, streamingService: String? = nil) -> Self {
        .init(.movieLog(.init(watchedAt: day.string(from: watchedAt), isRewatch: isRewatch, rating: rating, review: review, viewingContext: viewingContext, streamingService: streamingService)), media: media)
    }

    static func movieUpdate(watchID: String, media: CatalogMedia, watchedAt: Date, isRewatch: Bool, rating: Double?, review: String?, viewingContext: MovieViewingContext? = nil, streamingService: String? = nil) -> Self {
        .init(.movieUpdate(watchID: watchID, .init(watchedAt: day.string(from: watchedAt), isRewatch: isRewatch, rating: rating, review: review, viewingContext: viewingContext, streamingService: streamingService)), media: media)
    }

    static func movieDelete(watchID: String) -> Self { .init(.movieDelete(watchID: watchID)) }

    static func episodeLog(_ media: CatalogMedia, season: Int, episode: Int, watchedAt: Date, rating: Double?, episodeTitle: String? = nil) -> Self {
        .init(.episodeLog(season: season, episode: episode, watchedAt: instant.string(from: watchedAt), rating: rating, episodeTitle: episodeTitle), media: media)
    }

    static func episodeUnwatch(_ media: CatalogMedia, season: Int, episode: Int) -> Self {
        .init(.episodeUnwatch(season: season, episode: episode), media: media)
    }

    static func seasonState(_ media: CatalogMedia, season: Int, state: String, today: Date = .now) -> Self {
        .init(.seasonState(season: season, state: state, completedOn: state == "completed" ? day.string(from: today) : nil), media: media)
    }

    /// Updates `playthroughID` when one exists; otherwise starts a new playthrough.
    static func game(_ media: CatalogMedia, playthroughID: String?, status: String, platform: String?, playtimeMinutes: Int, percent: Double?, rating: Double?) -> Self {
        .init(.game(playthroughID: playthroughID, status: status, platform: platform, playtimeMinutes: playtimeMinutes, percent: percent, rating: rating), media: media)
    }

    /// Updates `readingID` when one exists; otherwise starts a new reading.
    static func book(_ media: CatalogMedia, readingID: String?, status: String, currentPage: Int?, totalPages: Int?, percent: Double?, rating: Double?) -> Self {
        .init(.book(readingID: readingID, status: status, currentPage: currentPage, totalPages: totalPages, percent: percent, rating: rating), media: media)
    }

    private static let day: DateFormatter = { let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .iso8601); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; return formatter }()
    private static let instant = ISO8601DateFormatter()
}

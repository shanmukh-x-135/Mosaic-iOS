import Foundation

struct ContinueResponseDTO: Decodable, Sendable {
    let items: [ContinueItemDTO]
}

struct ContinueItemDTO: Decodable, Sendable {
    let id: String
    let mediaType: ContinueMediaType
    let provider: String
    let providerId: String
    let title: String
    let posterURL: URL?
    let backdropURL: URL?
    let status: ContinueStatus
    let lastActivityAt: Date?
    let progress: ContinueProgressDTO
    let nextAction: ContinueNextActionDTO
}

enum ContinueMediaType: String, Decodable, Sendable { case series, book, game }
enum ContinueStatus: String, Decodable, Sendable { case watching, reading, playing }

struct ContinueProgressDTO: Decodable, Sendable {
    let watchedEpisodes: Int?
    let totalEpisodes: Int?
    let currentPage: Int?
    let totalPages: Int?
    let percent: Double?
    let playtimeMinutes: Int?
    let nextSeasonNumber: Int?
    let nextEpisodeNumber: Int?
}

struct ContinueNextActionDTO: Decodable, Sendable {
    let type: String
    let seasonNumber: Int?
    let episodeNumber: Int?
}

struct ContinueStory: Identifiable, Equatable, Sendable {
    let id: String
    let mediaType: ContinueMediaType
    let provider: String
    let providerID: String
    let title: String
    let artworkURL: URL?
    let fallbackArtworkURL: URL?
    let status: ContinueStatus
    let progress: ContinueProgress

    init(dto: ContinueItemDTO) {
        id = dto.id
        mediaType = dto.mediaType
        provider = dto.provider
        providerID = dto.providerId
        title = dto.title
        artworkURL = dto.backdropURL
        fallbackArtworkURL = dto.posterURL
        status = dto.status
        switch dto.mediaType {
        case .series:
            progress = .episodes(
                watched: dto.progress.watchedEpisodes,
                total: dto.progress.totalEpisodes,
                percent: dto.progress.percent,
                nextSeason: dto.progress.nextSeasonNumber,
                nextEpisode: dto.progress.nextEpisodeNumber
            )
        case .book:
            progress = .pages(current: dto.progress.currentPage, total: dto.progress.totalPages, percent: dto.progress.percent)
        case .game:
            progress = .game(percent: dto.progress.percent, playtimeMinutes: dto.progress.playtimeMinutes ?? 0)
        }
    }

    var mediaLabel: String { mediaType.rawValue.capitalized }
    var actionTitle: String { mediaType == .book ? "Continue Reading" : "Continue" }

    var detailRoute: MediaDetailRoute {
        MediaDetailRoute(provider: provider, mediaType: CatalogMediaType(mediaType), providerID: providerID)
    }
}

extension CatalogMediaType {
    init(_ continueType: ContinueMediaType) {
        switch continueType {
        case .series: self = .series
        case .book: self = .book
        case .game: self = .game
        }
    }
}

enum ContinueProgress: Equatable, Sendable {
    case episodes(watched: Int?, total: Int?, percent: Double?, nextSeason: Int?, nextEpisode: Int?)
    case pages(current: Int?, total: Int?, percent: Double?)
    case game(percent: Double?, playtimeMinutes: Int)

    var detailLines: [String] {
        switch self {
        case let .episodes(watched, total, _, nextSeason, nextEpisode):
            var lines: [String] = []
            if let nextSeason, let nextEpisode { lines.append("Next: S\(nextSeason)E\(nextEpisode)") }
            if let watched { lines.append(total.map { "\(watched) / \($0) episodes" } ?? "\(watched) episodes") }
            return lines
        case let .pages(current, total, percent):
            if let current, let total { return ["\(current) / \(total) pages"] }
            if let current { return ["Page \(current)"] }
            if let percent, percent > 0 { return ["\(Self.percentText(percent)) read"] }
            return []
        case let .game(percent, playtimeMinutes):
            var lines = playtimeMinutes > 0 ? [Self.playtimeText(playtimeMinutes)] : []
            if let percent, percent > 0 { lines.append(Self.percentText(percent)) }
            if lines.isEmpty { lines.append("In progress") }
            return lines
        }
    }

    var progressFraction: Double? {
        let percent: Double?
        switch self {
        case let .episodes(_, _, value, _, _), let .pages(_, _, value), let .game(value, _): percent = value
        }
        guard let percent, percent > 0 else { return nil }
        return min(max(percent / 100, 0), 1)
    }

    var accessibilitySummary: String { detailLines.joined(separator: ", ") }

    private static func percentText(_ percent: Double) -> String {
        "\(Int(percent.rounded()))%"
    }

    private static func playtimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 { return remainder > 0 ? "\(hours)h \(remainder)m played" : "\(hours)h played" }
        return "\(minutes)m played"
    }
}

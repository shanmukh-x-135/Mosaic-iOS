import Foundation

// Static copies of the web's verified Discover taxonomy (Tracking App
// `src/lib/media/genres.ts` and `themes.ts` at `bc49972`). IDs are the
// providers' own and are validated again by the server routes.

nonisolated struct ProviderGenre: Hashable, Identifiable, Sendable { let id: Int; let name: String }

nonisolated struct GenreCatalog: Sendable {
    let mediaType: CatalogMediaType
    let label: String
    let genres: [ProviderGenre]

    static let movie = GenreCatalog(mediaType: .movie, label: "TMDB movie genres", genres: [.init(id: 28, name: "Action"), .init(id: 12, name: "Adventure"), .init(id: 16, name: "Animation"), .init(id: 35, name: "Comedy"), .init(id: 80, name: "Crime"), .init(id: 99, name: "Documentary"), .init(id: 18, name: "Drama"), .init(id: 10751, name: "Family"), .init(id: 14, name: "Fantasy"), .init(id: 36, name: "History"), .init(id: 27, name: "Horror"), .init(id: 10402, name: "Music"), .init(id: 9648, name: "Mystery"), .init(id: 10749, name: "Romance"), .init(id: 878, name: "Science Fiction"), .init(id: 10770, name: "TV Movie"), .init(id: 53, name: "Thriller"), .init(id: 10752, name: "War"), .init(id: 37, name: "Western")])
    static let tv = GenreCatalog(mediaType: .tv, label: "TMDB series genres", genres: [.init(id: 10759, name: "Action & Adventure"), .init(id: 16, name: "Animation"), .init(id: 35, name: "Comedy"), .init(id: 80, name: "Crime"), .init(id: 99, name: "Documentary"), .init(id: 18, name: "Drama"), .init(id: 10751, name: "Family"), .init(id: 10762, name: "Kids"), .init(id: 9648, name: "Mystery"), .init(id: 10763, name: "News"), .init(id: 10764, name: "Reality"), .init(id: 10765, name: "Sci-Fi & Fantasy"), .init(id: 10766, name: "Soap"), .init(id: 10767, name: "Talk"), .init(id: 10768, name: "War & Politics"), .init(id: 37, name: "Western")])
    static let game = GenreCatalog(mediaType: .game, label: "IGDB game genres", genres: [.init(id: 2, name: "Point-and-click"), .init(id: 4, name: "Fighting"), .init(id: 5, name: "Shooter"), .init(id: 7, name: "Music"), .init(id: 8, name: "Platform"), .init(id: 9, name: "Puzzle"), .init(id: 10, name: "Racing"), .init(id: 11, name: "Real Time Strategy (RTS)"), .init(id: 12, name: "Role-playing (RPG)"), .init(id: 13, name: "Simulator"), .init(id: 14, name: "Sport"), .init(id: 15, name: "Strategy"), .init(id: 16, name: "Turn-based strategy (TBS)"), .init(id: 24, name: "Tactical"), .init(id: 25, name: "Hack and slash/Beat 'em up"), .init(id: 26, name: "Quiz/Trivia"), .init(id: 30, name: "Pinball"), .init(id: 31, name: "Adventure"), .init(id: 32, name: "Indie"), .init(id: 33, name: "Arcade"), .init(id: 34, name: "Visual Novel"), .init(id: 35, name: "Card & Board Game"), .init(id: 36, name: "MOBA")])

    /// `genresFor`: All browses movie genres and says so; books have none.
    static func forTab(_ type: CatalogMediaType?) -> GenreCatalog? {
        switch type { case nil, .movie: .movie; case .tv: .tv; case .game: .game; case .book: nil }
    }

    /// `genreAfterSwitch`: a selection survives only when it means the same thing.
    static func genre(_ id: Int?, afterSwitchFrom from: CatalogMediaType?, to: CatalogMediaType?) -> Int? {
        guard let id, let before = forTab(from), let after = forTab(to) else { return nil }
        let sameProvider = (before.mediaType == .game) == (after.mediaType == .game)
        return sameProvider && after.genres.contains { $0.id == id } ? id : nil
    }
}

nonisolated struct MosaicTheme: Hashable, Identifiable, Sendable {
    let id: String
    let label: String
    let tagline: String
    let mediaTypes: [CatalogMediaType]

    static let all: [MosaicTheme] = [
        .init(id: "time-loop", label: "Time Loop", tagline: "The same day, until it isn't", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "slow-burn", label: "Slow Burn", tagline: "Patience, rewarded", mediaTypes: [.movie, .tv]),
        .init(id: "found-family", label: "Found Family", tagline: "Strangers who become home", mediaTypes: [.movie, .tv, .book]),
        .init(id: "cyberpunk", label: "Cyberpunk", tagline: "Neon, chrome and corporate rot", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "cosmic-horror", label: "Cosmic Horror", tagline: "Dread at a scale beyond us", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "heist", label: "Heist", tagline: "One last job, timed to the minute", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "courtroom", label: "Courtroom", tagline: "Truth argued in public", mediaTypes: [.movie, .tv, .book]),
        .init(id: "political-intrigue", label: "Political Intrigue", tagline: "Power, quietly negotiated", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "workplace", label: "Workplace", tagline: "Lives between nine and five", mediaTypes: [.movie, .tv, .game]),
        .init(id: "medical", label: "Medical", tagline: "Stakes measured in heartbeats", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "prison", label: "Prison", tagline: "Walls, rules and the way out", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "coming-of-age", label: "Coming of Age", tagline: "The summer everything changed", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "based-on-a-book", label: "Based on a Book", tagline: "Stories that began on the page", mediaTypes: [.movie, .tv]),
        .init(id: "mystery", label: "Mystery", tagline: "Clues worth following", mediaTypes: [.movie, .tv, .game, .book]),
        .init(id: "survival", label: "Survival", tagline: "Endurance at the edge", mediaTypes: [.movie, .tv, .game, .book]),
    ]

    /// `themesForMediaType`.
    static func forTab(_ type: CatalogMediaType?) -> [MosaicTheme] { type.map { type in all.filter { $0.mediaTypes.contains(type) } } ?? all }
}

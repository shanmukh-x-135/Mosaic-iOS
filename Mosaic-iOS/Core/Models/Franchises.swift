import Foundation

nonisolated struct FranchiseDefinition: Sendable {
    let slug, title, overview: String
    let items: [ProviderIdentity]
}

/// Curated identities and ordering mirror src/lib/media/franchises.ts.
nonisolated enum Franchises {
    static let all: [FranchiseDefinition] = [
        .init(slug: "dune", title: "Dune", overview: "A curated path through Frank Herbert’s desert world across books and films.", items: [
            .init(provider: "mock", mediaType: .book, providerID: "dune"),
            .init(provider: "mock", mediaType: .movie, providerID: "dune-part-two"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "438631"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "693134"),
        ]),
        .init(slug: "the-witcher", title: "The Witcher", overview: "A curated path through Andrzej Sapkowski’s Continent across screen stories and games.", items: [
            .init(provider: "tmdb", mediaType: .tv, providerID: "71912"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "1203329"),
            .init(provider: "igdb", mediaType: .game, providerID: "1942"),
        ]),
        .init(slug: "wizarding-world", title: "Wizarding World", overview: "A curated collection of Wizarding World films, television, and games.", items: [
            .init(provider: "tmdb", mediaType: .movie, providerID: "671"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "674"),
            .init(provider: "tmdb", mediaType: .tv, providerID: "224377"),
            .init(provider: "igdb", mediaType: .game, providerID: "136625"),
        ]),
        .init(slug: "star-wars", title: "Star Wars", overview: "A curated collection from a galaxy far, far away across films, series, and games.", items: [
            .init(provider: "tmdb", mediaType: .movie, providerID: "11"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "140607"),
            .init(provider: "tmdb", mediaType: .tv, providerID: "4194"),
            .init(provider: "igdb", mediaType: .game, providerID: "74701"),
        ]),
        .init(slug: "middle-earth", title: "Middle-earth", overview: "A curated collection of Middle-earth films, series, and games.", items: [
            .init(provider: "tmdb", mediaType: .movie, providerID: "120"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "122"),
            .init(provider: "tmdb", mediaType: .tv, providerID: "84773"),
            .init(provider: "igdb", mediaType: .game, providerID: "3025"),
        ]),
    ]
    static func forMedia(_ media: CatalogMedia) -> FranchiseDefinition? {
        all.first { $0.items.contains { $0.provider == media.provider && $0.mediaType == media.mediaType && $0.providerID == media.providerID } }
    }
    static func bySlug(_ slug: String) -> FranchiseDefinition? { all.first { $0.slug == slug } }
}

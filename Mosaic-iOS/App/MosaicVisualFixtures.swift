#if DEBUG
import SwiftUI

/// DEBUG-only visual fixtures. Launch with `-mosaic-visual-fixtures` and
/// `-mosaic-visual-screen <name>` to render the **real** screens with canned
/// data. Personal data never touches the network and mutations are recorded
/// in memory only; artwork still loads from public image CDNs.
///
/// Screens: home, discover, library, library-list, profile, search, detail-movie,
/// detail-game, detail-book, series, season, lists, list, activity, settings, quicklog.
/// Options: `-mosaic-visual-state loaded|empty|error`, `-mosaic-visual-accessibility`.
nonisolated enum MosaicVisualFixtures {
    struct Configuration { let screen: String; let state: String; let accessibility: Bool }

    static var launchConfiguration: Configuration? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-mosaic-visual-fixtures") else { return nil }
        func value(_ flag: String) -> String? { arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } }
        return Configuration(screen: value("-mosaic-visual-screen") ?? "home", state: value("-mosaic-visual-state") ?? "loaded", accessibility: arguments.contains("-mosaic-visual-accessibility"))
    }

    // MARK: Catalog

    static let digger = media(#"{"provider":"tmdb","providerId":"1248832","mediaType":"movie","title":"Digger","description":"A bright new chapter begins underground.","posterUrl":"https://image.tmdb.org/t/p/w500/1ATXKrIPJyKNwnJ6lcG088Sa6zi.jpg","backdropUrl":"https://image.tmdb.org/t/p/w1280/b7t3r39Oll5qPxBKzLZ8eHMBD7l.jpg","releaseYear":2026,"genres":["Comedy","Drama"],"communityRating":7.456,"communityRatingCount":812,"runtimeMinutes":104,"director":"Alejandro G. Iñárritu"}"#)
    static let succession = media(#"{"provider":"tmdb","providerId":"76331","mediaType":"tv","title":"Succession","description":"The Roy family controls the biggest media and entertainment company in the world. However, their world changes when their father steps down from the company.","posterUrl":"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg","backdropUrl":"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg","releaseYear":2018,"releaseDate":"2018-06-03","genres":["Drama","Comedy"],"communityRating":8.306,"seasonCount":4,"episodeCount":39,"seasonNumbers":[1,2,3,4],"seasonEpisodeCounts":{"1":10,"2":10,"3":9,"4":10},"eligibleEpisodeCounts":{"1":10,"2":10,"3":9,"4":10},"eligibleEpisodeCount":39,"network":"HBO"}"#)
    static let loveHypothesis = media(#"{"provider":"tmdb","providerId":"1032863","mediaType":"movie","title":"The Love Hypothesis","description":"A scientist tests the one theory she never expected.","posterUrl":"https://image.tmdb.org/t/p/w500/vfZxVHextAGC70zrNhS8lsROqP1.jpg","backdropUrl":"https://image.tmdb.org/t/p/w1280/o7Oy9Gbx1CCyaweL8xUhtMW4Puq.jpg","releaseYear":2026,"genres":["Romance","Comedy"],"communityRating":8.066}"#)
    static let friends = media(#"{"provider":"tmdb","providerId":"1668","mediaType":"tv","title":"Friends","description":"Six friends navigate life, love, and coffee in New York.","posterUrl":"https://image.tmdb.org/t/p/w500/2koX1xLkpTQM4IZebYvKysFW1Nh.jpg","backdropUrl":"https://image.tmdb.org/t/p/w1280/l0qVZIpXtIo7km9u5Yqh0nKPOr5.jpg","releaseYear":1994,"genres":["Comedy"],"communityRating":8.408,"seasonCount":10,"episodeCount":236}"#)
    static let spiderMan = media(#"{"provider":"tmdb","providerId":"969681","mediaType":"movie","title":"Spider-Man: Brand New Day","description":"A new day begins for the friendly neighborhood hero.","posterUrl":"https://image.tmdb.org/t/p/w500/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg","backdropUrl":"https://image.tmdb.org/t/p/w1280/qeQJx07rK2xm8SD2sJxFKhE7gs0.jpg","releaseYear":2026,"genres":["Science Fiction","Action","Adventure"],"communityRating":7.9}"#)
    /// IGDB ratings are stored on a 0–5 scale: 4.4 displays as 8.8 IGDB.
    static let hades = media(#"{"provider":"igdb","providerId":"113112","mediaType":"game","title":"Hades II","description":"Battle beyond the Underworld using dark sorcery to take on the Titan of Time.","releaseYear":2025,"releaseDate":"2025-09-25","genres":["Role-playing (RPG)","Indie"],"communityRating":4.4,"platforms":["PC","Nintendo Switch 2"],"developer":"Supergiant Games","publisher":"Supergiant Games"}"#)
    static let leftHand = media(#"{"provider":"googlebooks","providerId":"volume-42","mediaType":"book","title":"The Left Hand of Darkness","subtitle":"50th Anniversary Edition","description":"A lone human ambassador is sent to Winter, an alien world without gender.","releaseYear":1969,"releaseDate":"1969","genres":["Fiction","Science Fiction"],"communityRating":4.2,"authors":["Ursula K. Le Guin"],"publisher":"Ace","pageCount":304}"#)
    static let longTitle = media(#"{"provider":"mock","providerId":"long-title","mediaType":"tv","title":"The Unreasonably Long Title of a Series That Must Wrap Naturally on Every iPhone","description":"A fixture for title wrapping.","posterUrl":"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg","releaseYear":2024,"genres":["Drama"],"seasonCount":1,"episodeCount":10,"seasonNumbers":[1],"seasonEpisodeCounts":{"1":10}}"#)

    static let all = [digger, succession, loveHypothesis, friends, spiderMan]
    static let catalog = all + [hades, leftHand, longTitle]

    static let discover = CatalogDiscoverResponse(
        items: catalog,
        failures: [],
        sections: [
            CatalogDiscoverySection(id: "tmdb-trending-movie", label: "Trending movies", mediaType: .movie, items: [spiderMan, digger, loveHypothesis]),
            CatalogDiscoverySection(id: "tmdb-trending-tv", label: "Trending series", mediaType: .tv, items: [succession, friends, longTitle]),
            CatalogDiscoverySection(id: "igdb-recent-game", label: "Recent games", mediaType: .game, items: [hades]),
            CatalogDiscoverySection(id: "googlebooks-fiction", label: "Fiction", mediaType: .book, items: [leftHand]),
        ]
    )

    // MARK: Personal

    static let continueStories = [
        continueStory(#"{"id":"tmdb:tv:76331","mediaType":"series","provider":"tmdb","providerId":"76331","title":"Succession","posterUrl":"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg","backdropUrl":"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg","status":"watching","lastActivityAt":"2026-10-11T20:00:00.000Z","progress":{"watchedEpisodes":13,"totalEpisodes":39,"percent":33.3,"nextSeasonNumber":2,"nextEpisodeNumber":4},"nextAction":{"type":"log_episode","seasonNumber":2,"episodeNumber":4}}"#),
        continueStory(#"{"id":"igdb:game:113112","mediaType":"game","provider":"igdb","providerId":"113112","title":"Hades II","status":"playing","lastActivityAt":"2026-10-10T20:00:00.000Z","progress":{"percent":null,"playtimeMinutes":245},"nextAction":{"type":"update_game_playthrough"}}"#),
        continueStory(#"{"id":"googlebooks:book:volume-42","mediaType":"book","provider":"googlebooks","providerId":"volume-42","title":"The Left Hand of Darkness","status":"reading","lastActivityAt":"2026-10-09T09:00:00.000Z","progress":{"currentPage":96,"totalPages":304,"percent":32},"nextAction":{"type":"update_book_progress"}}"#),
        continueStory(#"{"id":"tmdb:tv:1668","mediaType":"series","provider":"tmdb","providerId":"1668","title":"Friends","posterUrl":"https://image.tmdb.org/t/p/w500/2koX1xLkpTQM4IZebYvKysFW1Nh.jpg","status":"watching","lastActivityAt":null,"progress":{"watchedEpisodes":36,"totalEpisodes":null,"percent":null},"nextAction":{"type":"log_episode"}}"#),
    ]

    static let library: [LibraryItemDTO] = decode(#"""
    {"items":[
     {"id":"tmdb:tv:76331","mediaType":"tv","provider":"tmdb","providerId":"76331","title":"Succession","posterUrl":"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg","backdropUrl":"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg","releaseYear":2018,"status":"watching","userRating":4.5,"isFavorite":true,"updatedAt":"2026-10-11T20:00:00.000Z","progress":{"watchedEpisodes":13,"totalEpisodes":39,"percent":33,"nextSeasonNumber":2,"nextEpisodeNumber":4}},
     {"id":"igdb:game:113112","mediaType":"game","provider":"igdb","providerId":"113112","title":"Hades II","releaseYear":2025,"status":"playing","userRating":null,"isFavorite":false,"updatedAt":"2026-10-10T20:00:00.000Z","progress":{"playtimeMinutes":245,"percent":null}},
     {"id":"googlebooks:book:volume-42","mediaType":"book","provider":"googlebooks","providerId":"volume-42","title":"The Left Hand of Darkness","releaseYear":1969,"status":"reading","userRating":null,"isFavorite":true,"updatedAt":"2026-10-09T09:00:00.000Z","progress":{"currentPage":96,"totalPages":304,"percent":32}},
     {"id":"tmdb:movie:1248832","mediaType":"movie","provider":"tmdb","providerId":"1248832","title":"Digger","posterUrl":"https://image.tmdb.org/t/p/w500/1ATXKrIPJyKNwnJ6lcG088Sa6zi.jpg","releaseYear":2026,"status":"watched","userRating":4,"isFavorite":false,"updatedAt":"2026-10-08T10:00:00.000Z"},
     {"id":"tmdb:movie:1032863","mediaType":"movie","provider":"tmdb","providerId":"1032863","title":"The Love Hypothesis","posterUrl":"https://image.tmdb.org/t/p/w500/vfZxVHextAGC70zrNhS8lsROqP1.jpg","releaseYear":2026,"status":"watchlist","userRating":null,"isFavorite":false,"updatedAt":"2026-10-07T10:00:00.000Z"},
     {"id":"tmdb:tv:1668","mediaType":"tv","provider":"tmdb","providerId":"1668","title":"Friends","posterUrl":"https://image.tmdb.org/t/p/w500/2koX1xLkpTQM4IZebYvKysFW1Nh.jpg","releaseYear":1994,"status":"watching","userRating":5,"isFavorite":true,"updatedAt":"2026-10-06T10:00:00.000Z","progress":{"watchedEpisodes":36,"totalEpisodes":null,"percent":null}},
     {"id":"mock:tv:long-title","mediaType":"tv","provider":"mock","providerId":"long-title","title":"The Unreasonably Long Title of a Series That Must Wrap Naturally on Every iPhone","posterUrl":"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg","status":"dropped","userRating":2,"isFavorite":false,"updatedAt":"2026-09-01T10:00:00.000Z","progress":{"watchedEpisodes":0,"totalEpisodes":10,"percent":0}}
    ]}
    """#, as: LibraryResponseDTO.self).items

    static let activity: [ProfileActivity] = decode(#"""
    {"items":[
     {"eventId":"episode:1","media":\#(json(succession)),"occurredAt":"2026-10-11T20:00:00.000Z","eventType":"episode_watch","targetType":"episode","episode":{"seasonNumber":2,"episodeNumber":3},"rating":4.5},
     {"eventId":"game:1","media":\#(json(hades)),"occurredAt":"2026-10-10T20:00:00.000Z","eventType":"game_update","targetType":"playthrough"},
     {"eventId":"book:1","media":\#(json(leftHand)),"occurredAt":"2026-10-09T09:00:00.000Z","eventType":"book_update","targetType":"reading","progressPercent":32},
     {"eventId":"movie-watch:1","media":\#(json(digger)),"occurredAt":"2026-10-08T10:00:00.000Z","eventType":"movie_watch","targetType":"media","rating":4},
     {"eventId":"movie-watch:2","media":\#(json(digger)),"occurredAt":"2026-09-18T10:00:00.000Z","eventType":"movie_watch","targetType":"media","repeatKind":"rewatch"}
    ]}
    """#, as: ProfileActivityResponse.self).items.values

    static let stats: ProfileStatsDTO = decode(#"{"mediaMix":{"movie":2,"tv":3,"game":1,"book":1},"movie":{"watches":2,"rewatches":1,"uniqueMovies":1},"tv":{"uniqueEpisodesWatched":49,"episodeWatchLogs":51,"episodeRewatches":2,"completedSeasons":1,"showsInProgress":2},"game":{"completedPlaythroughs":0,"playtimeMinutes":245},"book":{"finished":0,"pagesRead":96}}"#, as: ProfileStatsDTO.self)

    static let lists: [UserList] = [
        UserList(id: "list-1", title: "Comfort rewatches", description: "Stories for slow Sunday evenings.", visibility: .public, items: [
            .init(id: "i1", media: friends, position: 0, note: "The one with the holiday armadillo."), .init(id: "i2", media: loveHypothesis, position: 1, note: nil), .init(id: "i3", media: leftHand, position: 2, note: nil),
        ], updatedAt: Date(timeIntervalSince1970: 1_791_000_000)),
        UserList(id: "list-2", title: "Winter 2026", description: "", visibility: .private, items: [.init(id: "i4", media: hades, position: 0, note: nil), .init(id: "i5", media: succession, position: 1, note: nil)], updatedAt: Date(timeIntervalSince1970: 1_790_000_000)),
    ]

    static let seriesState: SeriesPersonalState = decode(#"{"status":"watching","isFavorite":true,"userRating":4.5,"episodes":[\#((1...10).map { #"{"seasonNumber":1,"episodeNumber":\#($0),"watchedAt":"2026-09-0\#(min($0, 9))T20:00:00.000Z","rating":null}"# }.joined(separator: ",")),{"seasonNumber":2,"episodeNumber":1,"watchedAt":"2026-10-01T20:00:00.000Z","rating":4},{"seasonNumber":2,"episodeNumber":2,"watchedAt":"2026-10-05T20:00:00.000Z","rating":null},{"seasonNumber":2,"episodeNumber":3,"watchedAt":"2026-10-11T20:00:00.000Z","rating":4.5}],"seasons":[{"seasonNumber":1,"state":"completed","completedOn":"2026-09-09","updatedAt":"2026-09-09T20:00:00.000Z"}]}"#, as: SeriesPersonalState.self)

    static let snapshot: MosaicStateSnapshot = decode(#"""
    {"library":[{"media":\#(json(succession)),"status":"watching"},{"media":\#(json(digger)),"status":"watched"}],
     "ratings":[],"movieWatches":[{"media":\#(json(digger)),"watchedAt":"2026-10-08"}],
     "episodeWatches":[{"series":\#(json(succession)),"watchedAt":"2026-10-11T20:00:00.000Z"}],
     "gamePlaythroughs":[{"id":"00000000-0000-4000-8000-000000000001","media":\#(json(hades)),"status":"playing","platform":"PC","playtimeMinutes":245,"rating":4,"updatedAt":"2026-10-10T20:00:00.000Z"}],
     "bookReadings":[{"id":"00000000-0000-4000-8000-000000000002","media":\#(json(leftHand)),"status":"reading","currentPage":96,"totalPages":304,"progressPercent":32,"updatedAt":"2026-10-09T09:00:00.000Z"}]}
    """#, as: MosaicStateSnapshot.self)

    static func episodes(season: Int) -> [CatalogEpisode] {
        let count = succession.seasonEpisodeCounts?[String(season)] ?? 0
        let titles = ["Celebration", "Shit Show at the Fuck Factory", "Lifeboats", "Sad Sack Wasp Trap", "I Went to Market", "Which Side Are You On?", "Austerlitz", "Prague", "Pre-Nup", "Nobody Is Ever Missing"]
        return (1...max(count, 1)).map { number in
            decode(#"{"id":"s\#(season)e\#(number)","seasonNumber":\#(season),"episodeNumber":\#(number),"title":"\#(season == 1 ? titles[number - 1] : "Episode \(number)")","overview":"The Roys gather as the succession question sharpens.","stillUrl":"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg","airDate":"2018-06-\#(String(format: "%02d", min(number + 2, 28)))","runtimeMinutes":\#(55 + number % 6),"publicRating":\#(7.6 + Double(number % 4) / 10)}"#, as: CatalogEpisode.self)
        }
    }

    // MARK: Services

    /// Mutations made while browsing fixtures; never sent anywhere.
    @MainActor static var recordedMutations: [DetailMutation] = []

    @MainActor static func services(state: String) -> MosaicServices {
        let failure = MosaicAPIError.network("Fixture: offline")
        func personal<T>(_ value: T, empty: T) -> @MainActor () async throws -> T {
            { try await Task.sleep(for: .milliseconds(150)); if state == "error" { throw failure }; return state == "empty" ? empty : value }
        }
        return MosaicServices(
            continueItems: personal(continueStories, empty: []),
            library: personal(library, empty: []),
            activity: { limit in try await personal(Array(activity.prefix(limit)), empty: [])() },
            stats: personal(stats, empty: decode(#"{"mediaMix":{"movie":0,"tv":0,"game":0,"book":0},"movie":{"watches":0,"rewatches":0,"uniqueMovies":0},"tv":{"uniqueEpisodesWatched":0,"episodeWatchLogs":0,"episodeRewatches":0,"completedSeasons":0,"showsInProgress":0},"game":{"completedPlaythroughs":0,"playtimeMinutes":0},"book":{"finished":0,"pagesRead":0}}"#, as: ProfileStatsDTO.self)),
            lists: personal(lists, empty: []),
            stateSnapshot: personal(snapshot, empty: MosaicStateSnapshot()),
            seriesState: { _ in try await personal(seriesState, empty: decode(#"{"status":null,"isFavorite":false,"userRating":null,"episodes":[],"seasons":[]}"#, as: SeriesPersonalState.self))() },
            mutate: { mutation in recordedMutations.append(mutation) },
            discover: { if state == "error" { throw failure }; return discover },
            genre: { type, _ in CatalogSearchResponse(items: catalog.filter { $0.mediaType == type }, failures: []) },
            theme: { _, type in CatalogSearchResponse(items: catalog.filter { type == nil || $0.mediaType == type }, failures: []) },
            related: { route in CatalogSearchResponse(items: catalog.filter { $0.mediaType == route.mediaType && $0.route != route }, failures: []) },
            search: { query, filter in
                try await Task.sleep(for: .milliseconds(200))
                return CatalogSearchResponse(items: catalog.filter { (filter.catalogType == nil || $0.mediaType.rawValue == filter.catalogType) && $0.title.localizedCaseInsensitiveContains(query) }, failures: [])
            },
            detail: { route in
                guard let media = catalog.first(where: { $0.route == route }) else { throw MosaicAPIError.notFound("Fixture missing") }
                return media
            },
            season: { route in CatalogSeasonResponse(episodes: episodes(season: route.seasonNumber)) }
        )
    }

    // MARK: Helpers

    private static func media(_ json: String) -> CatalogMedia { decode(json, as: CatalogMedia.self) }
    private static func continueStory(_ json: String) -> ContinueStory { ContinueStory(dto: decode(json, as: ContinueItemDTO.self)) }
    private static func json(_ media: CatalogMedia) -> String { String(decoding: try! JSONEncoder().encode(media), as: UTF8.self) }
    private static func decode<T: Decodable>(_ json: String, as type: T.Type) -> T {
        do { return try JSONDecoder.mosaic.decode(T.self, from: Data(json.utf8)) }
        catch { fatalError("Invalid fixture \(T.self): \(error)") }
    }
}

/// Hosts the real `AppShell` (or a single pushed screen) on fixture services.
struct MosaicFixtureRoot: View {
    let configuration: MosaicVisualFixtures.Configuration
    @State private var session = SessionStore.fixture(user: CurrentUser(id: "fixture", profile: Profile(displayName: "Shan Mosaic", username: "shan", avatarURL: nil)))

    var body: some View {
        content
            .environment(session)
            .dynamicTypeSize(configuration.accessibility ? .accessibility3 : .large)
    }

    @ViewBuilder private var content: some View {
        let services = MosaicVisualFixtures.services(state: configuration.state)
        switch configuration.screen {
        case "season":
            standalone(services) { SeasonExperienceView(series: MosaicVisualFixtures.succession, seasonNumber: 1) }
        default:
            AppShell(services: services, router: router)
        }
    }

    private var router: MosaicRouter {
        let fixtures = MosaicVisualFixtures.self
        switch configuration.screen {
        case "discover": return MosaicRouter(selectedTab: .discover)
        case "library", "library-list": return MosaicRouter(selectedTab: .library)
        case "profile": return MosaicRouter(selectedTab: .profile)
        case "search": return MosaicRouter(selectedTab: .search)
        case "detail-movie": return MosaicRouter(selectedTab: .home, paths: [.home: [.media(fixtures.digger)]])
        case "detail-game": return MosaicRouter(selectedTab: .home, paths: [.home: [.media(fixtures.hades)]])
        case "detail-book": return MosaicRouter(selectedTab: .home, paths: [.home: [.media(fixtures.leftHand)]])
        case "series": return MosaicRouter(selectedTab: .home, paths: [.home: [.media(fixtures.succession)]])
        case "long-title": return MosaicRouter(selectedTab: .home, paths: [.home: [.media(fixtures.longTitle)]])
        case "lists": return MosaicRouter(selectedTab: .profile, paths: [.profile: [.lists]])
        case "list": return MosaicRouter(selectedTab: .profile, paths: [.profile: [.list(fixtures.lists[0])]])
        case "activity": return MosaicRouter(selectedTab: .profile, paths: [.profile: [.activity]])
        case "settings": return MosaicRouter(selectedTab: .profile, paths: [.profile: [.settings]])
        case "quicklog":
            let router = MosaicRouter(selectedTab: .home)
            router.isQuickLogPresented = true
            return router
        default: return MosaicRouter(selectedTab: .home)
        }
    }

    private func standalone<Content: View>(_ services: MosaicServices, @ViewBuilder content: () -> Content) -> some View {
        let library = LibraryStore()
        library.seed(MosaicVisualFixtures.library)
        return NavigationStack { content().mosaicDestinations() }
            .environment(\.mosaicServices, services)
            .environment(library)
            .environment(MosaicRouter())
    }
}
#endif

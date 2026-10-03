#if DEBUG
import SwiftUI

/// A simulator-only gallery for visual regression checks. It is never reachable in
/// production: launch the DEBUG app with `-mosaic-visual-fixtures`.
enum MosaicVisualFixtures {
    static let digger = media("{\"provider\":\"tmdb\",\"providerId\":\"1248832\",\"mediaType\":\"movie\",\"title\":\"Digger\",\"description\":\"A bright new chapter begins underground.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/1ATXKrIPJyKNwnJ6lcG088Sa6zi.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/b7t3r39Oll5qPxBKzLZ8eHMBD7l.jpg\",\"releaseYear\":2026,\"genres\":[\"Comedy\",\"Drama\"],\"communityRating\":7.456}")
    static let succession = media("{\"provider\":\"tmdb\",\"providerId\":\"76331\",\"mediaType\":\"tv\",\"title\":\"Succession\",\"description\":\"The Roy family controls the biggest media company in the world.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg\",\"releaseYear\":2018,\"genres\":[\"Drama\",\"Comedy\"],\"communityRating\":8.306,\"seasonCount\":4,\"episodeCount\":39,\"seasonNumbers\":[1,2,3,4],\"seasonEpisodeCounts\":{\"1\":10,\"2\":10,\"3\":9,\"4\":10},\"eligibleEpisodeCount\":39}")
    static let loveHypothesis = media("{\"provider\":\"tmdb\",\"providerId\":\"1032863\",\"mediaType\":\"movie\",\"title\":\"The Love Hypothesis\",\"description\":\"A scientist tests the one theory she never expected.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/vfZxVHextAGC70zrNhS8lsROqP1.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/o7Oy9Gbx1CCyaweL8xUhtMW4Puq.jpg\",\"releaseYear\":2026,\"genres\":[\"Romance\",\"Comedy\"],\"communityRating\":8.066}")
    static let friends = media("{\"provider\":\"tmdb\",\"providerId\":\"1668\",\"mediaType\":\"tv\",\"title\":\"Friends\",\"description\":\"Six friends navigate life, love, and coffee in New York.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/2koX1xLkpTQM4IZebYvKysFW1Nh.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/l0qVZIpXtIo7km9u5Yqh0nKPOr5.jpg\",\"releaseYear\":1994,\"genres\":[\"Comedy\"],\"communityRating\":8.408,\"seasonCount\":10,\"episodeCount\":236}")
    static let daredevil = media("{\"provider\":\"mock\",\"providerId\":\"daredevil\",\"mediaType\":\"tv\",\"title\":\"Daredevil\",\"description\":\"A blind lawyer fights for justice in Hell's Kitchen.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg\",\"releaseYear\":2015,\"genres\":[\"Crime\",\"Drama\"],\"communityRating\":8.1,\"seasonCount\":3,\"episodeCount\":39}")
    static let spiderMan = media("{\"provider\":\"tmdb\",\"providerId\":\"969681\",\"mediaType\":\"movie\",\"title\":\"Spider-Man: Brand New Day\",\"description\":\"A new day begins for the friendly neighborhood hero.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/qeQJx07rK2xm8SD2sJxFKhE7gs0.jpg\",\"releaseYear\":2026,\"genres\":[\"Science Fiction\",\"Action\",\"Adventure\"],\"communityRating\":7.9}")
    static let longTitle = media("{\"provider\":\"mock\",\"providerId\":\"long-title\",\"mediaType\":\"tv\",\"title\":\"The Unreasonably Long Title of a Series That Must Wrap Naturally on Every iPhone\",\"description\":\"A fixture for title wrapping.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg\",\"releaseYear\":2024,\"genres\":[\"Drama\"],\"seasonCount\":1,\"episodeCount\":10,\"seasonNumbers\":[1],\"seasonEpisodeCounts\":{\"1\":10}}")
    static let missingBackdrop = media("{\"provider\":\"mock\",\"providerId\":\"poster-only\",\"mediaType\":\"tv\",\"title\":\"Poster Only\",\"description\":\"A fixture for intentional poster fallback composition.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg\",\"releaseYear\":2024,\"genres\":[\"Drama\"],\"seasonCount\":1,\"episodeCount\":10,\"seasonNumbers\":[1],\"seasonEpisodeCounts\":{\"1\":10}}")
    static let continueStories = [
        continueStory("{\"id\":\"continue-succession\",\"mediaType\":\"series\",\"provider\":\"tmdb\",\"providerId\":\"76331\",\"title\":\"Succession\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg\",\"status\":\"watching\",\"lastActivityAt\":null,\"progress\":{\"watchedEpisodes\":13,\"totalEpisodes\":39,\"percent\":33.3,\"nextSeasonNumber\":2,\"nextEpisodeNumber\":3},\"nextAction\":{\"type\":\"episode.log\",\"seasonNumber\":2,\"episodeNumber\":3}}"),
        continueStory("{\"id\":\"continue-daredevil\",\"mediaType\":\"series\",\"provider\":\"mock\",\"providerId\":\"daredevil\",\"title\":\"Daredevil\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg\",\"status\":\"watching\",\"lastActivityAt\":null,\"progress\":{\"watchedEpisodes\":8,\"totalEpisodes\":39,\"percent\":20.5,\"nextSeasonNumber\":1,\"nextEpisodeNumber\":9},\"nextAction\":{\"type\":\"episode.log\",\"seasonNumber\":1,\"episodeNumber\":9}}"),
        continueStory("{\"id\":\"continue-friends\",\"mediaType\":\"series\",\"provider\":\"tmdb\",\"providerId\":\"1668\",\"title\":\"Friends\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/2koX1xLkpTQM4IZebYvKysFW1Nh.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/l0qVZIpXtIo7km9u5Yqh0nKPOr5.jpg\",\"status\":\"watching\",\"lastActivityAt\":null,\"progress\":{\"watchedEpisodes\":36,\"totalEpisodes\":236,\"percent\":15.3,\"nextSeasonNumber\":2,\"nextEpisodeNumber\":13},\"nextAction\":{\"type\":\"episode.log\",\"seasonNumber\":2,\"episodeNumber\":13}}")
    ]
    static let all = [digger, succession, loveHypothesis, friends, spiderMan]

    private static func media(_ json: String) -> CatalogMedia {
        try! JSONDecoder().decode(CatalogMedia.self, from: Data(json.utf8))
    }

    private static func continueStory(_ json: String) -> ContinueStory {
        ContinueStory(dto: try! JSONDecoder().decode(ContinueItemDTO.self, from: Data(json.utf8)))
    }
}

struct MosaicVisualFixtureGallery: View {
    private enum FixtureTab: Hashable { case home, discover, log, library, profile, detail, series, season, episode, longTitle, missingBackdrop }
    @State private var selectedTab: FixtureTab
    @State private var activeTab: FixtureTab
    @State private var showsLog = false
    private let accessibilityAudit: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let initial: FixtureTab
        switch arguments.firstIndex(of: "-mosaic-visual-screen").flatMap({ arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }) {
        case "home-lower": initial = .home
        case "discover": initial = .discover
        case "library": initial = .library
        case "profile": initial = .profile
        case "detail": initial = .detail
        case "series": initial = .series
        case "season": initial = .season
        case "episode": initial = .episode
        case "long-title": initial = .longTitle
        case "missing-backdrop": initial = .missingBackdrop
        default: initial = .home
        }
        _selectedTab = State(initialValue: initial)
        _activeTab = State(initialValue: initial)
        accessibilityAudit = arguments.contains("-mosaic-visual-accessibility")
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .detail: FixtureDetail()
            case .series: FixtureSeriesHub(media: MosaicVisualFixtures.succession)
            case .season: FixtureSeason(media: MosaicVisualFixtures.succession)
            case .episode: FixtureEpisode(media: MosaicVisualFixtures.succession)
            case .longTitle: FixtureSeriesHub(media: MosaicVisualFixtures.longTitle)
            case .missingBackdrop: FixtureSeriesHub(media: MosaicVisualFixtures.missingBackdrop)
            default: tabs
            }
        }
        .dynamicTypeSize(accessibilityAudit ? .accessibility3 : .large)
        .preferredColorScheme(.dark)
        .tint(MosaicColor.accent)
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            FixtureHome(lowerContentOnly: ProcessInfo.processInfo.arguments.contains("-mosaic-visual-home-lower")).tabItem { Label("Home", systemImage: "house.fill") }.tag(FixtureTab.home)
            FixtureDiscover().tabItem { Label("Discover", systemImage: "sparkles") }.tag(FixtureTab.discover)
            Color.clear.accessibilityHidden(true).tabItem { Label("Log", systemImage: "plus") }.tag(FixtureTab.log)
            FixtureLibrary().tabItem { Label("Library", systemImage: "books.vertical.fill") }.tag(FixtureTab.library)
            FixtureProfile().tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(FixtureTab.profile)
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .log { showsLog = true; selectedTab = activeTab } else { activeTab = tab }
        }
        .sheet(isPresented: $showsLog) { FixtureLogSheet() }
    }
}

private struct FixtureHome: View {
    let lowerContentOnly: Bool
    var body: some View { GeometryReader { viewport in MosaicScreen {
        if !lowerContentOnly {
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicEyebrow(title: "Your mosaic")
                Text("Good evening").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
            }.padding(.horizontal, MosaicLayout.pageHorizontal)
            FixtureHero(media: MosaicVisualFixtures.digger)
        }
        FixtureContinueRail(stories: MosaicVisualFixtures.continueStories, viewportWidth: viewport.size.width)
        FixtureActivity(title: "Recently logged", eyebrow: "Your story", items: [MosaicVisualFixtures.loveHypothesis, MosaicVisualFixtures.digger])
    } } }
}

private struct FixtureDiscover: View {
    var body: some View { MosaicScreen {
        VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicEyebrow(title: "Explore every medium"); Text("Discover").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText) }.padding(.horizontal, MosaicLayout.pageHorizontal)
        FixtureHero(media: MosaicVisualFixtures.spiderMan)
        FixtureRail(title: "Trending now", eyebrow: "Across Mosaic", items: MosaicVisualFixtures.all)
    } }
}

private struct FixtureLibrary: View {
    private let columns = [GridItem(.flexible(), spacing: MosaicSpace.medium), GridItem(.flexible())]
    var body: some View { MosaicScreen {
        VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicEyebrow(title: "Your collection"); Text("Library").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText); Text("5 saved stories").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }.padding(.horizontal, MosaicLayout.pageHorizontal)
        FixturePulse()
        FixtureRail(title: "In progress", eyebrow: "Keep going", items: [MosaicVisualFixtures.succession, MosaicVisualFixtures.friends])
        MosaicSectionHeader("Collection", eyebrow: "All stories")
        LazyVGrid(columns: columns, spacing: MosaicSpace.large) { ForEach(MosaicVisualFixtures.all) { FixtureLibraryTile(media: $0) } }.padding(.horizontal, MosaicLayout.pageHorizontal)
    } }
}

private struct FixtureProfile: View {
    var body: some View { MosaicScreen {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            HStack(spacing: MosaicSpace.medium) { Image(systemName: "person.crop.circle.fill").font(.system(size: 58)).foregroundStyle(MosaicColor.accent); VStack(alignment: .leading) { Text("Mosaic member").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text("5 stories logged").foregroundStyle(MosaicColor.secondaryText) } }
            Divider().overlay(MosaicColor.border)
            HStack { FixtureStat(value: "5", label: "Saved"); Spacer(); FixtureStat(value: "3", label: "Watched"); Spacer(); FixtureStat(value: "2", label: "In progress") }
        }.padding(.horizontal, MosaicLayout.pageHorizontal)
        FixtureRail(title: "Favourite stories", eyebrow: "Your taste", items: [MosaicVisualFixtures.succession, MosaicVisualFixtures.loveHypothesis, MosaicVisualFixtures.friends])
        VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicSectionHeader("Recent activity", eyebrow: "This week"); ForEach(MosaicVisualFixtures.all.prefix(2)) { media in Text("Added \(media.title)").foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, MosaicLayout.pageHorizontal) } }
    } }
}

private struct FixtureDetail: View {
    private let media: CatalogMedia

    init() {
        media = ProcessInfo.processInfo.arguments.contains("-mosaic-visual-movie-detail")
            ? MosaicVisualFixtures.spiderMan
            : MosaicVisualFixtures.succession
    }

    var body: some View { MosaicScreen {
        MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: media.mediaType.symbolName).containerRelativeFrame(.horizontal) { length, _ in length - (MosaicLayout.pageHorizontal * 2) }.frame(height: 260).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicEyebrow(title: "\(media.mediaType.displayName) · \(media.releaseYear ?? 0)"); Text(media.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); HStack { MosaicRating(value: media.communityRating ?? 0); Text(media.mediaType == .tv ? "4 seasons · 39 episodes" : "Now in cinemas").font(MosaicType.metadata).foregroundStyle(MosaicColor.secondaryText) }; Text(media.description ?? "").foregroundStyle(MosaicColor.secondaryText); HStack { MosaicGlassControl { Label("In library", systemImage: "checkmark") }; MosaicGlassControl { Image(systemName: "ellipsis") } } }
            .containerRelativeFrame(.horizontal) { length, _ in length - (MosaicLayout.pageHorizontal * 2) }
        MosaicSectionHeader(media.mediaType == .tv ? "Episodes" : "More like this", eyebrow: media.mediaType == .tv ? "Continue watching" : "Explore")
        HStack(spacing: MosaicSpace.medium) { MosaicArtwork(url: media.posterURL, symbol: media.mediaType.symbolName).frame(width: 100, height: 145).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media)); VStack(alignment: .leading, spacing: MosaicSpace.small) { Text(media.mediaType == .tv ? "S1 · E1" : "Featured story").font(.caption.weight(.bold)).foregroundStyle(MosaicColor.accent); Text(media.mediaType == .tv ? "Celebration" : "Brand New Day").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text(media.mediaType == .tv ? "The family gathers to decide what comes next." : "A new day begins for the friendly neighborhood hero.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) } }.containerRelativeFrame(.horizontal) { length, _ in length - (MosaicLayout.pageHorizontal * 2) }
    } }
}

private struct FixtureSeriesHub: View {
    let media: CatalogMedia
    var body: some View { MosaicScreen {
        FixtureSeriesHero(media: media)
        VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicEyebrow(title: "Series"); Text(media.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText).fixedSize(horizontal: false, vertical: true); Text("2018 · Drama · Comedy · HBO").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }.padding(.horizontal, MosaicLayout.pageHorizontal)
        VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicSectionHeader("Your story"); Text("Watching").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text("13 of 39 episodes · Next · S02E03").font(.subheadline).foregroundStyle(MosaicColor.secondaryText); ProgressView(value: 13, total: 39).tint(MosaicColor.accent); HStack { MosaicGlassControl { Label("Log next episode", systemImage: "plus") }; MosaicGlassControl { Label("Status", systemImage: "ellipsis") } } }.padding(.horizontal, MosaicLayout.pageHorizontal)
        VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicSectionHeader("Seasons", eyebrow: "Episode guide"); ForEach(1...4, id: \.self) { number in FixtureSeasonRow(media: media, season: number, watched: number == 1 ? 8 : number == 2 ? 5 : 0, total: number == 3 ? 9 : 10) } }.padding(.horizontal, MosaicLayout.pageHorizontal)
    } }
}

private struct FixtureSeriesHero: View { let media: CatalogMedia; var body: some View { Group { if media.backdropURL != nil { MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: "tv") } else { ZStack { LinearGradient(colors: [MosaicColor.surface, MosaicColor.elevated], startPoint: .topLeading, endPoint: .bottomTrailing); MosaicArtwork(url: media.posterURL, symbol: "tv").frame(width: 116).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.control)) } } }.aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous)).padding(.horizontal, MosaicLayout.pageHorizontal) } }
private struct FixtureSeasonRow: View { let media: CatalogMedia; let season, watched, total: Int; var body: some View { HStack(spacing: MosaicSpace.medium) { MosaicArtwork(url: media.posterURL, symbol: "tv").frame(width: 52, height: 72).clipShape(RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 5) { Text("Season \(season)").font(.headline).foregroundStyle(MosaicColor.primaryText); Text("\(watched) / \(total) watched").font(.footnote).foregroundStyle(MosaicColor.secondaryText); ProgressView(value: Double(watched), total: Double(total)).tint(MosaicColor.accent) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(MosaicColor.mutedText) }.padding(MosaicSpace.small).background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.control)) } }
private struct FixtureSeason: View { let media: CatalogMedia; var body: some View { MosaicScreen { VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicEyebrow(title: media.title); Text("Season 1").font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); Text("8 / 10 watched · Watching").foregroundStyle(MosaicColor.secondaryText); ProgressView(value: 8, total: 10).tint(MosaicColor.accent) }.padding(.horizontal, MosaicLayout.pageHorizontal); ForEach(1...10, id: \.self) { number in FixtureEpisodeRow(media: media, number: number, watched: number <= 8) } } } }
private struct FixtureEpisodeRow: View { let media: CatalogMedia; let number: Int; let watched: Bool; var body: some View { HStack(spacing: MosaicSpace.medium) { MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: "tv").frame(width: 104, height: 62).clipShape(RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 4) { Text("S01E\(String(format: "%02d", number))").font(.caption.weight(.bold)).foregroundStyle(MosaicColor.accent); Text(number == 1 ? "Celebration" : "Episode \(number)").font(.headline).foregroundStyle(MosaicColor.primaryText); Text("58 min · 2018-06-03 · ★ 8.4").font(.caption).foregroundStyle(MosaicColor.secondaryText) }; Spacer(); Image(systemName: watched ? "checkmark.circle.fill" : "circle").foregroundStyle(watched ? MosaicColor.accent : MosaicColor.mutedText) }.padding(.horizontal, MosaicLayout.pageHorizontal) } }
private struct FixtureEpisode: View { let media: CatalogMedia; var body: some View { MosaicScreen { FixtureSeriesHero(media: media); VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicEyebrow(title: "Succession · Season 1 · Episode 1"); Text("Celebration").font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); Text("2018-06-03 · 58 min · Public rating 8.4").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }.padding(.horizontal, MosaicLayout.pageHorizontal); VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicSectionHeader("Your episode"); Label("Watched · Rated 4 stars", systemImage: "checkmark.circle.fill").foregroundStyle(MosaicColor.accent); MosaicGlassControl { Label("Unwatch", systemImage: "arrow.uturn.backward") } }.padding(.horizontal, MosaicLayout.pageHorizontal) } } }

private struct FixtureLogSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { ContentUnavailableView("Log something", systemImage: "plus.circle", description: Text("Search the catalog to add it to your story.")).navigationTitle("Add to your story").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: dismiss.callAsFunction) } } }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible) } }
private struct FixtureHero: View { let media: CatalogMedia; var body: some View { ZStack(alignment: .bottomLeading) { MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: media.mediaType.symbolName); LinearGradient(colors: [.clear, MosaicColor.background.opacity(0.94)], startPoint: .center, endPoint: .bottom); VStack(alignment: .leading, spacing: 5) { MosaicEyebrow(title: "Featured"); Text(media.title).font(.system(.title, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); Text(media.resultMetadata).font(.footnote).foregroundStyle(MosaicColor.secondaryText) }.padding(MosaicSpace.medium) }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous)).padding(.horizontal, MosaicLayout.pageHorizontal) } }
private struct FixtureRail: View { let title: String; let eyebrow: String; let items: [CatalogMedia]; var body: some View { VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicSectionHeader(title, eyebrow: eyebrow); ScrollView(.horizontal) { LazyHStack(spacing: MosaicSpace.medium) { ForEach(items) { DiscoverPoster(media: $0) } }.padding(.horizontal, MosaicLayout.pageHorizontal) }.scrollIndicators(.hidden) } } }
private struct FixtureContinueRail: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let stories: [ContinueStory]
    let viewportWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Continue your stories", eyebrow: "In progress")
            ScrollView(.horizontal) {
                LazyHStack(spacing: MosaicSpace.medium) {
                    Color.clear.frame(width: MosaicLayout.pageHorizontal)
                    ForEach(stories) { story in
                        ContinueStoryCard(story: story, width: ContinueCardLayout.width(for: viewportWidth))
                    }
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: ContinueCardLayout.height(for: dynamicTypeSize))
        }
    }
}
private struct FixtureActivity: View { let title: String; let eyebrow: String; let items: [CatalogMedia]; var body: some View { VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicSectionHeader(title, eyebrow: eyebrow); ForEach(items) { media in HStack(spacing: MosaicSpace.medium) { MosaicArtwork(url: media.posterURL, fallbackURL: media.backdropURL, symbol: media.mediaType.symbolName).frame(width: 48, height: 64).clipShape(RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 3) { Text(media.title).font(.headline).foregroundStyle(MosaicColor.primaryText); Text("Added to your library").font(.footnote).foregroundStyle(MosaicColor.secondaryText) }; Spacer(minLength: 0) }.padding(.horizontal, MosaicLayout.pageHorizontal) } } } }
private struct FixturePulse: View { var body: some View { VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicSectionHeader("Library Pulse", eyebrow: "This month"); HStack(spacing: MosaicSpace.medium) { FixturePulseValue(value: "5", label: "Saved"); FixturePulseValue(value: "3", label: "Finished") }.padding(.horizontal, MosaicLayout.pageHorizontal) } } }
private struct FixturePulseValue: View { let value: String; let label: String; var body: some View { VStack(alignment: .leading, spacing: 5) { Text(value).font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text(label).font(.caption).foregroundStyle(MosaicColor.secondaryText) }.frame(maxWidth: .infinity, alignment: .leading).padding(MosaicSpace.medium).background(MosaicColor.surface, in: RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous)) } }
private struct FixtureLibraryTile: View { let media: CatalogMedia; var body: some View { VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicArtwork(url: media.posterURL, fallbackURL: media.backdropURL, symbol: media.mediaType.symbolName).frame(height: 230).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media)); Text(media.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2); Text(media.resultMetadata).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1) } } }
private struct FixtureStat: View { let value: String; let label: String; var body: some View { VStack(spacing: 3) { Text(value).font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text(label).font(.caption).foregroundStyle(MosaicColor.secondaryText) } } }
#endif

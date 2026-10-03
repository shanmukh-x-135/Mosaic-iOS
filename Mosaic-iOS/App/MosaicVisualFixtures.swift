#if DEBUG
import SwiftUI

/// A simulator-only gallery for visual regression checks. It is never reachable in
/// production: launch the DEBUG app with `-mosaic-visual-fixtures`.
enum MosaicVisualFixtures {
    static let digger = media("{\"provider\":\"tmdb\",\"providerId\":\"1248832\",\"mediaType\":\"movie\",\"title\":\"Digger\",\"description\":\"A bright new chapter begins underground.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/1ATXKrIPJyKNwnJ6lcG088Sa6zi.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/b7t3r39Oll5qPxBKzLZ8eHMBD7l.jpg\",\"releaseYear\":2026,\"genres\":[\"Comedy\",\"Drama\"],\"communityRating\":7.456}")
    static let succession = media("{\"provider\":\"tmdb\",\"providerId\":\"76331\",\"mediaType\":\"tv\",\"title\":\"Succession\",\"description\":\"The Roy family controls the biggest media company in the world.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/z0XiwdrCQ9yVIr4O0pxzaAYRxdW.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/d87JXX3DLkRJMfm5StCmmnmhHuX.jpg\",\"releaseYear\":2018,\"genres\":[\"Drama\",\"Comedy\"],\"communityRating\":8.306,\"seasonCount\":4,\"episodeCount\":39}")
    static let loveHypothesis = media("{\"provider\":\"tmdb\",\"providerId\":\"1032863\",\"mediaType\":\"movie\",\"title\":\"The Love Hypothesis\",\"description\":\"A scientist tests the one theory she never expected.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/vfZxVHextAGC70zrNhS8lsROqP1.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/o7Oy9Gbx1CCyaweL8xUhtMW4Puq.jpg\",\"releaseYear\":2026,\"genres\":[\"Romance\",\"Comedy\"],\"communityRating\":8.066}")
    static let friends = media("{\"provider\":\"tmdb\",\"providerId\":\"1668\",\"mediaType\":\"tv\",\"title\":\"Friends\",\"description\":\"Six friends navigate life, love, and coffee in New York.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/2koX1xLkpTQM4IZebYvKysFW1Nh.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/l0qVZIpXtIo7km9u5Yqh0nKPOr5.jpg\",\"releaseYear\":1994,\"genres\":[\"Comedy\"],\"communityRating\":8.408,\"seasonCount\":10,\"episodeCount\":236}")
    static let spiderMan = media("{\"provider\":\"tmdb\",\"providerId\":\"969681\",\"mediaType\":\"movie\",\"title\":\"Spider-Man: Brand New Day\",\"description\":\"A new day begins for the friendly neighborhood hero.\",\"posterUrl\":\"https://image.tmdb.org/t/p/w500/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg\",\"backdropUrl\":\"https://image.tmdb.org/t/p/w1280/qeQJx07rK2xm8SD2sJxFKhE7gs0.jpg\",\"releaseYear\":2026,\"genres\":[\"Science Fiction\",\"Action\",\"Adventure\"],\"communityRating\":7.9}")
    static let all = [digger, succession, loveHypothesis, friends, spiderMan]

    private static func media(_ json: String) -> CatalogMedia {
        try! JSONDecoder().decode(CatalogMedia.self, from: Data(json.utf8))
    }
}

struct MosaicVisualFixtureGallery: View {
    private enum FixtureTab: Hashable { case home, discover, log, library, profile, detail }
    @State private var selectedTab: FixtureTab
    @State private var activeTab: FixtureTab
    @State private var showsLog = false
    private let accessibilityAudit: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let initial: FixtureTab
        switch arguments.firstIndex(of: "-mosaic-visual-screen").flatMap({ arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }) {
        case "discover": initial = .discover
        case "library": initial = .library
        case "profile": initial = .profile
        case "detail": initial = .detail
        default: initial = .home
        }
        _selectedTab = State(initialValue: initial)
        _activeTab = State(initialValue: initial)
        accessibilityAudit = arguments.contains("-mosaic-visual-accessibility")
    }

    var body: some View {
        Group {
            if selectedTab == .detail {
                FixtureDetail()
            } else {
                tabs
            }
        }
        .dynamicTypeSize(accessibilityAudit ? .accessibility3 : .large)
        .preferredColorScheme(.dark)
        .tint(MosaicColor.accent)
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            FixtureHome().tabItem { Label("Home", systemImage: "house.fill") }.tag(FixtureTab.home)
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
    var body: some View { MosaicScreen {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            MosaicEyebrow(title: "Your mosaic")
            Text("Good evening").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
        }.padding(.horizontal, MosaicLayout.pageHorizontal)
        FixtureHero(media: MosaicVisualFixtures.digger)
        FixtureRail(title: "Continue watching", eyebrow: "Keep going", items: [MosaicVisualFixtures.succession, MosaicVisualFixtures.friends, MosaicVisualFixtures.spiderMan])
        FixtureRail(title: "For you", eyebrow: "Picked for tonight", items: [MosaicVisualFixtures.loveHypothesis, MosaicVisualFixtures.digger])
    } }
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
    private let media = MosaicVisualFixtures.succession
    var body: some View { MosaicScreen {
        MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: media.mediaType.symbolName).containerRelativeFrame(.horizontal) { length, _ in length - (MosaicLayout.pageHorizontal * 2) }.frame(height: 260).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicEyebrow(title: "Series · 2018"); Text(media.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); HStack { MosaicRating(value: media.communityRating ?? 0); Text("4 seasons · 39 episodes").font(MosaicType.metadata).foregroundStyle(MosaicColor.secondaryText) }; Text(media.description ?? "").foregroundStyle(MosaicColor.secondaryText); HStack { MosaicGlassControl { Label("In library", systemImage: "checkmark") }; MosaicGlassControl { Image(systemName: "ellipsis") } } }
            .containerRelativeFrame(.horizontal) { length, _ in length - (MosaicLayout.pageHorizontal * 2) }
        MosaicSectionHeader("Episodes", eyebrow: "Continue watching")
        HStack(spacing: MosaicSpace.medium) { MosaicArtwork(url: media.posterURL, symbol: "tv").frame(width: 100, height: 145).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media)); VStack(alignment: .leading, spacing: MosaicSpace.small) { Text("S1 · E1").font(.caption.weight(.bold)).foregroundStyle(MosaicColor.accent); Text("Celebration").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text("The family gathers to decide what comes next.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) } }.containerRelativeFrame(.horizontal) { length, _ in length - (MosaicLayout.pageHorizontal * 2) }
    } }
}

private struct FixtureLogSheet: View { @Environment(\.dismiss) private var dismiss; var body: some View { NavigationStack { ContentUnavailableView("Log something", systemImage: "plus.circle", description: Text("Search the catalog to add it to your story.")).navigationTitle("Add to your story").toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: dismiss.callAsFunction) } } }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible) } }
private struct FixtureHero: View { let media: CatalogMedia; var body: some View { ZStack(alignment: .bottomLeading) { MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: media.mediaType.symbolName); LinearGradient(colors: [.clear, MosaicColor.background.opacity(0.94)], startPoint: .center, endPoint: .bottom); VStack(alignment: .leading, spacing: 5) { MosaicEyebrow(title: "Featured"); Text(media.title).font(.system(.title, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); Text(media.resultMetadata).font(.footnote).foregroundStyle(MosaicColor.secondaryText) }.padding(MosaicSpace.medium) }.frame(height: 230).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous)).padding(.horizontal, MosaicLayout.pageHorizontal) } }
private struct FixtureRail: View { let title: String; let eyebrow: String; let items: [CatalogMedia]; var body: some View { VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicSectionHeader(title, eyebrow: eyebrow); ScrollView(.horizontal) { LazyHStack(spacing: MosaicSpace.medium) { ForEach(items) { DiscoverPoster(media: $0) } }.padding(.horizontal, MosaicLayout.pageHorizontal) }.scrollIndicators(.hidden) } } }
private struct FixtureLibraryTile: View { let media: CatalogMedia; var body: some View { VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicArtwork(url: media.posterURL, fallbackURL: media.backdropURL, symbol: media.mediaType.symbolName).frame(height: 230).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media)); Text(media.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2); Text(media.resultMetadata).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1) } } }
private struct FixtureStat: View { let value: String; let label: String; var body: some View { VStack(spacing: 3) { Text(value).font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text(label).font(.caption).foregroundStyle(MosaicColor.secondaryText) } } }
#endif

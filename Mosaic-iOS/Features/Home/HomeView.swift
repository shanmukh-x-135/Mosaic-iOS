import Observation
import SwiftUI

/// Home follows the web's order: discovery reel, Continue, Recently logged,
/// Saved for later, Worth a closer look. Personal sections only show real
/// history; a failed load says so instead of silently disappearing.
struct HomeView: View {
    @Environment(\.mosaicServices) private var services
    var body: some View { HomeScreen(services: services) }
}

private struct HomeScreen: View {
    let services: MosaicServices
    @State private var model: HomeViewModel
    @State private var activity = Loadable<[ProfileActivity]>.idle
    @State private var discovery = Loadable<CatalogDiscoverResponse>.idle
    @Environment(LibraryStore.self) private var library
    @Environment(MosaicRouter.self) private var router

    init(services: MosaicServices) {
        self.services = services
        _model = State(initialValue: HomeViewModel(requestStories: services.continueItems))
    }

    var body: some View {
        MosaicScreen {
            HomeHeader()
            reel
            if personalLoadFailed {
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicNotice(text: "Your progress couldn’t be loaded, so Continue and Recently logged are hidden.", tone: .failure)
                    Button("Try again", action: reloadPersonal).font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
            continueSection
            recentSection
            savedSection
            closerLookSection
        }
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)
        .task {
            model.load()
            if case .idle = activity { await loadActivity() }
            if case .idle = discovery { await loadDiscovery() }
        }
        .refreshable {
            model.retry(); library.refresh(services)
            await loadActivity(); await loadDiscovery()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { _ in
            model.retry(); Task { await loadActivity() }
        }
    }

    private var personalLoadFailed: Bool {
        if case .error = model.state { return true }
        if case .failed = activity { return true }
        return false
    }

    @ViewBuilder private var reel: some View {
        switch discovery {
        case let .loaded(response):
            let picks = HomeDiscoveryPicks.picks(from: response)
            if !picks.isEmpty { SpotlightPager(items: picks, eyebrow: "Discovery pick", source: "One pick from each medium") }
        case .idle, .loading:
            MosaicSkeleton(aspectRatio: 1.15).padding(.horizontal, MosaicLayout.pageHorizontal).accessibilityLabel("Loading discovery")
        case .failed:
            EmptyView()
        }
    }

    @ViewBuilder private var continueSection: some View {
        switch model.state {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Continue your stories", eyebrow: "In progress")
                MosaicSkeleton(aspectRatio: 1.6).padding(.horizontal, MosaicLayout.pageHorizontal)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading your stories")
        case let .loaded(stories):
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Continue your stories", eyebrow: "In progress")
                ContinueRail(stories: stories)
            }
        case .empty:
            HomeEmptyContinue()
        case .error:
            EmptyView()
        }
    }

    @ViewBuilder private var recentSection: some View {
        if case let .loaded(items) = activity, !items.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Recently logged", eyebrow: "Your story") {
                    NavigationLink("View activity", value: MosaicRoute.activity)
                }
                VStack(spacing: MosaicSpace.small) {
                    ForEach(items.prefix(4)) { event in
                        NavigationLink(value: MosaicRoute.media(event.media)) {
                            ActivityEventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
        }
    }

    @ViewBuilder private var savedSection: some View {
        let saved = library.items.filter { $0.libraryStatus?.isPlanned == true }
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Watchlist, backlog & reading list", eyebrow: "Saved for later") {
                    Button("Open Library") { router.select(.library) }
                }
                MosaicRail {
                    ForEach(saved.prefix(12)) { item in
                        NavigationLink(value: MosaicRoute.media(item)) {
                            MosaicPosterCard(summary: MosaicMediaSummary(item, subtitle: item.statusLabel), showsMedium: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var closerLookSection: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Worth a closer look", eyebrow: "A fresh discovery") {
                Button("Browse") { router.select(.discover) }
            }
            switch discovery {
            case let .loaded(response) where !response.items.isEmpty:
                MosaicPosterShelf(items: Array(response.items.prefix(12)), showsMedium: true)
            case .idle, .loading:
                MosaicRail { ForEach(0..<4, id: \.self) { _ in MosaicSkeleton(aspectRatio: MosaicArtworkRatio.poster).frame(width: MosaicLayout.posterWidth) } }
            default:
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    Text("Discovery is temporarily unavailable. Try again shortly.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    Button("Try again") { Task { await loadDiscovery() } }.font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
        }
    }

    private func reloadPersonal() { model.retry(); Task { await loadActivity() } }

    private func loadActivity() async {
        if activity.value == nil { activity = .loading }
        do { activity = .loaded(try await services.activity(6)) }
        catch is CancellationError {}
        catch { if activity.value == nil { activity = .failed(error) } }
    }

    private func loadDiscovery() async {
        if discovery.value == nil { discovery = .loading }
        do { discovery = .loaded(try await services.discover()) }
        catch is CancellationError {}
        catch { if discovery.value == nil { discovery = .failed(error) } }
    }
}

/// One featured pick per medium, so Home's reel is never movie-only.
enum HomeDiscoveryPicks {
    static func picks(from response: CatalogDiscoverResponse) -> [CatalogMedia] {
        DiscoverRails.rails(response.sections, type: nil).compactMap { section in
            section.items.first { $0.backdropURL != nil } ?? section.items.first
        }
    }
}

private struct HomeHeader: View {
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 5 ? "Good evening" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }
    var body: some View {
        HStack(alignment: .center, spacing: MosaicSpace.medium) {
            VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                MosaicEyebrow(title: greeting)
                Text("Every story, in one place").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText).accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            QuickLogButton()
        }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
        .padding(.top, MosaicSpace.small)
    }
}

/// Home's header hosts Quick Log directly because its navigation bar is hidden.
private struct QuickLogButton: View {
    @Environment(MosaicRouter.self) private var router
    var body: some View {
        Button { router.presentQuickLog() } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(MosaicColor.primaryText)
                .frame(width: 36, height: 36)
                .background(MosaicColor.surfaceHover, in: Circle())
                .overlay { Circle().strokeBorder(MosaicColor.highlight) }
                .frame(width: MosaicLayout.minimumTouchTarget, height: MosaicLayout.minimumTouchTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log something")
        .accessibilityHint("Search for a movie, series, game, or book to log")
    }
}

private struct ContinueRail: View {
    let stories: [ContinueStory]
    var body: some View {
        MosaicRail(spacing: MosaicSpace.medium) {
            ForEach(stories) { story in
                NavigationLink(value: MosaicRoute.media(story)) {
                    ContinueStoryCard(story: story, width: nil)
                        // Sized from the rail's visible width, leaving a peek of the next card.
                        .containerRelativeFrame(.horizontal) { length, _ in ContinueCardLayout.width(for: length, gutter: 0) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HomeEmptyContinue: View {
    @Environment(MosaicRouter.self) private var router
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            MosaicEyebrow(title: "In progress")
            Text("Nothing in progress yet").font(MosaicType.section).foregroundStyle(MosaicColor.primaryText)
            Text("Start a series, book, or game and it will appear here with your real progress.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
            Button("Find something to start") { router.select(.discover) }.buttonStyle(.bordered).tint(MosaicColor.accent).padding(.top, MosaicSpace.xxSmall)
        }
        .padding(MosaicSpace.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous).strokeBorder(MosaicColor.border) }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
}

import Observation
import SwiftUI

struct HomeView: View {
    @State private var model: HomeViewModel
    @State private var discovery = DiscoverViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL))
    @State private var library: LibraryViewModel
    @State private var activity: HomeActivityViewModel

    init(session: SessionStore) {
        let client = MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL)
        _model = State(initialValue: HomeViewModel(
            client: client,
            accessToken: { try await session.currentAccessToken() }
        ))
        _library = State(initialValue: LibraryViewModel(client: client, accessToken: { try await session.currentAccessToken() }))
        _activity = State(initialValue: HomeActivityViewModel(client: client, accessToken: { try await session.currentAccessToken() }))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: MosaicSpace.xLarge) {
                    HomeHeader()
                    if case let .loaded(response) = discovery.state, let featured = response.items.first ?? response.sections.flatMap(\.items).first { HomeFeaturedStory(media: featured) }
                    content
                    if case let .loaded(items) = activity.state, !items.isEmpty { HomeActivityRail(items: items) }
                    if case .loaded = library.state { HomeSavedRail(items: library.items) }
                    if case let .loaded(response) = discovery.state, !response.items.isEmpty { HomeDiscoveryRail(items: Array(response.items.prefix(12))) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, MosaicSpace.large)
            }
            .background(MosaicColor.background)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { GlobalSearchLink() } }
            .task { model.load(); discovery.load(); library.load(); activity.load() }
            .refreshable { model.retry(); discovery.retry(); library.refresh(); activity.refresh() }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading: ContinueSkeleton()
        case let .loaded(stories): ContinueRail(stories: stories)
        case .empty: HomeEmptyState()
        case let .error(error): HomeErrorState(error: error, retry: model.retry)
        }
    }
}

private struct HomeHeader: View {
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                MosaicEyebrow(title: greeting)
                Text("Your stories").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
            }
            Spacer()
            Image("MosaicEmblem").resizable().scaledToFit().frame(width: 34, height: 34).accessibilityLabel("Mosaic")
        }
        .padding(.horizontal, MosaicLayout.screenMargin)
    }
}

private struct ContinueRail: View {
    let stories: [ContinueStory]
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Continue your stories", eyebrow: "In progress")
            ScrollView(.horizontal) {
                LazyHStack(spacing: MosaicSpace.medium) {
                    ForEach(stories) { story in
                        NavigationLink {
                            MediaDetailContainer(route: story.detailRoute, preview: MediaDetailPreview(story: story))
                        } label: {
                            ContinueStoryCard(story: story)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, MosaicSpace.large)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ContinueSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Continue your stories", eyebrow: "In progress")
            RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous)
                .fill(MosaicColor.surface)
                .frame(maxWidth: .infinity)
                .frame(height: 228)
                .overlay(alignment: .bottomLeading) { VStack(alignment: .leading, spacing: 10) { Capsule().fill(Color.white.opacity(0.16)).frame(width: 70, height: 10); Capsule().fill(Color.white.opacity(0.18)).frame(width: 180, height: 22); Capsule().fill(Color.white.opacity(0.14)).frame(width: 130, height: 12) }.padding(MosaicSpace.medium) }
                .padding(.horizontal, MosaicSpace.large)
                .redacted(reason: .placeholder)
                .accessibilityLabel("Loading your stories")
        }
        .opacity(reduceMotion ? 1 : 0.88)
    }
}

private struct HomeFeaturedStory: View {
    let media: CatalogMedia
    var body: some View {
        NavigationLink { MediaDetailContainer(route: media.route, preview: MediaDetailPreview(media: media)) } label: {
            ZStack(alignment: .bottomLeading) {
                MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: media.mediaType.symbolName)
                LinearGradient(colors: [.clear, MosaicColor.background.opacity(0.98)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicEyebrow(title: "Discovery pick")
                    Text(media.title).font(MosaicType.hero).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                    HStack(spacing: MosaicSpace.small) { if let year = media.releaseYear { Text(String(year)) }; if let genre = media.genres.first { Text(genre) }; if let rating = media.communityRating { MosaicRating(value: rating) } }.font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                    Label("View story", systemImage: "play.fill").font(.subheadline.weight(.bold)).foregroundStyle(MosaicColor.background).padding(.horizontal, 14).padding(.vertical, 10).background(MosaicColor.primaryText, in: Capsule())
                }.padding(MosaicSpace.large)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
            .padding(.horizontal, MosaicLayout.screenMargin)
        }.buttonStyle(.plain)
    }
}

private struct HomeDiscoveryRail: View {
    let items: [CatalogMedia]
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Worth a closer look", eyebrow: "A fresh discovery")
            ScrollView(.horizontal) { LazyHStack(spacing: MosaicSpace.medium) { ForEach(items) { media in NavigationLink { MediaDetailContainer(route: media.route, preview: MediaDetailPreview(media: media)) } label: { DiscoverPoster(media: media) }.buttonStyle(.plain) } }.padding(.horizontal, MosaicSpace.large) }.scrollIndicators(.hidden)
        }
    }
}

private struct HomeActivityRail: View {
    let items: [ProfileActivity]
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Recently logged", eyebrow: "Your history")
            VStack(spacing: MosaicSpace.small) {
                ForEach(items.prefix(4)) { item in
                    NavigationLink { MediaDetailContainer(route: item.media.route, preview: MediaDetailPreview(media: item.media)) } label: {
                        HStack(spacing: MosaicSpace.medium) {
                            MosaicArtwork(url: item.media.posterURL, fallbackURL: item.media.backdropURL, symbol: item.media.mediaType.symbolName)
                                .frame(width: 48, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.media.title).font(.headline).foregroundStyle(MosaicColor.primaryText).lineLimit(1)
                                Text(item.label).font(.caption).foregroundStyle(MosaicColor.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, MosaicLayout.screenMargin)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct HomeSavedRail: View {
    let items: [LibraryItemDTO]
    private var saved: [LibraryItemDTO] { items.filter { ["watchlist", "backlog", "want_to_read"].contains($0.status) } }
    var body: some View {
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Saved for later", eyebrow: "Your watchlist")
                ScrollView(.horizontal) {
                    LazyHStack(spacing: MosaicSpace.medium) {
                        ForEach(saved.prefix(12)) { item in
                            NavigationLink { MediaDetailContainer(route: item.route, preview: MediaDetailPreview(library: item)) } label: {
                                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                                    MosaicArtwork(url: item.posterURL, fallbackURL: item.backdropURL, symbol: item.mediaType.symbolName)
                                        .frame(width: MosaicLayout.posterWidth, height: MosaicLayout.posterHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
                                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(1).frame(width: MosaicLayout.posterWidth, alignment: .leading)
                                }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, MosaicLayout.screenMargin)
                }.scrollIndicators(.hidden).frame(maxWidth: .infinity)
            }
        }
    }
}

@MainActor @Observable
private final class HomeActivityViewModel {
    enum State { case idle, loading, loaded([ProfileActivity]), failed }
    private let request: @MainActor () async throws -> [ProfileActivity]
    private var task: Task<Void, Never>?
    private(set) var state: State = .idle
    init(client: MosaicAPIClient, accessToken: @escaping @MainActor () async throws -> String) {
        request = { let token = try await accessToken(); return try await client.request("/api/me/activity?limit=4", token: token, as: ProfileActivityResponse.self).items }
    }
    func load() {
        guard task == nil else { return }
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }; defer { self.task = nil }
            do { self.state = .loaded(try await self.request()) }
            catch is CancellationError { self.state = .idle }
            catch { self.state = .failed }
        }
    }
    func refresh() { task?.cancel(); task = nil; state = .idle; load() }
}

private struct HomeEmptyState: View {
    var body: some View {
        ContentUnavailableView("Nothing in progress yet", systemImage: "play.rectangle", description: Text("Start a series, book, or game and it will appear here."))
            .foregroundStyle(MosaicColor.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 310)
            .padding(.horizontal, MosaicSpace.large)
    }
}

private struct HomeErrorState: View {
    let error: HomeErrorPresentation
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            Text(error.title).font(MosaicType.title).foregroundStyle(MosaicColor.primaryText)
            Text(error.message).foregroundStyle(MosaicColor.secondaryText)
            Button("Try again", action: retry).buttonStyle(.borderedProminent)
        }
        .padding(MosaicSpace.large)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        .padding(.horizontal, MosaicSpace.large)
    }
}

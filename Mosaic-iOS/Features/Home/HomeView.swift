import SwiftUI

struct HomeView: View {
    @State private var model: HomeViewModel
    @State private var discovery = DiscoverViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL))

    init(session: SessionStore) {
        _model = State(initialValue: HomeViewModel(
            client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL),
            accessToken: { try await session.currentAccessToken() }
        ))
    }

    var body: some View {
        NavigationStack {
            MosaicScreen {
                HomeHeader()
                if case let .loaded(response) = discovery.state, let featured = response.items.first ?? response.sections.flatMap(\.items).first { HomeFeaturedStory(media: featured) }
                content
                if case let .loaded(response) = discovery.state, !response.items.isEmpty { HomeDiscoveryRail(items: Array(response.items.prefix(12))) }
            }
            .background(MosaicColor.background)
            .navigationBarHidden(true)
            .task { model.load(); discovery.load() }
            .refreshable { model.retry(); discovery.retry() }
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
        .padding(.horizontal, MosaicSpace.large)
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
                MosaicArtwork(url: media.backdropURL ?? media.posterURL, symbol: media.mediaType.symbolName)
                LinearGradient(colors: [.clear, MosaicColor.background.opacity(0.98)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicEyebrow(title: "Discovery pick")
                    Text(media.title).font(MosaicType.hero).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                    HStack(spacing: MosaicSpace.small) { if let year = media.releaseYear { Text(String(year)) }; if let genre = media.genres.first { Text(genre) }; if let rating = media.communityRating { MosaicRating(value: rating) } }.font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                    Label("View story", systemImage: "play.fill").font(.subheadline.weight(.bold)).foregroundStyle(MosaicColor.background).padding(.horizontal, 14).padding(.vertical, 10).background(MosaicColor.primaryText, in: Capsule())
                }.padding(MosaicSpace.large)
            }
            .frame(maxWidth: .infinity)
            .frame(height: MosaicLayout.backdropHeight)
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

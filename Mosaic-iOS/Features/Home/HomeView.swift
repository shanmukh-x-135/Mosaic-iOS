import SwiftUI

struct HomeView: View {
    @State private var model: HomeViewModel

    init(session: SessionStore) {
        _model = State(initialValue: HomeViewModel(
            client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL),
            accessToken: { try await session.currentAccessToken() }
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MosaicSpace.large) {
                    HomeHeader()
                    content
                }
                .padding(.vertical, MosaicSpace.medium)
            }
            .background(MosaicColor.background)
            .navigationBarHidden(true)
            .task { model.load() }
            .refreshable { model.retry() }
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
                Text(greeting).font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                Text("Your stories").font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText)
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
            Text("Continue Your Stories").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText).padding(.horizontal, MosaicSpace.large)
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
        }
    }
}

private struct ContinueSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            Text("Continue Your Stories").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText).padding(.horizontal, MosaicSpace.large)
            RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous)
                .fill(MosaicColor.surface)
                .frame(width: 282, height: 228)
                .overlay(alignment: .bottomLeading) { VStack(alignment: .leading, spacing: 10) { Capsule().fill(Color.white.opacity(0.16)).frame(width: 70, height: 10); Capsule().fill(Color.white.opacity(0.18)).frame(width: 180, height: 22); Capsule().fill(Color.white.opacity(0.14)).frame(width: 130, height: 12) }.padding(MosaicSpace.medium) }
                .padding(.horizontal, MosaicSpace.large)
                .redacted(reason: .placeholder)
                .accessibilityLabel("Loading your stories")
        }
        .opacity(reduceMotion ? 1 : 0.88)
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

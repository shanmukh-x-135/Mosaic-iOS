import SwiftUI

enum MosaicTab: Hashable { case home, discover, log, library, profile }

struct MosaicTabRouter: Equatable {
    private(set) var activeTab: MosaicTab = .home

    mutating func activate(_ tab: MosaicTab) -> Bool {
        guard tab != .log else { return true }
        activeTab = tab
        return false
    }
}

struct AppShell: View {
    @Bindable var session: SessionStore
    @State private var selectedTab: MosaicTab = .home
    @State private var router = MosaicTabRouter()
    @State private var isLogPresented = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(session: session)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(MosaicTab.home)
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .tag(MosaicTab.discover)
            Color.clear
                .accessibilityHidden(true)
                .tabItem { Label("Log", systemImage: "plus") }
                .tag(MosaicTab.log)
            LibraryView(session: session)
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(MosaicTab.library)
            ProfileView(session: session)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(MosaicTab.profile)
        }
        .onChange(of: selectedTab) { _, newTab in
            if router.activate(newTab) {
                isLogPresented = true
                selectedTab = router.activeTab
            }
        }
        .sheet(isPresented: $isLogPresented) { LogEntryView() }
    }
}

private struct LogEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = SearchViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL))
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: MosaicSpace.large) {
                    VStack(alignment: .leading, spacing: 5) {
                        MosaicEyebrow(title: "Add to your story")
                        Text("Log something").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                        Text("Search movies, series, games, and books.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, MosaicLayout.screenMargin)
                    TextField("Search the catalog", text: $model.query)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, MosaicLayout.screenMargin)
                        .accessibilityLabel("Search movies, series, games, and books")
                    ScrollView(.horizontal) {
                        HStack(spacing: MosaicSpace.small) {
                            ForEach([CatalogFilter.movies, .series, .games, .books]) { filter in
                                Button { model.filter = filter } label: { MosaicFilterChip(title: filter.title, selected: model.filter == filter) }
                            }
                        }.padding(.horizontal, MosaicLayout.screenMargin)
                    }.scrollIndicators(.hidden)
                    LogSearchContent(model: model)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, MosaicSpace.large)
            }
            .background(MosaicColor.background)
            .navigationTitle("")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done", action: dismiss.callAsFunction) } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct LogSearchContent: View {
    let model: SearchViewModel
    var body: some View {
        switch model.state {
        case .noQuery, .minimumQuery:
            ContentUnavailableView("Start with a title", systemImage: "magnifyingglass", description: Text("Choose a media type or search across Mosaic.")).frame(maxWidth: .infinity, minHeight: 160)
        case .loading:
            ProgressView("Searching catalog").frame(maxWidth: .infinity, minHeight: 160)
        case let .results(items, _):
            LazyVStack(spacing: MosaicSpace.small) {
                ForEach(items) { item in
                    NavigationLink { MediaDetailContainer(route: item.route, preview: MediaDetailPreview(media: item)) } label: {
                        HStack(spacing: MosaicSpace.medium) {
                            MosaicArtwork(url: item.posterURL, fallbackURL: item.backdropURL, symbol: item.mediaType.symbolName).frame(width: 48, height: 66).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) { Text(item.title).font(.headline).foregroundStyle(MosaicColor.primaryText).lineLimit(1); Text(item.resultMetadata).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1) }
                            Spacer(minLength: 0)
                        }.padding(.horizontal, MosaicLayout.screenMargin)
                    }.buttonStyle(.plain)
                }
            }
        case .empty:
            ContentUnavailableView("No matches", systemImage: "sparkle.magnifyingglass", description: Text("Try another title."))
        case let .error(error):
            VStack(spacing: MosaicSpace.medium) { ContentUnavailableView(error.title, systemImage: "exclamationmark.triangle", description: Text(error.message)); Button("Retry", action: model.retry).buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity)
        }
    }
}

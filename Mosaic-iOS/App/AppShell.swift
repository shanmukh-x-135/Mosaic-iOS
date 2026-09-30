import SwiftUI

private enum MosaicTab: Hashable { case home, discover, library, profile }

struct AppShell: View {
    @Bindable var session: SessionStore
    @State private var selectedTab: MosaicTab = .home
    @State private var isLogPresented = false

    var body: some View {
        destination
        .safeAreaInset(edge: .bottom, spacing: 0) { MosaicTabBar(selectedTab: $selectedTab) { isLogPresented = true } }
        .sheet(isPresented: $isLogPresented) { LogEntryView() }
    }

    @ViewBuilder private var destination: some View {
        switch selectedTab {
        case .home: HomeView(session: session)
        case .discover: DiscoverView()
        case .library: LibraryView(session: session)
        case .profile: ProfileView(session: session)
        }
    }
}

private struct MosaicTabBar: View {
    @Binding var selectedTab: MosaicTab
    let logAction: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            tab(.home, title: "Home", symbol: "house.fill")
            tab(.discover, title: "Discover", symbol: "sparkles")
            Button(action: logAction) {
                VStack(spacing: 3) {
                    Image(systemName: "plus").font(.headline.weight(.bold)).frame(width: 32, height: 32).foregroundStyle(MosaicColor.background).background(MosaicColor.accent, in: Circle()).glassEffect(.regular, in: Circle())
                    Text("Log").font(.caption2.weight(.bold)).foregroundStyle(MosaicColor.primaryText)
                }.frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.plain).accessibilityLabel("Log")
            tab(.library, title: "Library", symbol: "books.vertical.fill")
            tab(.profile, title: "Profile", symbol: "person.crop.circle")
        }
        .padding(.horizontal, 4).padding(.vertical, 7)
        .glassEffect(.regular, in: Capsule(style: .continuous))
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6)
        .background(MosaicColor.background.opacity(0.001))
    }
    private func tab(_ tab: MosaicTab, title: String, symbol: String) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text(title).font(.caption2.weight(.medium))
            }
            .foregroundStyle(selectedTab == tab ? MosaicColor.accent : MosaicColor.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
        }.buttonStyle(.plain).accessibilityLabel(title)
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

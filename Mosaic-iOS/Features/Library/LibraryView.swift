import SwiftUI

struct LibraryView: View {
    @State private var model: LibraryViewModel
    init(session: SessionStore) { _model = State(initialValue: LibraryViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL), accessToken: { try await session.currentAccessToken() })) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    MosaicEyebrow(title: "Your archive")
                    Text("Library").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                    Text("Your stories, in the order that matters to you.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, MosaicSpace.large).padding(.top, MosaicSpace.medium)
                filterBar
                content
            }
            .background(MosaicColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { GlobalSearchLink() }; ToolbarItem(placement: .topBarTrailing) { Menu { Picker("Sort", selection: $model.sort) { ForEach(LibrarySort.allCases) { Text($0.title).tag($0) } } } label: { Label("Sort", systemImage: "arrow.up.arrow.down") } } }
            .task { model.load() }
        }
    }
    private var filterBar: some View { ScrollView(.horizontal) { HStack(spacing: MosaicSpace.small) { ForEach(LibraryMediaFilter.allCases) { filter in Button { model.mediaFilter = filter } label: { MosaicFilterChip(title: filter.title, selected: model.mediaFilter == filter) }.accessibilityAddTraits(model.mediaFilter == filter ? .isSelected : []) } }.padding(.horizontal, MosaicSpace.large).padding(.vertical, MosaicSpace.medium) }.scrollIndicators(.hidden) }
    @ViewBuilder private var content: some View { switch model.state { case .idle, .loading: LibrarySkeleton(); case .empty: LibraryEmpty(title: "Your Library is waiting", detail: "Track a movie, series, game, or book and it will appear here."); case .loaded: if model.visibleItems.isEmpty { LibraryEmpty(title: "Nothing here yet", detail: "Try another media type.") } else { ScrollView { VStack(alignment: .leading, spacing: MosaicSpace.xLarge) { LibraryPulse(items: model.items); LibraryInProgress(items: model.items); VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicSectionHeader("Your stories, your order", eyebrow: "Collection"); LibraryGrid(items: model.visibleItems) } }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, MosaicSpace.medium).safeAreaPadding(.bottom, MosaicLayout.bottomClearance) }.refreshable { model.refresh() } }; case let .error(error): VStack(spacing: MosaicSpace.medium) { ContentUnavailableView(error.title, systemImage: "exclamationmark.triangle", description: Text(error.message)); Button("Try again", action: model.refresh).buttonStyle(.borderedProminent) } } }
}

private struct LibraryGrid: View { let items: [LibraryItemDTO]; private let columns = [GridItem(.flexible(), spacing: MosaicSpace.medium), GridItem(.flexible())]; var body: some View { LazyVGrid(columns: columns, spacing: MosaicSpace.large) { ForEach(items) { item in NavigationLink { MediaDetailContainer(route: item.route, preview: MediaDetailPreview(library: item)) } label: { LibraryTile(item: item) }.buttonStyle(.plain) } }.padding(.horizontal, MosaicSpace.large) } }
private struct LibraryPulse: View {
    let items: [LibraryItemDTO]
    private var counts: [(String, String)] {
        [("Movies", "movie"), ("Series", "tv"), ("Games", "game"), ("Books", "book")].map { type in
            (type.0, String(items.filter { $0.mediaType.rawValue == type.1 }.count))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Library Pulse", eyebrow: "Your collection")
            ScrollView(.horizontal) {
                HStack(spacing: MosaicSpace.small) {
                    ForEach(counts, id: \.0) { label, value in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(value).font(.title2.weight(.bold)).foregroundStyle(MosaicColor.primaryText)
                            Text(label).font(.caption).foregroundStyle(MosaicColor.secondaryText)
                        }
                        .frame(width: 112, alignment: .leading)
                        .padding(MosaicSpace.medium)
                        .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous))
                    }
                }.padding(.horizontal, MosaicSpace.large)
            }.scrollIndicators(.hidden)
        }
    }
}
private struct LibraryInProgress: View {
    let items: [LibraryItemDTO]
    private var active: [LibraryItemDTO] { items.filter { ["watching", "reading", "playing"].contains($0.status) } }
    var body: some View {
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("In progress", eyebrow: "Keep going")
                ScrollView(.horizontal) {
                    LazyHStack(spacing: MosaicSpace.medium) {
                        ForEach(active) { item in
                            NavigationLink { MediaDetailContainer(route: item.route, preview: MediaDetailPreview(library: item)) } label: {
                                LibraryProgressCard(item: item)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, MosaicSpace.large)
                }.scrollIndicators(.hidden)
            }
        }
    }
}
private struct LibraryProgressCard: View { let item: LibraryItemDTO; var body: some View { ZStack(alignment: .bottomLeading) { MosaicArtwork(url: item.backdropURL, fallbackURL: item.posterURL, symbol: item.mediaType.symbolName); LinearGradient(colors: [.clear, MosaicColor.background.opacity(0.96)], startPoint: .top, endPoint: .bottom); VStack(alignment: .leading, spacing: 4) { Text(item.statusLabel).font(.caption.weight(.bold)).foregroundStyle(MosaicColor.secondaryText); Text(item.title).font(.title3.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2); if let progress = item.progress?.displayText { Text(progress).font(.caption).foregroundStyle(MosaicColor.secondaryText) } }.padding(MosaicSpace.medium) }.frame(width: 250, height: 150).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous)) } }
private struct LibraryTile: View { let item: LibraryItemDTO; var body: some View { VStack(alignment: .leading, spacing: 7) { LibraryArtwork(item: item).aspectRatio(0.68, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous)); Text(item.title).font(.system(.headline, design: .serif)).foregroundStyle(MosaicColor.primaryText).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading); Text(item.statusLabel).font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText).lineLimit(1); if let progress = item.progress?.displayText { Text(progress).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1) } else if let rating = item.ratingText { Text(rating).font(.caption.weight(.medium)).foregroundStyle(MosaicColor.accent) } }.accessibilityElement(children: .combine).accessibilityLabel([item.title, item.mediaType.displayName, item.statusLabel, item.progress?.displayText, item.ratingText].compactMap { $0 }.joined(separator: ", ")).accessibilityHint("Opens details") } }
private struct LibraryArtwork: View { let item: LibraryItemDTO; var body: some View { MosaicArtwork(url: item.posterURL, fallbackURL: item.backdropURL, symbol: item.mediaType.symbolName) } }
private struct LibrarySkeleton: View { private let columns = [GridItem(.flexible(), spacing: MosaicSpace.medium), GridItem(.flexible())]; var body: some View { ScrollView { LazyVGrid(columns: columns, spacing: MosaicSpace.large) { ForEach(0..<6, id: \.self) { _ in VStack(alignment: .leading, spacing: 7) { RoundedRectangle(cornerRadius: MosaicRadius.control).fill(MosaicColor.surface).aspectRatio(0.68, contentMode: .fit); Capsule().fill(MosaicColor.surface).frame(height: 16); Capsule().fill(MosaicColor.surface).frame(width: 80, height: 12) }.redacted(reason: .placeholder) } }.padding(MosaicSpace.large).safeAreaPadding(.bottom, MosaicLayout.bottomClearance) }.accessibilityLabel("Loading your Library") } }
private struct LibraryEmpty: View { let title: String; let detail: String; var body: some View { ContentUnavailableView(title, systemImage: "books.vertical", description: Text(detail)).foregroundStyle(MosaicColor.secondaryText) } }

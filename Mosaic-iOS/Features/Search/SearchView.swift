import SwiftUI

struct GlobalSearchLink: View {
    var body: some View {
        NavigationLink { SearchView() } label: {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel("Search Mosaic")
    }
}

struct SearchView: View {
    @State private var model: SearchViewModel

    init() { _model = State(initialValue: SearchViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL))) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    MosaicEyebrow(title: "Across every medium")
                    Text("Search").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MosaicSpace.large)
                .padding(.top, MosaicSpace.medium)
                filterBar
                content
            }
            .background(MosaicColor.background)
            .navigationTitle("Search")
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Movies, series, games, and books")
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MosaicSpace.small) {
                ForEach(CatalogFilter.allCases) { filter in
                    Button { model.filter = filter } label: {
                        MosaicFilterChip(title: filter.title, selected: model.filter == filter)
                    }
                        .accessibilityAddTraits(model.filter == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, MosaicSpace.large).padding(.vertical, MosaicSpace.small)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .noQuery:
            ContentUnavailableView("Find something to love", systemImage: "magnifyingglass", description: Text("Search Mosaic’s movies, series, games, and books."))
                .foregroundStyle(MosaicColor.secondaryText)
        case .minimumQuery:
            ContentUnavailableView("Keep typing", systemImage: "text.magnifyingglass", description: Text("Enter at least 2 characters to search."))
                .foregroundStyle(MosaicColor.secondaryText)
        case .loading:
            SearchSkeleton()
        case let .results(items, partialFailure):
            SearchResults(items: items, partialFailure: partialFailure)
        case let .empty(partialFailure):
            ContentUnavailableView("No matches", systemImage: "sparkle.magnifyingglass", description: Text(partialFailure ?? "Try another title or a different media type."))
                .foregroundStyle(MosaicColor.secondaryText)
        case let .error(error):
            VStack(spacing: MosaicSpace.medium) {
                ContentUnavailableView(error.title, systemImage: "exclamationmark.triangle", description: Text(error.message))
                Button("Try again", action: model.retry).buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct SearchResults: View {
    let items: [CatalogMedia]
    let partialFailure: String?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MosaicSpace.small) {
                if let partialFailure { Text(partialFailure).font(.footnote).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, MosaicSpace.large) }
                Text("\(items.count) results").font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, MosaicSpace.large).padding(.top, MosaicSpace.small)
                ForEach(items) { item in
                    NavigationLink { MediaDetailContainer(route: item.route, preview: MediaDetailPreview(media: item)) } label: { SearchResultRow(item: item) }
                        .buttonStyle(.plain)
                        .padding(.horizontal, MosaicSpace.large)
                    Divider().overlay(MosaicColor.border).padding(.leading, MosaicSpace.large + 74)
                }
            }
            .padding(.vertical, MosaicSpace.small)
            .safeAreaPadding(.bottom, MosaicLayout.bottomClearance)
        }.scrollIndicators(.hidden)
    }
}

private struct SearchResultRow: View {
    let item: CatalogMedia
    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            MosaicArtwork(url: item.posterURL ?? item.backdropURL, symbol: item.mediaType.symbolName).frame(width: 58, height: 82).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.headline).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                Text(item.resultMetadata).font(.subheadline).foregroundStyle(MosaicColor.secondaryText).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.resultMetadata)")
        .accessibilityHint("Opens details")
    }
}

private struct SearchSkeleton: View {
    var body: some View {
        ScrollView { VStack(spacing: MosaicSpace.medium) { ForEach(0..<6, id: \.self) { _ in HStack(spacing: MosaicSpace.medium) { MosaicSkeleton(aspectRatio: 0.7).frame(width: 58, height: 82); VStack(alignment: .leading, spacing: 10) { Capsule().fill(MosaicColor.surface).frame(width: 170, height: 16); Capsule().fill(MosaicColor.surface).frame(width: 110, height: 12) }; Spacer() }.padding(.horizontal, MosaicSpace.large) } }.padding(.top, MosaicSpace.medium).safeAreaPadding(.bottom, MosaicLayout.bottomClearance) }.accessibilityLabel("Searching catalog")
    }
}

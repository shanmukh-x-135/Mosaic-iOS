import SwiftUI

struct SearchView: View {
    @State private var model: SearchViewModel

    init() { _model = State(initialValue: SearchViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL))) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    Button(filter.title) { model.filter = filter }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(model.filter == filter ? MosaicColor.background : MosaicColor.primaryText)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(model.filter == filter ? MosaicColor.primaryText : MosaicColor.surface, in: Capsule())
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
        List {
            if let partialFailure { Text(partialFailure).font(.footnote).foregroundStyle(MosaicColor.secondaryText).listRowBackground(Color.clear) }
            ForEach(items) { item in
                NavigationLink { MediaDetailContainer(route: item.route, preview: MediaDetailPreview(media: item)) } label: { SearchResultRow(item: item) }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(MosaicColor.surface)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct SearchResultRow: View {
    let item: CatalogMedia
    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            SearchArtwork(item: item).frame(width: 58, height: 82).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous))
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

private struct SearchArtwork: View {
    let item: CatalogMedia
    var body: some View {
        Group {
            if let url = item.posterURL ?? item.backdropURL {
                AsyncImage(url: url) { phase in
                    switch phase { case let .success(image): image.resizable().scaledToFill(); default: fallback }
                }
            } else { fallback }
        }.clipped().accessibilityHidden(true)
    }
    private var fallback: some View { LinearGradient(colors: [MosaicColor.surface, MosaicColor.background], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Image(systemName: item.mediaType.symbolName).foregroundStyle(MosaicColor.secondaryText)) }
}

private struct SearchSkeleton: View {
    var body: some View {
        List(0..<6, id: \.self) { _ in
            HStack(spacing: MosaicSpace.medium) {
                RoundedRectangle(cornerRadius: MosaicRadius.control).fill(MosaicColor.surface).frame(width: 58, height: 82)
                VStack(alignment: .leading, spacing: 10) { Capsule().fill(MosaicColor.surface).frame(width: 170, height: 16); Capsule().fill(MosaicColor.surface).frame(width: 110, height: 12) }
            }.redacted(reason: .placeholder).listRowBackground(Color.clear)
        }.listStyle(.plain).scrollContentBackground(.hidden).accessibilityLabel("Searching catalog")
    }
}

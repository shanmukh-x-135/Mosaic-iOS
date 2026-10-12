import SwiftUI

/// The one catalog search surface, hosted by the system search tab. Results
/// keep the server's provider order and its partial-failure notice.
struct SearchView: View {
    @Environment(\.mosaicServices) private var services
    var body: some View { SearchScreen(services: services) }
}

private struct SearchScreen: View {
    @State private var model: SearchViewModel
    @SceneStorage("mosaic.search.query") private var storedQuery = ""
    @SceneStorage("mosaic.search.filter") private var storedFilter = CatalogFilter.all.rawValue

    init(services: MosaicServices) { _model = State(initialValue: SearchViewModel(search: services.search)) }

    var body: some View {
        List {
            Section {
                MosaicChipRow(items: CatalogFilter.allCases, selection: $model.filter, title: \.title, tint: { $0.mediaType?.accent })
                    .listRowInsets(EdgeInsets(top: MosaicSpace.xSmall, leading: 0, bottom: MosaicSpace.xSmall, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("Media type")
            }
            content
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(MosaicColor.background)
        .navigationTitle("Search")
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Movies, series, games, and books")
        .toolbar { QuickLogToolbarItem() }
        .onAppear {
            if model.query.isEmpty, !storedQuery.isEmpty { model.query = storedQuery }
            if let filter = CatalogFilter(rawValue: storedFilter), filter != model.filter { model.filter = filter }
        }
        .onChange(of: model.query) { _, query in storedQuery = query }
        .onChange(of: model.filter) { _, filter in storedFilter = filter.rawValue }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .noQuery:
            message(MosaicStateMessage(title: "Find something to love", message: "Search Mosaic’s movies, series, games, and books.", systemImage: "magnifyingglass"))
        case .minimumQuery:
            message(MosaicStateMessage(title: "Keep typing", message: "Enter at least 2 characters to search.", systemImage: "text.magnifyingglass"))
        case .loading:
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: MosaicSpace.medium) {
                    MosaicSkeleton(aspectRatio: MosaicArtworkRatio.poster).frame(width: 52)
                    VStack(alignment: .leading, spacing: 8) { Capsule().fill(MosaicColor.surface).frame(width: 170, height: 14); Capsule().fill(MosaicColor.surface).frame(width: 110, height: 10) }
                }
                .listRowBackground(Color.clear)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Searching catalog")
        case let .results(items, partialFailure):
            Section {
                ForEach(items) { media in
                    NavigationLink(value: MosaicRoute.media(media)) {
                        MosaicMediaRow(summary: MosaicMediaSummary(media), lines: lines(for: media), showsMedium: model.filter == .all)
                    }
                    .listRowBackground(Color.clear)
                    .saveForLaterContextMenu(media)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    if let partialFailure { MosaicNotice(text: partialFailure) }
                    Text("\(items.count) \(items.count == 1 ? "result" : "results")").font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText)
                }
            }
        case let .empty(partialFailure):
            message(MosaicStateMessage(title: "No matches", message: partialFailure ?? "Try another title or a different media type.", systemImage: "sparkle.magnifyingglass"))
        case let .error(error):
            message(MosaicStateMessage(title: error.title, message: error.message, systemImage: "exclamationmark.triangle", actionTitle: "Try again", action: model.retry))
        }
    }

    private func lines(for media: CatalogMedia) -> [String] {
        var lines = [media.resultMetadata].filter { !$0.isEmpty }
        if let rating = media.community { lines.append("★ \(rating.formattedValue) \(rating.source.shortLabel)") }
        return lines
    }

    private func message(_ view: MosaicStateMessage) -> some View {
        view.padding(.top, MosaicSpace.xLarge).listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets())
    }
}

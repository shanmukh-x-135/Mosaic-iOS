import SwiftUI

/// Quick Log: choose a medium, find the title, then fill that medium's form.
struct QuickLogView: View {
    @Environment(\.mosaicServices) private var services
    var body: some View { QuickLogFlow(services: services) }
}

private struct QuickLogFlow: View {
    @State private var model: SearchViewModel
    @Environment(\.dismiss) private var dismiss

    init(services: MosaicServices) {
        let model = SearchViewModel(search: services.search)
        model.filter = .movies
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MosaicChipRow(items: [CatalogFilter.movies, .series, .games, .books], selection: $model.filter, title: \.title, tint: { $0.mediaType?.accent })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .accessibilityLabel("What are you logging?")
                }
                results
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MosaicColor.background)
            .navigationTitle("Log something")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(model.filter.title.lowercased())")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .navigationDestination(for: CatalogMedia.self) { media in QuickLogTarget(preview: media) }
        }
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var results: some View {
        switch model.state {
        case .noQuery, .minimumQuery:
            row { MosaicStateMessage(title: "Start with a title", message: "Search \(model.filter.title.lowercased()) by name, then fill in what you watched, played or read.", systemImage: "magnifyingglass") }
        case .loading:
            row { HStack { Spacer(); ProgressView("Searching \(model.filter.title.lowercased())"); Spacer() }.padding(.vertical, MosaicSpace.xLarge) }
        case let .results(items, partialFailure):
            if let partialFailure { row { MosaicNotice(text: partialFailure).padding(.horizontal, MosaicLayout.pageHorizontal) } }
            ForEach(items) { media in
                NavigationLink(value: media) {
                    MosaicMediaRow(summary: MosaicMediaSummary(media), lines: [media.resultMetadata].filter { !$0.isEmpty }, showsMedium: false, thumbnailWidth: 44)
                }
                .listRowBackground(Color.clear)
            }
        case let .empty(partialFailure):
            row { MosaicStateMessage(title: "No matches", message: partialFailure ?? "Try another title.", systemImage: "sparkle.magnifyingglass") }
        case let .error(error):
            row { MosaicStateMessage(title: error.title, message: error.message, systemImage: "exclamationmark.triangle", actionTitle: "Try again", action: model.retry) }
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
}

/// Loads full catalog detail (season counts, page counts) before the form opens.
private struct QuickLogTarget: View {
    let preview: CatalogMedia
    @Environment(\.mosaicServices) private var services
    @Environment(MosaicRouter.self) private var router
    @State private var media: Loadable<CatalogMedia> = .idle

    var body: some View {
        Group {
            switch media {
            case let .loaded(media): MediaLogForm(media: media, onSaved: { router.isQuickLogPresented = false })
            case let .failed(error):
                MosaicStateMessage(title: DetailErrorPresentation.from(error).title, message: DetailErrorPresentation.from(error).message, systemImage: "exclamationmark.triangle", actionTitle: "Try again") { Task { await load() } }
            case .idle, .loading:
                ProgressView("Loading \(preview.title)").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MosaicColor.background)
        .task { if case .idle = media { await load() } }
    }

    private func load() async {
        media = .loading
        do { media = .loaded(try await services.detail(preview.route)) } catch { media = .failed(error) }
    }
}

extension CatalogFilter {
    var mediaType: CatalogMediaType? { catalogType.flatMap(CatalogMediaType.init(rawValue:)) }
}

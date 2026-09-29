import SwiftUI
import Observation

struct MediaDetailContainer: View {
    let route: MediaDetailRoute
    let preview: MediaDetailPreview
    @State private var model: MediaDetailViewModel

    init(route: MediaDetailRoute, preview: MediaDetailPreview) {
        self.route = route
        self.preview = preview
        _model = State(initialValue: MediaDetailViewModel(route: route, client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL)))
    }

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading: MediaDetailSkeleton(preview: preview)
            case let .loaded(media): typedDetail(media)
            case let .error(error): DetailErrorView(error: error, retry: model.retry)
            }
        }
        .background(MosaicColor.background)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(preview.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { model.load() }
    }

    @ViewBuilder private func typedDetail(_ media: CatalogMedia) -> some View {
        switch media.mediaType {
        case .movie: MovieDetailView(media: media)
        case .tv: SeriesDetailView(media: media)
        case .game: GameDetailView(media: media)
        case .book: BookDetailView(media: media)
        }
    }
}

struct MediaDetailPreview: Equatable, Sendable {
    let title: String
    let artworkURL: URL?
    let fallbackArtworkURL: URL?
    let mediaType: CatalogMediaType

    init(story: ContinueStory) {
        title = story.title
        artworkURL = story.artworkURL
        fallbackArtworkURL = story.fallbackArtworkURL
        mediaType = story.detailRoute.mediaType
    }

    init(media: CatalogMedia) {
        title = media.title
        artworkURL = media.backdropURL
        fallbackArtworkURL = media.posterURL
        mediaType = media.mediaType
    }

    init(library: LibraryItemDTO) {
        title = library.title
        artworkURL = library.backdropURL
        fallbackArtworkURL = library.posterURL
        mediaType = library.mediaType
    }
}

enum MediaDetailState: Equatable { case idle, loading, loaded(CatalogMedia), error(DetailErrorPresentation) }

enum DetailErrorPresentation: Equatable {
    case offline, unavailable, notFound, unreadable
    var title: String { switch self { case .offline: "Mosaic can’t reach the internet"; case .unavailable: "Details are unavailable right now"; case .notFound: "This title is no longer available"; case .unreadable: "Mosaic couldn’t read these details" } }
    var message: String { switch self { case .offline: "Check your connection and try again."; case .unavailable: "Try again in a moment."; case .notFound: "Return to search and choose another result."; case .unreadable: "Try again. If this continues, update Mosaic." } }
    static func from(_ error: Error) -> DetailErrorPresentation {
        switch error {
        case let error as MosaicAPIError:
            switch error { case .network: .offline; case .notFound: .notFound; case .providerUnavailable, .internalError: .unavailable; default: .unreadable }
        default: .unavailable
        }
    }
}

actor CatalogDetailCache {
    static let shared = CatalogDetailCache()
    private var values: [MediaDetailRoute: CatalogMedia] = [:]
    func value(for route: MediaDetailRoute) -> CatalogMedia? { values[route] }
    func store(_ media: CatalogMedia, for route: MediaDetailRoute) { values[route] = media }
}

@MainActor @Observable
final class MediaDetailViewModel {
    private let route: MediaDetailRoute
    private let request: @Sendable (MediaDetailRoute) async throws -> CatalogMedia
    private var loadTask: Task<Void, Never>?
    private(set) var state: MediaDetailState = .idle

    init(route: MediaDetailRoute, client: MosaicAPIClient) {
        self.route = route
        request = { route in try await client.publicRequest(path: route.catalogPath, as: CatalogMedia.self) }
    }
    init(route: MediaDetailRoute, request: @escaping @Sendable (MediaDetailRoute) async throws -> CatalogMedia) { self.route = route; self.request = request }

    func load() {
        guard loadTask == nil else { return }
        state = .loading
        loadTask = Task { [weak self, route, request] in
            defer { Task { @MainActor [weak self] in self?.loadTask = nil } }
            if let cached = await CatalogDetailCache.shared.value(for: route) {
                guard !Task.isCancelled else { return }
                self?.state = .loaded(cached)
                return
            }
            do {
                let media = try await request(route)
                try Task.checkCancellation()
                await CatalogDetailCache.shared.store(media, for: route)
                self?.state = .loaded(media)
            } catch is CancellationError {
                self?.state = .idle
            } catch {
                self?.state = .error(DetailErrorPresentation.from(error))
            }
        }
    }
    func retry() { load() }
}

private struct MovieDetailView: View {
    let media: CatalogMedia
    var body: some View { MediaDetailContent(media: media, metadata: [MetadataLine("Runtime", media.runtimeMinutes.map(runtimeText)), MetadataLine("Director", media.director), MetadataLine("Studio", media.studio)]) }
    private func runtimeText(_ minutes: Int) -> String { let hours = minutes / 60; let remainder = minutes % 60; return hours > 0 ? "\(hours)h \(remainder)m" : "\(minutes)m" }
}
private struct SeriesDetailView: View { let media: CatalogMedia; var body: some View { MediaDetailContent(media: media, metadata: [MetadataLine("Seasons", media.seasonCount.map(String.init)), MetadataLine("Episodes", media.episodeCount.map(String.init)), MetadataLine("Network", media.network)]) } }
private struct GameDetailView: View { let media: CatalogMedia; var body: some View { MediaDetailContent(media: media, metadata: [MetadataLine("Platforms", media.platforms?.joined(separator: ", ")), MetadataLine("Developer", media.developer), MetadataLine("Publisher", media.publisher)]) } }
private struct BookDetailView: View { let media: CatalogMedia; var body: some View { MediaDetailContent(media: media, metadata: [MetadataLine("Author", media.authors?.joined(separator: ", ")), MetadataLine("Pages", media.pageCount.map(String.init)), MetadataLine("Publisher", media.publisher)]) } }

private struct MetadataLine: Identifiable { let label: String; let value: String?; var id: String { label }; init(_ label: String, _ value: String?) { self.label = label; self.value = value } }

private struct MediaDetailContent: View {
    let media: CatalogMedia
    let metadata: [MetadataLine]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MosaicSpace.large) {
                DetailArtwork(media: media).frame(height: 255).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    Label(media.mediaType.displayName, systemImage: media.mediaType.symbolName).font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText)
                    Text(media.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText).fixedSize(horizontal: false, vertical: true)
                    if let subtitle = media.subtitle ?? media.releaseContext { Text(subtitle).font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }
                    if let rating = media.communityRating { Text("Public rating \(rating.formatted(.number.precision(.fractionLength(1))))").font(.subheadline.weight(.medium)).foregroundStyle(MosaicColor.accent) }
                }
                if !media.genres.isEmpty { GenreChips(genres: media.genres) }
                if let description = media.description, !description.isEmpty { VStack(alignment: .leading, spacing: MosaicSpace.small) { Text("About").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text(description).foregroundStyle(MosaicColor.secondaryText).fixedSize(horizontal: false, vertical: true) } }
                let available = metadata.filter { $0.value?.isEmpty == false }
                if !available.isEmpty { VStack(alignment: .leading, spacing: MosaicSpace.small) { Text("Details").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); ForEach(available) { item in HStack(alignment: .firstTextBaseline) { Text(item.label).foregroundStyle(MosaicColor.secondaryText); Spacer(); Text(item.value ?? "").multilineTextAlignment(.trailing).foregroundStyle(MosaicColor.primaryText) } } } }
            }
            .padding(.horizontal, MosaicSpace.large)
            .padding(.vertical, MosaicSpace.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DetailArtwork: View {
    let media: CatalogMedia
    var body: some View { Group { if let url = media.artworkURL { AsyncImage(url: url) { phase in switch phase { case let .success(image): image.resizable().scaledToFill(); default: fallback } } } else { fallback } }.frame(maxWidth: .infinity).clipped().accessibilityHidden(true) }
    private var fallback: some View { LinearGradient(colors: [MosaicColor.surface, MosaicColor.background], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Image(systemName: media.mediaType.symbolName).font(.system(size: 50, weight: .light)).foregroundStyle(MosaicColor.secondaryText)) }
}
private struct GenreChips: View { let genres: [String]; var body: some View { ScrollView(.horizontal) { HStack(spacing: MosaicSpace.small) { ForEach(genres, id: \.self) { Text($0).font(.caption.weight(.medium)).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, 10).padding(.vertical, 6).background(MosaicColor.surface, in: Capsule()) } }.padding(.vertical, 2) }.scrollIndicators(.hidden) } }
private struct MediaDetailSkeleton: View { let preview: MediaDetailPreview; var body: some View { ScrollView { VStack(alignment: .leading, spacing: MosaicSpace.large) { RoundedRectangle(cornerRadius: MosaicRadius.card).fill(MosaicColor.surface).frame(height: 255); Text(preview.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); Capsule().fill(MosaicColor.surface).frame(width: 180, height: 14); Capsule().fill(MosaicColor.surface).frame(height: 14); Capsule().fill(MosaicColor.surface).frame(width: 260, height: 14) }.padding(MosaicSpace.large).redacted(reason: .placeholder) }.accessibilityLabel("Loading \(preview.title) details") } }
private struct DetailErrorView: View { let error: DetailErrorPresentation; let retry: () -> Void; var body: some View { VStack(spacing: MosaicSpace.medium) { ContentUnavailableView(error.title, systemImage: "exclamationmark.triangle", description: Text(error.message)); if error != .notFound { Button("Try again", action: retry).buttonStyle(.borderedProminent) } }.foregroundStyle(MosaicColor.secondaryText) } }

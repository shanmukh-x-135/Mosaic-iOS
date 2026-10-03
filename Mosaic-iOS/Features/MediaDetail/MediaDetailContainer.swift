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
            switch error { case .network, .timedOut: .offline; case .notFound: .notFound; case .providerUnavailable, .internalError: .unavailable; default: .unreadable }
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
private struct SeriesDetailView: View { let media: CatalogMedia; var body: some View { SeriesHubView(media: media) } }
private struct GameDetailView: View { let media: CatalogMedia; var body: some View { MediaDetailContent(media: media, metadata: [MetadataLine("Platforms", media.platforms?.joined(separator: ", ")), MetadataLine("Developer", media.developer), MetadataLine("Publisher", media.publisher)]) } }
private struct BookDetailView: View { let media: CatalogMedia; var body: some View { MediaDetailContent(media: media, metadata: [MetadataLine("Author", media.authors?.joined(separator: ", ")), MetadataLine("Pages", media.pageCount.map(String.init)), MetadataLine("Publisher", media.publisher)]) } }

private struct MetadataLine: Identifiable { let label: String; let value: String?; var id: String { label }; init(_ label: String, _ value: String?) { self.label = label; self.value = value } }

private struct MediaDetailContent: View {
    let media: CatalogMedia
    let metadata: [MetadataLine]
    @Environment(SessionStore.self) private var session
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MosaicSpace.large) {
                DetailArtwork(media: media).frame(height: 255).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    Label(media.mediaType.displayName, systemImage: media.mediaType.symbolName).font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText)
                    Text(media.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText).fixedSize(horizontal: false, vertical: true)
                    if let subtitle = media.subtitle ?? media.releaseContext { Text(subtitle).font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }
                    if let rating = media.communityRating { Text("Public rating \(rating.formatted(.number.precision(.fractionLength(1))))").font(.subheadline.weight(.medium)).foregroundStyle(MosaicColor.accent) }
                }
                DetailTrackingActions(media: media, session: session)
                if !media.genres.isEmpty { GenreChips(genres: media.genres) }
                if let description = media.description, !description.isEmpty { VStack(alignment: .leading, spacing: MosaicSpace.small) { Text("About").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); Text(description).foregroundStyle(MosaicColor.secondaryText).fixedSize(horizontal: false, vertical: true) } }
                let available = metadata.filter { $0.value?.isEmpty == false }
                if !available.isEmpty { VStack(alignment: .leading, spacing: MosaicSpace.small) { Text("Details").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText); ForEach(available) { item in DetailFactRow(item: item) } } }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MosaicLayout.pageHorizontal)
            .padding(.vertical, MosaicSpace.large)
        }
    }
}

private struct DetailFactRow: View {
    let item: MetadataLine
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.label).font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText)
            Text(item.value ?? "").foregroundStyle(MosaicColor.primaryText).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailTrackingActions: View {
    let media: CatalogMedia
    let session: SessionStore
    @State private var isSaving = false
    @State private var notice: String?
    @State private var sheet: DetailActionSheet?
    @State private var personal: DetailPersonalStateModel

    init(media: CatalogMedia, session: SessionStore) {
        self.media = media
        self.session = session
        _personal = State(initialValue: DetailPersonalStateModel(media: media, client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL), accessToken: { try await session.currentAccessToken() }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            Text("Your story").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText)
            HStack(spacing: MosaicSpace.small) {
                Button(primaryTitle) { sheet = .log }
                    .buttonStyle(.glassProminent)
                    .disabled(isSaving)
                Menu {
                    ForEach(libraryStatuses, id: \.self) { status in
                        Button(status.replacingOccurrences(of: "_", with: " ").capitalized) { save(.library(media, status: status, isFavorite: personal.item?.isFavorite)) }
                    }
                    if personal.item != nil {
                        Divider()
                        Button("Remove from Library", role: .destructive) { save(.removeLibrary(media)) }
                    }
                } label: { Label("Library", systemImage: "books.vertical") }
                    .buttonStyle(.glass)
                    .disabled(isSaving)
            }
            HStack(spacing: MosaicSpace.small) {
                Menu {
                    Button("Clear rating") { save(.rating(media, nil)) }
                    Divider()
                    ForEach([1.0, 2.0, 3.0, 4.0, 5.0], id: \.self) { rating in
                        Button("\(Int(rating)) stars") { save(.rating(media, rating)) }
                    }
                } label: {
                    Label("Rate", systemImage: "star")
                }
                .buttonStyle(.glass)
                .disabled(isSaving)
                Button { save(.library(media, status: personal.item?.status ?? defaultLibraryStatus, isFavorite: !(personal.item?.isFavorite ?? false))) } label: {
                    Image(systemName: personal.item?.isFavorite == true ? "heart.fill" : "heart")
                }
                .buttonStyle(.glass)
                .accessibilityLabel(personal.item?.isFavorite == true ? "Remove favourite" : "Add favourite")
                .disabled(isSaving)
            }
            DetailPersonalStateView(state: personal.state)
            if let notice { Text(notice).font(.footnote).foregroundStyle(MosaicColor.secondaryText) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .task { personal.load() }
        .sheet(item: $sheet) { action in
            DetailLogSheet(action: action, media: media, onSave: save)
        }
    }

    private var primaryTitle: String {
        switch media.mediaType {
        case .movie: "Log watched"
        case .tv: "Log next episode"
        case .game, .book: "Update progress"
        }
    }

    private var defaultLibraryStatus: String {
        switch media.mediaType {
        case .movie: "watchlist"
        case .tv: "watching"
        case .game: "backlog"
        case .book: "want_to_read"
        }
    }

    private var libraryStatuses: [String] {
        switch media.mediaType {
        case .movie: ["watchlist", "watched"]
        case .tv: ["watchlist", "watching", "paused", "completed", "dropped"]
        case .game: ["backlog", "playing", "paused", "completed", "dropped"]
        case .book: ["want_to_read", "reading", "paused", "finished", "dnf"]
        }
    }

    private func save(_ mutation: DetailMutation) {
        guard !isSaving else { return }
        isSaving = true; notice = nil
        Task {
            do {
                let token = try await session.currentAccessToken()
                try await MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL).mutate(path: "/api/me/state", body: mutation, token: token)
                await MainActor.run { notice = "Saved to your Mosaic."; isSaving = false; personal.refresh() }
            } catch {
                await MainActor.run { notice = "Mosaic couldn’t save that change. Try again."; isSaving = false }
            }
        }
    }
}

private enum DetailActionSheet: String, Identifiable { case log; var id: String { rawValue } }

@MainActor @Observable
private final class DetailPersonalStateModel {
    enum State { case idle, loading, empty, loaded(LibraryItemDTO), failed }
    let media: CatalogMedia
    private let request: @MainActor () async throws -> [LibraryItemDTO]
    private var task: Task<Void, Never>?
    private(set) var state: State = .idle

    init(media: CatalogMedia, client: MosaicAPIClient, accessToken: @escaping @MainActor () async throws -> String) {
        self.media = media
        request = { let token = try await accessToken(); return try await client.request("/api/me/library", token: token, as: LibraryResponseDTO.self).items }
    }
    var item: LibraryItemDTO? { if case let .loaded(item) = state { item } else { nil } }
    func load() {
        guard task == nil else { return }
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }; defer { self.task = nil }
            do { self.state = (try await self.request()).first(where: { $0.provider == self.media.provider && $0.providerID == self.media.providerID && $0.mediaType == self.media.mediaType }).map(State.loaded) ?? .empty }
            catch is CancellationError { self.state = .idle }
            catch { self.state = .failed }
        }
    }
    func refresh() { task?.cancel(); task = nil; state = .idle; load() }
}

private struct DetailPersonalStateView: View {
    let state: DetailPersonalStateModel.State
    var body: some View {
        switch state {
        case let .loaded(item):
            VStack(alignment: .leading, spacing: 4) {
                Text([item.statusLabel, item.isFavorite ? "Favourite" : nil, item.ratingText, item.progress?.displayText].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote.weight(.medium)).foregroundStyle(MosaicColor.secondaryText)
                Text("In your Library").font(.caption).foregroundStyle(MosaicColor.mutedText)
            }
        case .loading: ProgressView().controlSize(.small)
        case .empty, .idle, .failed: Text("Not in your Library yet").font(.footnote).foregroundStyle(MosaicColor.mutedText)
        }
    }
}

private struct DetailLogSheet: View {
    let action: DetailActionSheet
    let media: CatalogMedia
    let onSave: (DetailMutation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var isRewatch = false
    @State private var rating: Double = 0
    @State private var review = ""
    @State private var status = ""
    @State private var currentPage = ""
    @State private var totalPages = ""
    @State private var percent = ""
    @State private var playtimeMinutes = ""
    @State private var platform = ""
    @State private var season = 1
    @State private var episode = 1

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(media.title).font(.headline) }
                switch media.mediaType {
                case .movie: movieFields
                case .tv: seriesFields
                case .book: bookFields
                case .game: gameFields
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(mutation); dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var title: String { switch media.mediaType { case .movie: "Log watched"; case .tv: "Log episode"; case .book, .game: "Update progress" } }
    private var movieFields: some View { Group { Section("When") { DatePicker("Watched", selection: $date, displayedComponents: .date); Toggle("Rewatch", isOn: $isRewatch) }; ratingFields; Section("Note") { TextField("Optional review", text: $review, axis: .vertical).lineLimit(3...6) } } }
    private var seriesFields: some View { Group { Section("Episode") { Picker("Season", selection: $season) { ForEach(seasons, id: \.self) { Text("Season \($0)").tag($0) } }; Picker("Episode", selection: $episode) { ForEach(1...max(episodeCount, 1), id: \.self) { Text("Episode \($0)").tag($0) } }; DatePicker("Watched", selection: $date, displayedComponents: .date) }; ratingFields } }
    private var bookFields: some View { Group { Section("Reading") { Picker("Status", selection: $status) { ForEach(["want_to_read", "reading", "paused", "finished", "dnf"], id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }; TextField("Pages read", text: $currentPage).keyboardType(.numberPad); TextField("Total pages", text: $totalPages).keyboardType(.numberPad); TextField("Progress percent", text: $percent).keyboardType(.decimalPad) }; ratingFields } }
    private var gameFields: some View { Group { Section("Playthrough") { Picker("Status", selection: $status) { ForEach(["backlog", "playing", "paused", "completed", "dropped"], id: \.self) { Text($0.capitalized).tag($0) } }; TextField("Platform (optional)", text: $platform); TextField("Playtime minutes", text: $playtimeMinutes).keyboardType(.numberPad); TextField("Progress percent", text: $percent).keyboardType(.decimalPad) }; ratingFields } }
    private var ratingFields: some View { Section("Your rating") { Picker("Rating", selection: $rating) { Text("No rating").tag(0.0); ForEach([1.0, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5], id: \.self) { Text("\($0.formatted(.number.precision(.fractionLength(0...1)))) stars").tag($0) } } } }
    private var seasons: [Int] { let values = media.seasonNumbers?.filter { $0 > 0 } ?? []; return values.isEmpty ? [1] : values }
    private var episodeCount: Int { media.seasonEpisodeCounts?[String(season)] ?? media.episodeCount ?? 1 }
    private var mutation: DetailMutation {
        let selectedRating = rating == 0 ? nil : rating
        switch media.mediaType {
        case .movie: return .movieLog(media, watchedAt: date, isRewatch: isRewatch, rating: selectedRating, review: review.nilIfBlank)
        case .tv: return .episodeLog(media, season: season, episode: episode, watchedAt: date, rating: selectedRating)
        case .book: return .book(media, status: status.isEmpty ? "reading" : status, currentPage: Int(currentPage), totalPages: Int(totalPages), percent: Double(percent), rating: selectedRating)
        case .game: return .game(media, status: status.isEmpty ? "playing" : status, platform: platform.nilIfBlank, playtimeMinutes: Int(playtimeMinutes) ?? 0, percent: Double(percent), rating: selectedRating)
        }
    }
}

private extension String { var nilIfBlank: String? { let value = trimmingCharacters(in: .whitespacesAndNewlines); return value.isEmpty ? nil : value } }

struct DetailMutation: Encodable {
    let type: String
    let media: CatalogMedia
    let series: CatalogMedia?
    let status: String?
    let state: String?
    let provenance: String?
    let isFavorite: Bool?
    let value: Double?
    let rating: Double?
    let watchedAt: String?
    let isRewatch: Bool?
    let review: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let platform: String?
    let playtimeMinutes: Int?
    let progressPercent: Double?
    let currentPage: Int?
    let totalPages: Int?

    static func rating(_ media: CatalogMedia, _ value: Double?) -> Self { .base(type: "rating.set", media: media, value: value) }
    static func library(_ media: CatalogMedia, status: String, isFavorite: Bool?) -> Self { .base(type: "library.upsert", media: media, status: status, isFavorite: isFavorite) }
    static func removeLibrary(_ media: CatalogMedia) -> Self { .base(type: "library.remove", media: media) }
    static func movieLog(_ media: CatalogMedia, watchedAt: Date, isRewatch: Bool, rating: Double?, review: String?) -> Self { .base(type: "movie.log", media: media, rating: rating, watchedAt: Self.day.string(from: watchedAt), isRewatch: isRewatch, review: review) }
    static func episodeLog(_ media: CatalogMedia, season: Int, episode: Int, watchedAt: Date, rating: Double?) -> Self { .base(type: "episode.log", media: media, series: media, rating: rating, watchedAt: Self.instant.string(from: watchedAt), seasonNumber: season, episodeNumber: episode) }
    static func episodeUnwatch(_ media: CatalogMedia, season: Int, episode: Int) -> Self { .base(type: "episode.unwatch", media: media, series: media, seasonNumber: season, episodeNumber: episode) }
    static func seasonState(_ media: CatalogMedia, season: Int, state: String) -> Self { .base(type: "season.state", media: media, series: media, state: state, provenance: "bulk_season", seasonNumber: season) }
    static func game(_ media: CatalogMedia, status: String, platform: String?, playtimeMinutes: Int, percent: Double?, rating: Double?) -> Self { .base(type: "game.upsert", media: media, status: status, rating: rating, platform: platform, playtimeMinutes: playtimeMinutes, progressPercent: percent) }
    static func book(_ media: CatalogMedia, status: String, currentPage: Int?, totalPages: Int?, percent: Double?, rating: Double?) -> Self { .base(type: "book.upsert", media: media, status: status, rating: rating, progressPercent: percent, currentPage: currentPage, totalPages: totalPages) }
    private static func base(type: String, media: CatalogMedia, series: CatalogMedia? = nil, status: String? = nil, state: String? = nil, provenance: String? = nil, isFavorite: Bool? = nil, value: Double? = nil, rating: Double? = nil, watchedAt: String? = nil, isRewatch: Bool? = nil, review: String? = nil, seasonNumber: Int? = nil, episodeNumber: Int? = nil, platform: String? = nil, playtimeMinutes: Int? = nil, progressPercent: Double? = nil, currentPage: Int? = nil, totalPages: Int? = nil) -> Self {
        .init(type: type, media: media, series: series, status: status, state: state, provenance: provenance, isFavorite: isFavorite, value: value, rating: rating, watchedAt: watchedAt, isRewatch: isRewatch, review: review, seasonNumber: seasonNumber, episodeNumber: episodeNumber, platform: platform, playtimeMinutes: playtimeMinutes, progressPercent: progressPercent, currentPage: currentPage, totalPages: totalPages)
    }
    private static let day: DateFormatter = { let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .iso8601); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; return formatter }()
    private static let instant = ISO8601DateFormatter()
}

private struct DetailArtwork: View {
    let media: CatalogMedia
    var body: some View { MosaicArtwork(url: media.backdropURL ?? media.posterURL, fallbackURL: media.posterURL, symbol: media.mediaType.symbolName) }
}
private struct GenreChips: View { let genres: [String]; var body: some View { ScrollView(.horizontal) { HStack(spacing: MosaicSpace.small) { ForEach(genres, id: \.self) { Text($0).font(.caption.weight(.medium)).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, 10).padding(.vertical, 6).background(MosaicColor.surface, in: Capsule()) } }.padding(.vertical, 2) }.scrollIndicators(.hidden) } }
private struct MediaDetailSkeleton: View { let preview: MediaDetailPreview; var body: some View { ScrollView { VStack(alignment: .leading, spacing: MosaicSpace.large) { RoundedRectangle(cornerRadius: MosaicRadius.card).fill(MosaicColor.surface).frame(height: 255); Text(preview.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText); Capsule().fill(MosaicColor.surface).frame(width: 180, height: 14); Capsule().fill(MosaicColor.surface).frame(height: 14); Capsule().fill(MosaicColor.surface).frame(width: 260, height: 14) }.padding(MosaicSpace.large).redacted(reason: .placeholder) }.accessibilityLabel("Loading \(preview.title) details") } }
private struct DetailErrorView: View { let error: DetailErrorPresentation; let retry: () -> Void; var body: some View { VStack(spacing: MosaicSpace.medium) { ContentUnavailableView(error.title, systemImage: "exclamationmark.triangle", description: Text(error.message)); if error != .notFound { Button("Try again", action: retry).buttonStyle(.borderedProminent) } }.foregroundStyle(MosaicColor.secondaryText) } }

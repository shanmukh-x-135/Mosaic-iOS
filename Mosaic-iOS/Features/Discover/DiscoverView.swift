import Observation
import SwiftUI

/// `discoveryRails` in the web `src/lib/media/discovery.ts`: rails are chosen
/// by each section's own media type, never by position, and a medium with no
/// section gets an honest empty rail instead of another medium's items.
enum DiscoverRails {
    static let order: [CatalogMediaType] = [.movie, .tv, .game, .book]

    static func rails(_ sections: [CatalogDiscoverySection], type: CatalogMediaType?) -> [CatalogDiscoverySection] {
        func own(_ mediaType: CatalogMediaType) -> [CatalogDiscoverySection] {
            sections.filter { $0.mediaType == mediaType }.map { CatalogDiscoverySection(id: $0.id, label: $0.label, mediaType: $0.mediaType, items: $0.items.filter { $0.mediaType == mediaType }) }
        }
        if let type { let sections = own(type); return sections.isEmpty ? [unavailable(type)] : sections }
        return order.map { mediaType in let sections = own(mediaType); return sections.first { !$0.items.isEmpty } ?? sections.first ?? unavailable(mediaType) }
    }

    static func unavailable(_ mediaType: CatalogMediaType) -> CatalogDiscoverySection {
        CatalogDiscoverySection(id: "unavailable-\(mediaType.rawValue)", label: mediaType.pluralName, mediaType: mediaType, items: [])
    }

    /// The spotlight: the first four unique titles of the visible sections.
    static func spotlight(_ sections: [CatalogDiscoverySection], type: CatalogMediaType?) -> (items: [CatalogMedia], source: String?) {
        let visible = sections.filter { type == nil || $0.mediaType == type }
        var seen = Set<String>(), items: [CatalogMedia] = []
        for media in visible.flatMap(\.items) where (type == nil || media.mediaType == type) && !seen.contains(media.mediaKey) {
            seen.insert(media.mediaKey); items.append(media)
            if items.count == 4 { break }
        }
        return (items, visible.first { !$0.items.isEmpty }?.label)
    }

    static func intro(for type: CatalogMediaType) -> String {
        switch type {
        case .movie: "What’s trending, playing and coming to theaters."
        case .tv: "Series people are watching now, and the ones still on the air."
        case .game: "Games across release windows, from IGDB."
        case .book: "Fiction from Google Books."
        }
    }
}

extension CatalogMediaType {
    var pluralName: String { switch self { case .movie: "Movies"; case .tv: "Series"; case .game: "Games"; case .book: "Books" } }
}

/// The result of a provider-backed shelf (genre, theme): a provider failure is
/// reported as `failed`, never as an empty list.
enum ShelfResult: Equatable {
    case loading, loaded([CatalogMedia], partial: Bool), failed
    init(_ response: CatalogSearchResponse) {
        self = response.items.isEmpty && !response.failures.isEmpty ? .failed : .loaded(response.items, partial: !response.failures.isEmpty)
    }
}

@MainActor @Observable
final class DiscoverViewModel {
    private(set) var feed: Loadable<CatalogDiscoverResponse> = .idle
    private(set) var type: CatalogMediaType?
    private(set) var selectedGenre: Int?
    private(set) var selectedTheme: String?
    private(set) var genreResult: ShelfResult?
    private(set) var themeResult: ShelfResult?
    private(set) var recommendations: Loadable<RecommendationState> = .idle
    private var shelfTask: Task<Void, Never>?
    private var themeTask: Task<Void, Never>?

    enum RecommendationState { case noSeeds, rows([Recommendations.Row]), nothingNew, failed }

    func load(_ services: MosaicServices, region: String?, force: Bool = false) async {
        guard force || feed.value == nil else { return }
        if feed.value == nil { feed = .loading }
        do { feed = .loaded(try await services.discover(region)) }
        catch is CancellationError {}
        catch { if feed.value == nil { feed = .failed(error) } }
        await loadRecommendations(services)
    }

    /// `chooseType`: a genre or theme survives a switch only when it still means
    /// the same thing for the new medium.
    func choose(_ next: CatalogMediaType?, services: MosaicServices) {
        guard next != type else { return }
        let previous = type
        type = next
        let keptGenre = GenreCatalog.genre(selectedGenre, afterSwitchFrom: previous, to: next)
        if keptGenre != selectedGenre { selectedGenre = nil; genreResult = nil }
        if keptGenre != nil { selectedGenre = keptGenre; loadGenre(services) }
        if let theme = selectedTheme, let next, MosaicTheme.all.first(where: { $0.id == theme })?.mediaTypes.contains(next) != true { selectedTheme = nil; themeResult = nil }
        if selectedTheme != nil { loadTheme(services) }
        Task { await loadRecommendations(services) }
    }

    func toggleGenre(_ id: Int, services: MosaicServices) {
        selectedGenre = selectedGenre == id ? nil : id
        loadGenre(services)
    }

    func toggleTheme(_ id: String, services: MosaicServices) {
        selectedTheme = selectedTheme == id ? nil : id
        loadTheme(services)
    }

    private func loadGenre(_ services: MosaicServices) {
        shelfTask?.cancel()
        guard let genre = selectedGenre, let catalog = GenreCatalog.forTab(type) else { genreResult = nil; return }
        genreResult = .loading
        shelfTask = Task {
            do {
                let response = try await services.genre(catalog.mediaType, genre)
                try Task.checkCancellation()
                genreResult = ShelfResult(response)
            } catch is CancellationError {} catch { genreResult = .failed }
        }
    }

    private func loadTheme(_ services: MosaicServices) {
        themeTask?.cancel()
        guard let theme = selectedTheme else { themeResult = nil; return }
        themeResult = .loading
        let type = type
        themeTask = Task {
            do {
                let response = try await services.theme(theme, type)
                try Task.checkCancellation()
                themeResult = ShelfResult(response)
            } catch is CancellationError {} catch { themeResult = .failed }
        }
    }

    func retryShelves(_ services: MosaicServices) { loadGenre(services); loadTheme(services) }

    /// Seeds come only from logged movie and episode watches (`recommendationSeeds`).
    private func loadRecommendations(_ services: MosaicServices) async {
        guard type != .game, type != .book else { recommendations = .idle; return }
        recommendations = .loading
        let type = type
        do {
            let snapshot = try await services.stateSnapshot()
            let seeds = Recommendations.seeds(from: snapshot, type: type)
            guard !seeds.isEmpty else { recommendations = .loaded(.noSeeds); return }
            var results: [[CatalogMedia]?] = []
            for seed in seeds {
                let response = try? await services.related(seed.route)
                results.append(response.flatMap { $0.items.isEmpty && !$0.failures.isEmpty ? nil : $0.items })
            }
            guard self.type == type else { return }
            if results.allSatisfy({ $0 == nil }) { recommendations = .loaded(.failed); return }
            let rows = Recommendations.build(seeds: seeds, results: results, snapshot: snapshot)
            recommendations = .loaded(rows.isEmpty ? .nothingNew : .rows(rows))
        } catch is CancellationError {
        } catch {
            recommendations = .loaded(.failed)
        }
    }
}

struct DiscoverView: View {
    @Environment(\.mosaicServices) private var services
    @Environment(SessionStore.self) private var session
    @State private var model = DiscoverViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var region: String? { session.currentUser?.profile?.watchRegion }

    var body: some View {
        MosaicScreen {
            MosaicChipRow(
                items: [nil] + DiscoverRails.order.map(Optional.some),
                selection: Binding(get: { model.type }, set: { next in withAnimation(MosaicMotion.standard(reduceMotion: reduceMotion)) { model.choose(next, services: services) } }),
                title: { $0?.pluralName ?? "All" },
                tint: { $0?.accent }
            )
            .accessibilityLabel("Discover media type")
            GenreStrip(model: model)
            content
        }
        .navigationTitle("Discover")
        .toolbar { QuickLogToolbarItem() }
        .task { await model.load(services, region: region) }
        .refreshable { await model.load(services, region: region, force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicProfileDidChange)) { _ in
            Task { await model.load(services, region: region, force: true) }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.feed {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: MosaicLayout.sectionSpacing) {
                MosaicSkeleton(aspectRatio: 1.15).padding(.horizontal, MosaicLayout.pageHorizontal)
                MosaicRail { ForEach(0..<4, id: \.self) { _ in MosaicSkeleton(aspectRatio: MosaicArtworkRatio.poster).frame(width: MosaicLayout.posterWidth) } }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading discovery")
        case let .failed(error):
            MosaicStateMessage(title: "Discovery is taking a breather", message: MosaicErrorCopy.message(for: error), systemImage: "sparkles", actionTitle: "Try again") { Task { await model.load(services, region: region, force: true) } }
        case let .loaded(response):
            DiscoverFeed(response: response, model: model)
        }
    }
}

private struct GenreStrip: View {
    let model: DiscoverViewModel
    @Environment(\.mosaicServices) private var services

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            if let catalog = GenreCatalog.forTab(model.type) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Genres").font(.subheadline.weight(.bold)).foregroundStyle(MosaicColor.primaryText)
                    Text(catalog.label).font(.caption).foregroundStyle(MosaicColor.mutedText)
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
                ScrollView(.horizontal) {
                    HStack(spacing: MosaicSpace.xSmall) {
                        ForEach(catalog.genres) { genre in
                            Button { model.toggleGenre(genre.id, services: services) } label: {
                                Text(genre.name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(model.selectedGenre == genre.id ? MosaicColor.onLight : MosaicColor.secondaryText)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 32)
                                    .background(model.selectedGenre == genre.id ? MosaicColor.primaryText : Color.clear, in: Capsule())
                                    .overlay { Capsule().strokeBorder(model.selectedGenre == genre.id ? Color.clear : MosaicColor.highlight) }
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(model.selectedGenre == genre.id ? .isSelected : [])
                        }
                    }
                }
                .contentMargins(.horizontal, MosaicLayout.pageHorizontal, for: .scrollContent)
                .scrollIndicators(.hidden)
                .accessibilityLabel(catalog.label)
                if model.selectedGenre != nil, let result = model.genreResult {
                    ShelfResultView(result: result, loading: "Finding provider results…", failed: "Genre results are temporarily unavailable. Try again shortly.", empty: "The provider has no titles for this genre right now.", showsMedium: false) { model.retryShelves(services) }
                }
            } else {
                Text("Genre browsing isn’t available for books: Google Books doesn’t offer a category filter that returns results reliably.")
                    .font(.caption).foregroundStyle(MosaicColor.mutedText)
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct DiscoverFeed: View {
    let response: CatalogDiscoverResponse
    let model: DiscoverViewModel
    @Environment(\.mosaicServices) private var services

    var body: some View {
        let spotlight = DiscoverRails.spotlight(response.sections, type: model.type)
        if !response.failures.isEmpty {
            MosaicNotice(text: "Some catalog sources are temporarily unavailable. Showing the stories we found.")
                .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
        if !spotlight.items.isEmpty {
            SpotlightPager(items: spotlight.items, eyebrow: "Spotlight", source: spotlight.source.map { "From \($0)" })
        }
        ThemeGallery(model: model)
        if let type = model.type {
            VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                Text(type.pluralName).font(MosaicType.title).foregroundStyle(type.accent).accessibilityAddTraits(.isHeader)
                Text(DiscoverRails.intro(for: type)).font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
        ForEach(DiscoverRails.rails(response.sections, type: model.type)) { section in
            DiscoverChapter(section: section, isOverview: model.type == nil) { model.choose(section.mediaType, services: services) }
        }
        if model.type != .game && model.type != .book { BecauseYouWatched(model: model) }
        if model.type == nil, !response.items.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("More than one kind of story", eyebrow: "Across Mosaic")
                MosaicPosterShelf(items: response.items, showsMedium: true)
            }
        }
    }
}

private struct ThemeGallery: View {
    let model: DiscoverViewModel
    @Environment(\.mosaicServices) private var services

    var body: some View {
        let themes = Array(MosaicTheme.forTab(model.type).prefix(12))
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Mosaic themes", eyebrow: "Story shapes") {
                if model.selectedTheme != nil { Button("Clear") { model.toggleTheme(model.selectedTheme!, services: services) } }
            }
            MosaicRail(spacing: MosaicSpace.small) {
                ForEach(themes) { theme in
                    let active = model.selectedTheme == theme.id
                    Button { model.toggleTheme(theme.id, services: services) } label: {
                        VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                            Text(theme.label).font(.headline).foregroundStyle(active ? MosaicColor.onLight : MosaicColor.primaryText)
                            Text(theme.tagline).font(.caption).foregroundStyle(active ? MosaicColor.onLight.opacity(0.7) : MosaicColor.secondaryText).lineLimit(2, reservesSpace: true)
                        }
                        .padding(MosaicSpace.medium)
                        .frame(width: 168, alignment: .leading)
                        .background(active ? MosaicColor.primaryText : MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).strokeBorder(MosaicColor.border) }
                        .contentShape(RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                    .accessibilityHint(theme.tagline)
                }
            }
            if let id = model.selectedTheme, let theme = MosaicTheme.all.first(where: { $0.id == id }), let result = model.themeResult {
                Text(model.type.map { "\(theme.label) in \($0.pluralName.lowercased())" } ?? theme.label)
                    .font(.subheadline.weight(.bold)).foregroundStyle(MosaicColor.primaryText)
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
                ShelfResultView(result: result, loading: "Building this shelf from provider metadata…", failed: "Theme results are temporarily unavailable. Try again shortly.", empty: "The providers have no titles for this theme right now.", showsMedium: model.type == nil) { model.retryShelves(services) }
            }
        }
    }
}

private struct DiscoverChapter: View {
    let section: CatalogDiscoverySection
    let isOverview: Bool
    let explore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader(section.label, eyebrow: section.mediaType.pluralName) {
                if isOverview { Button("See all", action: explore).accessibilityLabel("See all \(section.mediaType.pluralName.lowercased())") }
            }
            if section.items.isEmpty {
                Text("No \(section.mediaType.pluralName.lowercased()) are available from the catalog right now.")
                    .font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
            } else {
                MosaicPosterShelf(items: section.items)
            }
        }
    }
}

private struct BecauseYouWatched: View {
    let model: DiscoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Because you watched", eyebrow: "From your history")
            Group {
                switch model.recommendations {
                case .idle, .loading: note("Finding titles like the ones you watched…")
                case .failed, .loaded(.failed): note("Recommendations are temporarily unavailable. Try again shortly.")
                case .loaded(.noSeeds): note("Log a movie or an episode and Mosaic will recommend titles like it here.")
                case .loaded(.nothingNew): note("No new recommendations for what you watched recently: everything suggested is already in your library.")
                case let .loaded(.rows(rows)):
                    VStack(alignment: .leading, spacing: MosaicLayout.sectionSpacing - 8) {
                        ForEach(rows) { row in
                            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                                Text("Like \(row.seed.title)").font(.subheadline.weight(.bold)).foregroundStyle(MosaicColor.primaryText)
                                    .padding(.horizontal, MosaicLayout.pageHorizontal)
                                MosaicPosterShelf(items: row.items, showsMedium: model.type == nil)
                            }
                        }
                    }
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
            .padding(.horizontal, MosaicLayout.pageHorizontal)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShelfResultView: View {
    let result: ShelfResult
    let loading: String
    let failed: String
    let empty: String
    var showsMedium = false
    var retry: (() -> Void)?

    var body: some View {
        switch result {
        case .loading:
            HStack(spacing: MosaicSpace.small) { ProgressView(); Text(loading) }
                .font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                .padding(.horizontal, MosaicLayout.pageHorizontal)
        case .failed:
            VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
                MosaicNotice(text: failed, tone: .failure)
                if let retry { Button("Try again", action: retry).font(.subheadline.weight(.semibold)) }
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        case let .loaded(items, partial):
            if items.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, MosaicLayout.pageHorizontal)
            } else {
                if partial { MosaicNotice(text: "Some providers are unavailable; showing what they returned.").padding(.horizontal, MosaicLayout.pageHorizontal) }
                MosaicPosterShelf(items: items, showsMedium: showsMedium)
            }
        }
    }
}

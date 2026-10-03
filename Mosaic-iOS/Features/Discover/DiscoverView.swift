import SwiftUI
import Observation

@MainActor @Observable
final class DiscoverViewModel {
    enum State { case loading, loaded(CatalogDiscoverResponse), failed }
    private let loadResponse: @Sendable () async throws -> CatalogDiscoverResponse
    private var task: Task<Void, Never>?
    private(set) var state: State = .loading
    var filter: CatalogFilter = .all

    init(client: MosaicAPIClient) {
        loadResponse = { try await client.publicRequest(path: "/api/catalog/discover", as: CatalogDiscoverResponse.self) }
    }

    func load() {
        guard task == nil else { return }
        task = Task { [weak self, loadResponse] in
            defer { Task { @MainActor [weak self] in self?.task = nil } }
            do { self?.state = .loaded(try await loadResponse()) }
            catch { self?.state = .failed }
        }
    }

    func retry() { task?.cancel(); task = nil; state = .loading; load() }
}

struct DiscoverView: View {
    @State private var model = DiscoverViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL))

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading: DiscoverSkeleton()
                case let .loaded(response): DiscoverContent(response: response, filter: $model.filter)
                case .failed:
                    ContentUnavailableView("Discovery is taking a breather", systemImage: "sparkles", description: Text("Try again shortly to see live Mosaic catalogs."))
                        .foregroundStyle(MosaicColor.secondaryText)
                }
            }
            .background(MosaicColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { GlobalSearchLink() } }
            .task { model.load() }
            .refreshable { model.retry() }
        }
    }
}

private struct DiscoverContent: View {
    let response: CatalogDiscoverResponse
    @Binding var filter: CatalogFilter
    @State private var selectedGenre: String?
    private var baseSections: [CatalogDiscoverySection] { filter == .all ? response.sections : response.sections.filter { $0.mediaType == CatalogMediaType(rawValue: filter.catalogType ?? "") } }
    private var sections: [CatalogDiscoverySection] {
        guard let selectedGenre else { return baseSections }
        return baseSections.map { section in
            CatalogDiscoverySection(id: section.id, label: section.label, mediaType: section.mediaType, items: section.items.filter { $0.genres.contains(selectedGenre) })
        }.filter { !$0.items.isEmpty }
    }
    private var genres: [String] {
        Array(Set(baseSections.flatMap(\.items).flatMap(\.genres))).sorted().prefix(12).map { $0 }
    }
    private var spotlight: CatalogMedia? { sections.flatMap(\.items).first ?? response.items.first }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MosaicSpace.xLarge) {
                VStack(alignment: .leading, spacing: 4) {
                    MosaicEyebrow(title: "Live catalogs")
                    Text("Discover").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                }.padding(.horizontal, MosaicLayout.screenMargin)
                if let spotlight { DiscoverHero(media: spotlight) }
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    VStack(alignment: .leading, spacing: 4) {
                        MosaicEyebrow(title: "Editorial discovery")
                        Text("Find your next obsession").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                        Text("Live catalogs, shaped around the stories you keep coming back to.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    }.padding(.horizontal, MosaicLayout.screenMargin)
                    ScrollView(.horizontal) { HStack(spacing: MosaicSpace.small) { ForEach(CatalogFilter.allCases) { item in Button { filter = item } label: { MosaicFilterChip(title: item.title, selected: item == filter) } } }.padding(.horizontal, MosaicLayout.screenMargin) }.scrollIndicators(.hidden)
                }
                if !genres.isEmpty {
                    VStack(alignment: .leading, spacing: MosaicSpace.small) {
                        MosaicSectionHeader("Browse by genre", eyebrow: "Find your next mood")
                        ScrollView(.horizontal) {
                            HStack(spacing: MosaicSpace.small) {
                                Button { selectedGenre = nil } label: { MosaicFilterChip(title: "All genres", selected: selectedGenre == nil) }
                                ForEach(genres, id: \.self) { genre in
                                    Button { selectedGenre = selectedGenre == genre ? nil : genre } label: { MosaicFilterChip(title: genre, selected: selectedGenre == genre) }
                                }
                            }
                            .padding(.horizontal, MosaicLayout.screenMargin)
                        }.scrollIndicators(.hidden).frame(maxWidth: .infinity)
                    }
                }
                if !response.failures.isEmpty { Text("Some catalog sources are temporarily unavailable. Showing the stories we found.").font(.footnote).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, MosaicLayout.screenMargin) }
                ForEach(sections) { section in DiscoverRail(section: section) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, MosaicSpace.large)
        }
    }
}

private struct DiscoverHero: View {
    let media: CatalogMedia
    var body: some View {
        NavigationLink { MediaDetailContainer(route: media.route, preview: MediaDetailPreview(media: media)) } label: {
            ZStack(alignment: .bottomLeading) {
                MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: media.mediaType.symbolName)
                LinearGradient(colors: [.clear, MosaicColor.background.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicEyebrow(title: "Mosaic spotlight")
                    Text(media.title).font(MosaicType.hero).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                    HStack(spacing: MosaicSpace.small) { if let year = media.releaseYear { Text(String(year)) }; if let genre = media.genres.first { Text(genre) }; if let rating = media.communityRating { MosaicRating(value: rating) } }.font(MosaicType.metadata).foregroundStyle(MosaicColor.secondaryText)
                    if let description = media.description { Text(description).font(.subheadline).foregroundStyle(MosaicColor.secondaryText).lineLimit(2) }
                    Label("View story", systemImage: "play.fill").font(.subheadline.weight(.bold)).foregroundStyle(MosaicColor.background).padding(.horizontal, 14).padding(.vertical, 10).background(MosaicColor.primaryText, in: Capsule())
                }.padding(MosaicSpace.large)
            }
            .frame(height: 230)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
            .padding(.horizontal, MosaicLayout.screenMargin)
        }.buttonStyle(.plain)
    }
}

private struct DiscoverRail: View {
    let section: CatalogDiscoverySection
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader(section.label, eyebrow: section.mediaType.displayName)
            ScrollView(.horizontal) {
                LazyHStack(spacing: MosaicSpace.medium) { ForEach(section.items) { media in NavigationLink { MediaDetailContainer(route: media.route, preview: MediaDetailPreview(media: media)) } label: { DiscoverPoster(media: media) }.buttonStyle(.plain) } }.padding(.horizontal, MosaicLayout.pageHorizontal)
            }.scrollIndicators(.hidden).frame(maxWidth: .infinity)
        }
    }
}

struct DiscoverPoster: View {
    let media: CatalogMedia
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            MosaicArtwork(url: media.posterURL, fallbackURL: media.backdropURL, symbol: media.mediaType.symbolName).frame(width: MosaicLayout.posterWidth, height: MosaicLayout.posterHeight).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
            Text(media.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(1).frame(width: MosaicLayout.posterWidth, alignment: .leading)
            Text(media.resultMetadata).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1).frame(width: MosaicLayout.posterWidth, alignment: .leading)
        }
    }
}

private struct DiscoverSkeleton: View {
    var body: some View { MosaicScreen { MosaicSkeleton().frame(height: MosaicLayout.backdropHeight).padding(.horizontal, MosaicLayout.pageHorizontal); ForEach(0..<2, id: \.self) { _ in VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicSectionHeader("Loading stories", eyebrow: "Discover"); ScrollView(.horizontal) { HStack(spacing: MosaicSpace.medium) { ForEach(0..<3, id: \.self) { _ in MosaicSkeleton(aspectRatio: 0.68).frame(width: MosaicLayout.posterWidth) } }.padding(.horizontal, MosaicLayout.pageHorizontal) }.frame(maxWidth: .infinity) } } }.accessibilityLabel("Loading discovery") }
}

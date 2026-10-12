import Observation
import SwiftUI

struct MediaDetailContainer: View {
    let route: MediaDetailRoute
    let preview: MediaDetailPreview
    @Environment(\.mosaicServices) private var services
    @State private var model: MediaDetailViewModel?

    var body: some View {
        Group {
            switch model?.state ?? .idle {
            case .idle, .loading: MediaDetailSkeleton(preview: preview)
            case let .loaded(media): typedDetail(media)
            case let .error(error): DetailErrorView(error: error) { model?.retry() }
            }
        }
        .background(MosaicColor.background)
        .navigationTitle(preview.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if model == nil { model = MediaDetailViewModel(route: route, request: services.detail) }
            model?.load()
        }
    }

    @ViewBuilder private func typedDetail(_ media: CatalogMedia) -> some View {
        switch media.mediaType {
        case .tv: SeriesHubView(media: media)
        case .movie, .game, .book: MediaDetailContent(media: media)
        }
    }
}

struct MediaDetailPreview: Hashable, Sendable {
    let title: String
    let artworkURL: URL?
    let fallbackArtworkURL: URL?
    let mediaType: CatalogMediaType

    init(story: ContinueStory) {
        title = story.title; artworkURL = story.artworkURL; fallbackArtworkURL = story.fallbackArtworkURL; mediaType = story.detailRoute.mediaType
    }
    init(media: CatalogMedia) {
        title = media.title; artworkURL = media.backdropURL; fallbackArtworkURL = media.posterURL; mediaType = media.mediaType
    }
    init(library: LibraryItemDTO) {
        title = library.title; artworkURL = library.backdropURL; fallbackArtworkURL = library.posterURL; mediaType = library.mediaType
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

@MainActor @Observable
final class MediaDetailViewModel {
    private let route: MediaDetailRoute
    private let request: @Sendable (MediaDetailRoute) async throws -> CatalogMedia
    private var loadTask: Task<Void, Never>?
    private(set) var state: MediaDetailState = .idle

    init(route: MediaDetailRoute, request: @escaping @Sendable (MediaDetailRoute) async throws -> CatalogMedia) { self.route = route; self.request = request }

    func load() {
        guard loadTask == nil, state.loadedMedia == nil else { return }
        state = .loading
        loadTask = Task { [weak self, route, request] in
            do {
                let media = try await request(route)
                try Task.checkCancellation()
                self?.state = .loaded(media)
            } catch is CancellationError {
                self?.state = .idle
            } catch {
                self?.state = .error(DetailErrorPresentation.from(error))
            }
            self?.loadTask = nil
        }
    }
    func retry() { load() }
}

private extension MediaDetailState {
    var loadedMedia: CatalogMedia? { if case let .loaded(media) = self { media } else { nil } }
}

// MARK: - Movie, game and book detail

private struct MediaDetailContent: View {
    let media: CatalogMedia
    @State private var showsFullAbout = false

    var body: some View {
        MosaicScreen {
            DetailHero(media: media)
            DetailIdentity(media: media)
            PersonalStoryPanel(media: media)
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            if let description = media.description, !description.isEmpty {
                DetailAbout(text: description)
            }
            DetailFacts(facts: facts)
        }
    }

    /// Only facts the provider supplied; a missing value is omitted, never shown as zero.
    private var facts: [DetailFact] {
        switch media.mediaType {
        case .movie:
            [DetailFact("Runtime", media.runtimeMinutes.map(MosaicDuration.playtime)), DetailFact("Director", media.director), DetailFact("Studio", media.studio), DetailFact("Released", media.releaseDate)]
        case .game:
            [DetailFact("Platforms", media.platforms.flatMap { $0.isEmpty ? nil : $0.joined(separator: ", ") }), DetailFact("Developer", media.developer), DetailFact("Publisher", media.publisher), DetailFact("Released", media.releaseDate)]
        case .book:
            [DetailFact("Author", media.authors.flatMap { $0.isEmpty ? nil : $0.joined(separator: ", ") }), DetailFact("Pages", media.pageCount.map(String.init)), DetailFact("Publisher", media.publisher), DetailFact("Published", media.releaseDate), DetailFact("ISBN", media.isbn)]
        case .tv:
            []
        }
    }
}

struct DetailHero: View {
    let media: CatalogMedia
    var body: some View {
        Group {
            if media.backdropURL != nil {
                MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, mediaType: media.mediaType)
                    .aspectRatio(MosaicArtworkRatio.backdrop, contentMode: .fit)
            } else {
                // Poster-only titles (most books and games) keep their poster upright.
                LinearGradient(colors: media.mediaType.fallbackGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .aspectRatio(MosaicArtworkRatio.backdrop, contentMode: .fit)
                    .overlay {
                        MosaicArtwork(url: media.posterURL, mediaType: media.mediaType, title: media.title)
                            .aspectRatio(MosaicArtworkRatio.poster, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small, style: .continuous))
                            .shadow(color: .black.opacity(0.4), radius: 12, y: 8)
                            .padding(MosaicSpace.medium)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous).strokeBorder(MosaicColor.border) }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
}

struct DetailIdentity: View {
    let media: CatalogMedia
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            MosaicMediaLabel(mediaType: media.mediaType)
            Text(media.title)
                .font(MosaicType.display)
                .foregroundStyle(MosaicColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle = media.subtitle { Text(subtitle).font(.headline).foregroundStyle(MosaicColor.secondaryText) }
            HStack(spacing: MosaicSpace.small) {
                if let line = metadataLine { Text(line).font(.subheadline).foregroundStyle(MosaicColor.secondaryText).lineLimit(2) }
                if let rating = media.community { MosaicCommunityRatingLabel(rating: rating) }
            }
            if !media.genres.isEmpty {
                Text(media.genres.joined(separator: " · ")).font(.footnote).foregroundStyle(MosaicColor.mutedText).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }

    private var metadataLine: String? {
        var values: [String] = []
        if let year = media.releaseYear { values.append(String(year)) }
        switch media.mediaType {
        case .movie: if let runtime = media.runtimeMinutes { values.append(MosaicDuration.playtime(runtime)) }
        case .tv: if let network = media.network { values.append(network) }
        case .game: if let platform = media.platforms?.first { values.append(media.platforms!.count > 1 ? "\(platform) +\(media.platforms!.count - 1)" : platform) }
        case .book: if let authors = media.authors, !authors.isEmpty { values.append(authors.joined(separator: ", ")) }
        }
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }
}

struct DetailAbout: View {
    let text: String
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            MosaicSectionHeader("About")
            Text(text)
                .font(.body)
                .foregroundStyle(MosaicColor.secondaryText)
                .lineLimit(expanded ? nil : 6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            if text.count > 320 {
                Button(expanded ? "Show less" : "Read more") { expanded.toggle() }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
        }
    }
}

struct DetailFact: Identifiable {
    let label: String
    let value: String?
    var id: String { label }
    init(_ label: String, _ value: String?) { self.label = label; self.value = value }
}

struct DetailFacts: View {
    let facts: [DetailFact]
    var body: some View {
        let available = facts.filter { $0.value?.isEmpty == false }
        if !available.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicSectionHeader("Details")
                VStack(spacing: 0) {
                    ForEach(available) { fact in
                        HStack(alignment: .firstTextBaseline, spacing: MosaicSpace.medium) {
                            Text(fact.label).foregroundStyle(MosaicColor.secondaryText)
                            Spacer(minLength: MosaicSpace.small)
                            Text(fact.value ?? "").foregroundStyle(MosaicColor.primaryText).multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                        .padding(.vertical, MosaicSpace.small)
                        .accessibilityElement(children: .combine)
                        if fact.id != available.last?.id { Divider().overlay(MosaicColor.border) }
                    }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
        }
    }
}

// MARK: - Personal actions

/// The user's own state for one title: status, rating, favourite and the
/// medium's logging action. Every change goes through a documented mutation;
/// the shared Library store refreshes afterwards.
struct PersonalStoryPanel: View {
    let media: CatalogMedia
    /// Series supply their own primary action (episode logging).
    var showsLogAction = true
    @Environment(LibraryStore.self) private var library
    @Environment(\.mosaicServices) private var services
    @State private var isSaving = false
    @State private var notice: (String, MosaicNotice.Tone)?
    @State private var presentsLog = false
    @State private var confirmsRemoval = false

    private var entry: LibraryItemDTO? { library.entry(for: media) }

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                    MosaicEyebrow(title: "Your story", color: media.mediaType.accent)
                    Text(entry?.statusLabel ?? (library.hasLoaded ? "Not in your Library yet" : "Loading your story…"))
                        .font(MosaicType.section).foregroundStyle(MosaicColor.primaryText)
                }
                Spacer(minLength: MosaicSpace.small)
                if let rating = entry?.userRating { MosaicUserRatingLabel(value: rating) }
            }
            // Series show episode progress above the panel, from the per-episode record.
            if media.mediaType != .tv, let progress = entry?.progressLine {
                VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
                    Text(progress.text).font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    if let fraction = progress.fraction { MosaicProgressBar(fraction: fraction, tint: media.mediaType.accent) }
                }
            }
            if showsLogAction {
                Button { presentsLog = true } label: {
                    Label(MediaLogForm.actionTitle(for: media.mediaType), systemImage: media.mediaType == .movie ? "checkmark.circle" : "chart.bar.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(media.mediaType.accent)
                .foregroundStyle(MosaicColor.onLight)
                .controlSize(.large)
                .disabled(isSaving)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: MosaicSpace.small) { statusMenu; ratingMenu; favouriteButton }
                VStack(alignment: .leading, spacing: MosaicSpace.small) { HStack(spacing: MosaicSpace.small) { statusMenu; favouriteButton }; ratingMenu }
            }
            .disabled(isSaving || !library.hasLoaded)
            if let notice { MosaicNotice(text: notice.0, tone: notice.1) }
        }
        .padding(MosaicSpace.medium)
        .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous).strokeBorder(MosaicColor.border) }
        .sheet(isPresented: $presentsLog) {
            NavigationStack { MediaLogForm(media: media, onSaved: { notice = ("Saved to your Mosaic.", .success) }) }
        }
        .confirmationDialog("Remove \(media.title) from your Library?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("Remove from Library", role: .destructive) { save(.removeLibrary(media), success: "Removed from your Library.") }
        } message: { Text("Your logs, ratings and history stay in your diary.") }
    }

    private var statusMenu: some View {
        Menu {
            Picker("Status", selection: Binding(get: { entry?.libraryStatus }, set: { status in
                if let status { save(.library(media, status: status.rawValue), success: "Status set to \(status.label).") }
            })) {
                ForEach(LibraryStatus.statuses(for: media.mediaType), id: \.self) { status in
                    Label(status.label, systemImage: status.systemImage).tag(Optional(status))
                }
            }
            if entry != nil {
                Divider()
                Button("Remove from Library", systemImage: "trash", role: .destructive) { confirmsRemoval = true }
            }
        } label: {
            Label(entry == nil ? "Add to Library" : "Status", systemImage: entry?.libraryStatus?.systemImage ?? "plus")
        }
        .buttonStyle(.bordered)
        .accessibilityHint(entry.map { "Current status \($0.statusLabel)" } ?? "Choose a status to add this title")
    }

    private var ratingMenu: some View {
        Menu {
            Picker("Your rating", selection: Binding(get: { entry?.userRating }, set: { value in
                save(.rating(media, value), success: value.map { "Rated \(UserRating.format($0)) out of 5." } ?? "Rating cleared.")
            })) {
                ForEach(UserRating.options.reversed(), id: \.self) { value in Text("\(UserRating.format(value)) ★").tag(Optional(value)) }
            }
            if entry?.userRating != nil {
                Divider()
                Button("Clear rating", systemImage: "xmark") { save(.rating(media, nil), success: "Rating cleared.") }
            }
        } label: {
            Label(entry?.userRating.map { "\(UserRating.format($0)) ★" } ?? "Rate", systemImage: "star")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(entry?.userRating.map { "Your rating \(UserRating.format($0)) out of 5. Change rating" } ?? "Rate")
    }

    private var favouriteButton: some View {
        let isFavorite = entry?.isFavorite == true
        return Button {
            // An untracked title is added with its planned status, so a favourite never starts a series.
            let status = entry?.status ?? LibraryStatus.saveForLater(for: media.mediaType).rawValue
            save(.library(media, status: status, isFavorite: !isFavorite), success: isFavorite ? "Removed from favourites." : "Added to favourites.")
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart").frame(minWidth: 22)
        }
        .buttonStyle(.bordered)
        .tint(isFavorite ? MosaicColor.danger : MosaicColor.accent)
        .accessibilityLabel(isFavorite ? "Remove favourite" : "Add favourite")
    }

    private func save(_ mutation: DetailMutation, success: String) {
        guard !isSaving else { return }
        isSaving = true; notice = nil
        Task {
            do {
                try await services.mutate(mutation)
                notice = (success, .success)
            } catch {
                notice = ("Mosaic couldn’t save that change. Try again.", .failure)
            }
            isSaving = false
        }
    }
}

// MARK: - Loading and error

private struct MediaDetailSkeleton: View {
    let preview: MediaDetailPreview
    var body: some View {
        MosaicScreen {
            MosaicArtwork(url: preview.artworkURL, fallbackURL: preview.fallbackArtworkURL, mediaType: preview.mediaType)
                .aspectRatio(MosaicArtworkRatio.backdrop, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicMediaLabel(mediaType: preview.mediaType)
                Text(preview.title).font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                Capsule().fill(MosaicColor.surface).frame(width: 180, height: 14)
                Capsule().fill(MosaicColor.surface).frame(height: 14)
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading \(preview.title) details")
    }
}

private struct DetailErrorView: View {
    let error: DetailErrorPresentation
    let retry: () -> Void
    var body: some View {
        MosaicStateMessage(title: error.title, message: error.message, systemImage: "exclamationmark.triangle", actionTitle: error == .notFound ? nil : "Try again", action: error == .notFound ? nil : retry)
            .frame(maxHeight: .infinity)
    }
}

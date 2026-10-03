import SwiftUI
import Observation
import os

private let seriesLogger = Logger(subsystem: "com.shanmukhpgsspersonalteam.MosaiciOS", category: "Series")

struct SeriesHubView: View {
    let media: CatalogMedia
    @Environment(SessionStore.self) private var session
    @State private var state: SeriesPersonalStateViewModel

    init(media: CatalogMedia) {
        self.media = media
        _state = State(initialValue: SeriesPersonalStateViewModel(media: media, client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL)))
    }

    private var seasons: [Int] {
        let declared = media.seasonNumbers ?? Array(1...(media.seasonCount ?? 0))
        return declared.filter { $0 > 0 }.sorted()
    }

    var body: some View {
        MosaicScreen {
            MosaicArtwork(url: media.backdropURL, fallbackURL: media.posterURL, symbol: "tv")
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
                .padding(.horizontal, MosaicLayout.pageHorizontal)

            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicEyebrow(title: "Series")
                Text(media.title)
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .foregroundStyle(MosaicColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                SeriesIdentity(media: media)
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)

            SeriesPersonalStory(media: media, state: state)
                .padding(.horizontal, MosaicLayout.pageHorizontal)

            if let description = media.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicSectionHeader("About")
                    Text(description).foregroundStyle(MosaicColor.secondaryText).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, MosaicLayout.pageHorizontal)
                }
            }

            if !seasons.isEmpty {
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicSectionHeader("Seasons", eyebrow: "Episode guide")
                    ForEach(seasons, id: \.self) { number in
                        NavigationLink {
                            SeasonExperienceView(series: media, seasonNumber: number, personalState: state.value)
                        } label: {
                            SeasonRow(media: media, seasonNumber: number, personalState: state.value)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, MosaicLayout.pageHorizontal)
                    }
                }
            }
        }
        .task { await state.load(using: session) }
    }
}

private struct SeriesIdentity: View {
    let media: CatalogMedia
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: MosaicSpace.small) {
                if let year = media.releaseYear { Text(String(year)) }
                if let rating = media.communityRating { MosaicRating(value: rating) }
                if let network = media.network { Text(network).lineLimit(1) }
            }
            .font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
            if !media.genres.isEmpty { Text(media.genres.joined(separator: " · ")).font(.footnote).foregroundStyle(MosaicColor.secondaryText) }
        }
    }
}

private struct SeriesPersonalStory: View {
    let media: CatalogMedia
    let state: SeriesPersonalStateViewModel
    @Environment(SessionStore.self) private var session
    @State private var isSaving = false
    @State private var notice: String?

    private var watchedCount: Int { state.value?.watchedCoordinates.count ?? 0 }
    private var total: Int? { media.eligibleEpisodeCount ?? media.episodeCount }
    private var next: (Int, Int)? {
        guard let total, watchedCount < total else { return nil }
        let counts = media.eligibleEpisodeCounts ?? media.seasonEpisodeCounts ?? [:]
        for season in (media.seasonNumbers ?? []).filter({ $0 > 0 }).sorted() {
            for episode in 1...(counts[String(season)] ?? 0) where !(state.value?.watchedCoordinates.contains("\(season):\(episode)") ?? false) { return (season, episode) }
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicEyebrow(title: "Your story")
            HStack(alignment: .firstTextBaseline) {
                Text(state.value?.status?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Not in your Library")
                    .font(MosaicType.title).foregroundStyle(MosaicColor.primaryText)
                Spacer(minLength: MosaicSpace.small)
                if state.value?.isFavorite == true { Image(systemName: "heart.fill").foregroundStyle(MosaicColor.accent).accessibilityLabel("Favourite") }
            }
            if let total {
                Text("\(watchedCount) of \(total) episodes").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                ProgressView(value: Double(watchedCount), total: Double(total)).tint(MosaicColor.accent)
            } else if watchedCount > 0 {
                Text("\(watchedCount) episodes watched").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
            }
            if let next { Text("Next · S\(String(format: "%02d", next.0))E\(String(format: "%02d", next.1))").font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.accent) }
            HStack(spacing: MosaicSpace.small) {
                if let next {
                    Button("Log next episode") { log(next) }.buttonStyle(.glassProminent).disabled(isSaving)
                }
                Menu {
                    ForEach(["watchlist", "watching", "paused", "completed", "dropped"], id: \.self) { status in
                        Button(status.replacingOccurrences(of: "_", with: " ").capitalized) { save(.library(media, status: status, isFavorite: state.value?.isFavorite)) }
                    }
                } label: { Label("Status", systemImage: "ellipsis.circle") }
                .buttonStyle(.glass).disabled(isSaving)
            }
            if let notice { Text(notice).font(.footnote).foregroundStyle(MosaicColor.secondaryText) }
        }
        .task { await state.load(using: session) }
    }

    private func log(_ coordinate: (Int, Int)) { save(.episodeLog(media, season: coordinate.0, episode: coordinate.1, watchedAt: .now, rating: nil)) }
    private func save(_ mutation: DetailMutation) {
        guard !isSaving else { return }
        isSaving = true
        Task {
            do {
                let token = try await session.currentAccessToken()
                try await MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL).mutate(path: "/api/me/state", body: mutation, token: token)
                await SeriesPersonalStateCache.shared.invalidate(media.route)
                await MainActor.run { notice = "Saved to your Mosaic."; isSaving = false }
                await state.refresh(using: session)
            } catch { await MainActor.run { notice = "Mosaic couldn’t save that change. Try again."; isSaving = false } }
        }
    }
}

private struct SeasonRow: View {
    let media: CatalogMedia
    let seasonNumber: Int
    let personalState: SeriesPersonalState?
    private var count: Int? { (media.eligibleEpisodeCounts ?? media.seasonEpisodeCounts)?[String(seasonNumber)] }
    private var watched: Int { personalState?.episodes.filter { $0.seasonNumber == seasonNumber }.count ?? 0 }
    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            MosaicArtwork(url: media.posterURL, fallbackURL: media.backdropURL, symbol: "tv").frame(width: 56, height: 78).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text("Season \(seasonNumber)").font(.headline).foregroundStyle(MosaicColor.primaryText)
                Text(count.map { "\(watched) / \($0) watched" } ?? "\(watched) watched").font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                if let count, count > 0 { ProgressView(value: Double(watched), total: Double(count)).tint(MosaicColor.accent) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.mutedText)
        }
        .padding(MosaicSpace.small)
        .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous))
    }
}

private struct SeasonExperienceView: View {
    let series: CatalogMedia
    let seasonNumber: Int
    let personalState: SeriesPersonalState?
    @State private var model: SeasonEpisodesViewModel

    init(series: CatalogMedia, seasonNumber: Int, personalState: SeriesPersonalState?) {
        self.series = series
        self.seasonNumber = seasonNumber
        self.personalState = personalState
        _model = State(initialValue: SeasonEpisodesViewModel(route: SeriesSeasonRoute(series: series, seasonNumber: seasonNumber), client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL)))
    }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicEyebrow(title: series.title)
                Text("Season \(seasonNumber)").font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText)
                if let episodes = model.episodes {
                    let watched = episodes.filter { personalState?.watched($0) == true }.count
                    Text("\(watched) / \(episodes.count) watched").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    ProgressView(value: Double(watched), total: Double(max(episodes.count, 1))).tint(MosaicColor.accent)
                }
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
            switch model.state {
            case .idle, .loading:
                ProgressView("Loading episodes").frame(maxWidth: .infinity, minHeight: 180)
            case let .loaded(episodes):
                ForEach(episodes) { episode in
                    NavigationLink { EpisodeExperienceView(series: series, seasonRoute: model.route, episode: episode, episodes: episodes, watched: personalState?.watched(episode) == true) } label: {
                        EpisodeRow(episode: episode, watched: personalState?.watched(episode) == true)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
                }
            case .failed:
                ContentUnavailableView("Episodes are unavailable", systemImage: "exclamationmark.triangle", description: Text("Try again in a moment."))
            }
        }
        .navigationTitle("")
        .task { model.load() }
    }
}

private struct EpisodeRow: View {
    let episode: CatalogEpisode
    let watched: Bool
    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            MosaicArtwork(url: episode.stillURL, symbol: "tv").frame(width: 104, height: 62).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("S\(String(format: "%02d", episode.seasonNumber))E\(String(format: "%02d", episode.episodeNumber))").font(.caption.weight(.bold)).foregroundStyle(MosaicColor.accent)
                Text(episode.title).font(.headline).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                Text([episode.runtimeMinutes.map { "\($0)m" }, episode.airDate, episode.publicRating.map { "★ \($0.formatted(.number.precision(.fractionLength(1))))" }].compactMap { $0 }.joined(separator: " · ")).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: watched ? "checkmark.circle.fill" : "circle").foregroundStyle(watched ? MosaicColor.accent : MosaicColor.mutedText)
        }
        .padding(.vertical, MosaicSpace.xSmall)
    }
}

private struct EpisodeExperienceView: View {
    let series: CatalogMedia
    let seasonRoute: SeriesSeasonRoute
    let episode: CatalogEpisode
    let episodes: [CatalogEpisode]
    let watched: Bool
    @Environment(SessionStore.self) private var session
    @State private var isWatched: Bool
    @State private var isSaving = false
    @State private var presentsLogSheet = false
    @State private var notice: String?

    init(series: CatalogMedia, seasonRoute: SeriesSeasonRoute, episode: CatalogEpisode, episodes: [CatalogEpisode], watched: Bool) {
        self.series = series
        self.seasonRoute = seasonRoute
        self.episode = episode
        self.episodes = episodes
        self.watched = watched
        _isWatched = State(initialValue: watched)
    }

    var body: some View {
        MosaicScreen {
            MosaicArtwork(url: episode.stillURL, fallbackURL: series.backdropURL ?? series.posterURL, symbol: "tv")
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicEyebrow(title: "\(series.title) · Season \(episode.seasonNumber)")
                Text("Episode \(episode.episodeNumber)").font(.headline).foregroundStyle(MosaicColor.secondaryText)
                Text(episode.title).font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText).fixedSize(horizontal: false, vertical: true)
                Text([episode.airDate, episode.runtimeMinutes.map { "\($0) min" }].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                if let rating = episode.publicRating { MosaicRating(value: rating) }
            }.padding(.horizontal, MosaicLayout.pageHorizontal)
            if let overview = episode.overview, !overview.isEmpty { VStack(alignment: .leading, spacing: MosaicSpace.small) { MosaicSectionHeader("About this episode"); Text(overview).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, MosaicLayout.pageHorizontal) } }
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicSectionHeader("Your episode")
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    Label(isWatched ? "Watched" : "Not watched", systemImage: isWatched ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isWatched ? MosaicColor.accent : MosaicColor.secondaryText)
                    if isWatched {
                        Button("Unwatch") { save(.episodeUnwatch(series, season: seasonRoute.seasonNumber, episode: episode.episodeNumber)) }
                            .buttonStyle(.glass)
                            .disabled(isSaving)
                    } else {
                        Button("Log watched") { presentsLogSheet = true }
                            .buttonStyle(.glassProminent)
                            .disabled(isSaving)
                    }
                    if let notice { Text(notice).font(.footnote).foregroundStyle(MosaicColor.secondaryText) }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
            EpisodeAdjacentNavigation(series: series, seasonRoute: seasonRoute, episode: episode, episodes: episodes, watchedCoordinates: [])
        }
        .sheet(isPresented: $presentsLogSheet) { EpisodeLogSheet { date, rating in save(.episodeLog(series, season: seasonRoute.seasonNumber, episode: episode.episodeNumber, watchedAt: date, rating: rating)) } }
    }

    private func save(_ mutation: DetailMutation) {
        guard !isSaving else { return }
        isSaving = true; notice = nil
        Task {
            do {
                let token = try await session.currentAccessToken()
                let clock = ContinuousClock(); let start = clock.now
                try await MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL).mutate(path: "/api/me/state", body: mutation, token: token)
                seriesLogger.debug("Episode mutation completed in \(String(describing: start.duration(to: clock.now)), privacy: .public)")
                await SeriesPersonalStateCache.shared.invalidate(series.route)
                await SeriesSeasonCache.shared.invalidate(seasonRoute)
                await MainActor.run { isWatched = mutation.type == "episode.log"; notice = isWatched ? "Episode logged." : "Episode marked unwatched."; isSaving = false }
            } catch { await MainActor.run { notice = "Mosaic couldn’t save that change. Try again."; isSaving = false } }
        }
    }
}

private struct EpisodeLogSheet: View {
    let onSave: (Date, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var rating = 0.0
    var body: some View {
        NavigationStack {
            Form {
                Section("Watched") { DatePicker("Date", selection: $date, displayedComponents: .date) }
                Section("Your rating") { Picker("Rating", selection: $rating) { Text("No rating").tag(0.0); ForEach([1.0, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5], id: \.self) { Text("\($0.formatted(.number.precision(.fractionLength(0...1)))) stars").tag($0) } } }
            }
            .navigationTitle("Log episode")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }; ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(date, rating == 0 ? nil : rating); dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

private struct EpisodeAdjacentNavigation: View {
    let series: CatalogMedia
    let seasonRoute: SeriesSeasonRoute
    let episode: CatalogEpisode
    let episodes: [CatalogEpisode]
    let watchedCoordinates: Set<String>
    var body: some View {
        let index = episodes.firstIndex(where: { $0.id == episode.id })
        HStack {
            if let previous = index.flatMap({ $0 > 0 ? episodes[$0 - 1] : nil }) { NavigationLink("Previous") { EpisodeExperienceView(series: series, seasonRoute: seasonRoute, episode: previous, episodes: episodes, watched: watchedCoordinates.contains("\(previous.seasonNumber):\(previous.episodeNumber)")) } }
            Spacer()
            if let next = index.flatMap({ $0 + 1 < episodes.count ? episodes[$0 + 1] : nil }) { NavigationLink("Next") { EpisodeExperienceView(series: series, seasonRoute: seasonRoute, episode: next, episodes: episodes, watched: watchedCoordinates.contains("\(next.seasonNumber):\(next.episodeNumber)")) } }
        }
        .font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.accent)
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
}

@MainActor @Observable
private final class SeasonEpisodesViewModel {
    enum State { case idle, loading, loaded([CatalogEpisode]), failed }
    let route: SeriesSeasonRoute
    private let request: @Sendable (SeriesSeasonRoute) async throws -> CatalogSeasonResponse
    private var task: Task<Void, Never>?
    private(set) var state: State = .idle
    var episodes: [CatalogEpisode]? { if case let .loaded(items) = state { items } else { nil } }

    init(route: SeriesSeasonRoute, client: MosaicAPIClient) {
        self.route = route
        request = { route in try await client.publicRequest(path: route.catalogPath, as: CatalogSeasonResponse.self) }
    }

    func load() {
        guard task == nil else { return }
        state = .loading
        task = Task { [weak self, route, request] in
            guard let self else { return }
            defer { self.task = nil }
            if let cached = await SeriesSeasonCache.shared.episodes(for: route) { self.state = .loaded(cached); return }
            do {
                let clock = ContinuousClock(); let start = clock.now
                let response = try await request(route)
                seriesLogger.debug("Season episode request completed in \(String(describing: start.duration(to: clock.now)), privacy: .public)")
                try Task.checkCancellation()
                await SeriesSeasonCache.shared.store(response.episodes, for: route)
                self.state = .loaded(response.episodes)
            } catch is CancellationError { self.state = .idle }
            catch { seriesLogger.error("Season episode request failed"); self.state = .failed }
        }
    }
}

@MainActor @Observable
final class SeriesPersonalStateViewModel {
    private let route: MediaDetailRoute
    private let request: @Sendable (String) async throws -> SeriesPersonalState
    private var task: Task<Void, Never>?
    private(set) var value: SeriesPersonalState?
    private(set) var isLoading = false

    init(media: CatalogMedia, client: MosaicAPIClient) {
        route = media.route
        let encodedProvider = media.provider.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? media.provider
        let encodedID = media.providerID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? media.providerID
        let path = "/api/me/series-state?provider=\(encodedProvider)&providerId=\(encodedID)"
        request = { token in try await client.request(path, token: token, as: SeriesPersonalState.self) }
    }

    func load(using session: SessionStore) async {
        guard task == nil else { return }
        if let cached = await SeriesPersonalStateCache.shared.value(for: route) { value = cached; return }
        isLoading = true
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.task = nil; self.isLoading = false }
            do {
                let clock = ContinuousClock(); let start = clock.now
                let loaded = try await self.request(session.currentAccessToken())
                seriesLogger.debug("Personal Series state completed in \(String(describing: start.duration(to: clock.now)), privacy: .public)")
                try Task.checkCancellation()
                await SeriesPersonalStateCache.shared.store(loaded, for: self.route)
                self.value = loaded
            } catch is CancellationError { } catch { seriesLogger.error("Personal Series state failed") }
        }
    }

    func refresh(using session: SessionStore) async {
        task?.cancel(); task = nil
        await SeriesPersonalStateCache.shared.invalidate(route)
        await load(using: session)
    }
}

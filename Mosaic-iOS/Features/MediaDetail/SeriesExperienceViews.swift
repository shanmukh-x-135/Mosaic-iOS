import Observation
import os
import SwiftUI

private let seriesLogger = Logger(subsystem: "com.shanmukhpgsspersonalteam.MosaiciOS", category: "Series")

struct SeriesHubView: View {
    let media: CatalogMedia
    @Environment(\.mosaicServices) private var services
    @State private var state = SeriesPersonalStateViewModel()

    private var seasons: [Int] {
        let declared = media.seasonNumbers ?? Array(1...max(media.seasonCount ?? 0, 1))
        return media.seasonNumbers == nil && media.seasonCount == nil ? [] : declared.filter { $0 > 0 }.sorted()
    }

    var body: some View {
        MosaicScreen {
            DetailHero(media: media)
            DetailIdentity(media: media)
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                SeriesEpisodeProgress(media: media, state: state)
                PersonalStoryPanel(media: media, showsLogAction: false)
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
            if let description = media.description, !description.isEmpty { DetailAbout(text: description) }
            if !seasons.isEmpty {
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicSectionHeader("Seasons", eyebrow: "Episode guide")
                    ForEach(seasons, id: \.self) { number in
                        NavigationLink {
                            SeasonExperienceView(series: media, seasonNumber: number)
                        } label: {
                            SeasonRow(media: media, seasonNumber: number, personalState: state.value)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, MosaicLayout.pageHorizontal)
                    }
                }
            }
            DetailFacts(facts: [
                DetailFact("Network", media.network),
                DetailFact("Seasons", media.seasonCount.map(String.init)),
                DetailFact("Episodes", (media.eligibleEpisodeCount ?? media.episodeCount).map(String.init)),
                DetailFact("First aired", media.releaseDate ?? media.releaseYear.map(String.init)),
            ])
        }
        .task { await state.load(media.route, services: services) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { _ in Task { await state.refresh(media.route, services: services) } }
    }
}

/// Episode progress and the next-episode action. Totals are the catalog's
/// aired, non-special count; without one, progress is shown as a plain count.
private struct SeriesEpisodeProgress: View {
    let media: CatalogMedia
    let state: SeriesPersonalStateViewModel
    @Environment(\.mosaicServices) private var services
    @State private var presentsLog = false
    @State private var notice: (String, MosaicNotice.Tone)?

    private var watchedCount: Int { state.value?.watchedCoordinates.count ?? 0 }
    private var total: Int? { media.eligibleEpisodeCount ?? media.episodeCount }
    private var next: (season: Int, episode: Int)? { SeriesProgress.nextEpisode(media: media, watched: state.value?.watchedCoordinates ?? []) }

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            if state.value == nil && state.isLoading {
                ProgressView().controlSize(.small)
            } else {
                if let total, total > 0 {
                    Text("\(watchedCount) of \(total) episodes watched").font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText)
                    MosaicProgressBar(fraction: Double(watchedCount) / Double(total), tint: CatalogMediaType.tv.accent)
                } else if watchedCount > 0 {
                    Text("\(watchedCount) episodes watched").font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText)
                }
                Button { presentsLog = true } label: {
                    Label(next.map { "Log \(EpisodeCode.format(season: $0.season, episode: $0.episode))" } ?? "Log an episode", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(CatalogMediaType.tv.accent)
                .foregroundStyle(MosaicColor.onLight)
                .controlSize(.large)
                .accessibilityHint(next == nil ? "Choose a season and episode" : "Opens the log form for the next unwatched episode")
            }
            if let notice { MosaicNotice(text: notice.0, tone: notice.1) }
        }
        .sheet(isPresented: $presentsLog) {
            NavigationStack { MediaLogForm(media: media, onSaved: { notice = ("Episode logged.", .success) }) }
        }
    }
}

private struct SeasonRow: View {
    let media: CatalogMedia
    let seasonNumber: Int
    let personalState: SeriesPersonalState?
    private var count: Int? { (media.eligibleEpisodeCounts ?? media.seasonEpisodeCounts)?[String(seasonNumber)] }
    private var watched: Int { personalState?.episodes.filter { $0.seasonNumber == seasonNumber }.count ?? 0 }
    private var seasonState: String? { personalState?.seasons.first { $0.seasonNumber == seasonNumber }?.state }

    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: MosaicSpace.xSmall) {
                    Text("Season \(seasonNumber)").font(.headline).foregroundStyle(MosaicColor.primaryText)
                    if let seasonState { Text(LibraryStatus.label(for: seasonState)).font(.caption.weight(.semibold)).foregroundStyle(CatalogMediaType.tv.accent) }
                }
                Text(count.map { "\(watched) of \($0) watched" } ?? "\(watched) watched").font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                if let count, count > 0 { MosaicProgressBar(fraction: Double(watched) / Double(count), tint: CatalogMediaType.tv.accent) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.mutedText).accessibilityHidden(true)
        }
        .padding(MosaicSpace.medium)
        .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).strokeBorder(MosaicColor.border) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the episode list")
    }
}

struct SeasonExperienceView: View {
    let series: CatalogMedia
    let seasonNumber: Int
    @Environment(\.mosaicServices) private var services
    @State private var episodes = Loadable<[CatalogEpisode]>.idle
    @State private var personal = SeriesPersonalStateViewModel()
    @State private var isSaving = false
    @State private var savingEpisodeIDs: Set<String> = []
    @State private var notice: (String, MosaicNotice.Tone)?

    private var route: SeriesSeasonRoute { SeriesSeasonRoute(series: series, seasonNumber: seasonNumber) }
    private var seasonStatus: String? { personal.value?.seasons.first { $0.seasonNumber == seasonNumber }?.state }

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicEyebrow(title: series.title, color: CatalogMediaType.tv.accent)
                Text("Season \(seasonNumber)").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText).accessibilityAddTraits(.isHeader)
                if let episodes = episodes.value {
                    let watched = episodes.filter { personal.value?.watched($0) == true }.count
                    Text("\(watched) of \(episodes.count) watched").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    if !episodes.isEmpty { MosaicProgressBar(fraction: Double(watched) / Double(episodes.count), tint: CatalogMediaType.tv.accent) }
                }
                Menu {
                    Picker("Season status", selection: Binding(get: { seasonStatus }, set: { if let status = $0 { save(status) } })) {
                        ForEach(LibraryStatus.statuses(for: .tv), id: \.self) { Text($0.label).tag(Optional($0.rawValue)) }
                    }
                } label: {
                    Label(seasonStatus.map(LibraryStatus.label(for:)) ?? "Set season status", systemImage: "checklist")
                }
                .buttonStyle(.bordered)
                .disabled(isSaving)
                if let notice { MosaicNotice(text: notice.0, tone: notice.1) }
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)

            switch episodes {
            case .idle, .loading:
                ProgressView("Loading episodes").frame(maxWidth: .infinity, minHeight: 180)
            case let .loaded(items) where items.isEmpty:
                MosaicStateMessage(title: "No episodes listed", message: "The catalog has no episodes for this season yet.", systemImage: "tv")
            case let .loaded(items):
                LazyVStack(spacing: MosaicSpace.small) {
                    ForEach(items) { episode in
                        let watched = personal.value?.watched(episode) == true
                        HStack(spacing: MosaicSpace.small) {
                            NavigationLink {
                                EpisodeExperienceView(series: series, seasonRoute: route, episode: episode, episodes: items)
                            } label: {
                                EpisodeRow(episode: episode)
                            }
                            .buttonStyle(.plain)
                            Button { toggle(episode, watched: watched) } label: {
                                Image(systemName: watched ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(watched ? CatalogMediaType.tv.accent : MosaicColor.mutedText)
                                    .frame(width: MosaicLayout.minimumTouchTarget, height: MosaicLayout.minimumTouchTarget)
                            }
                            .buttonStyle(.plain)
                            .disabled(savingEpisodeIDs.contains(episode.id))
                            .accessibilityLabel(watched ? "Mark \(episode.title) unwatched" : "Mark \(episode.title) watched")
                        }
                    }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            case .failed:
                MosaicStateMessage(title: "Episodes are unavailable", message: "Try again in a moment.", systemImage: "exclamationmark.triangle", actionTitle: "Try again") { Task { await loadEpisodes() } }
            }
        }
        .navigationTitle("Season \(seasonNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if case .idle = episodes { await loadEpisodes() }
            await personal.load(series.route, services: services)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { _ in Task { await personal.refresh(series.route, services: services) } }
    }

    private func loadEpisodes() async {
        episodes = .loading
        do { episodes = .loaded(try await services.season(route).episodes) }
        catch { seriesLogger.error("Season episode request failed"); episodes = .failed(error) }
    }

    private func save(_ status: String) {
        guard !isSaving else { return }
        isSaving = true; notice = nil
        Task {
            do { try await services.mutate(.seasonState(series, season: seasonNumber, state: status)); notice = ("Season status saved.", .success) }
            catch { notice = ("Mosaic couldn’t save that change. Try again.", .failure) }
            isSaving = false
        }
    }

    private func toggle(_ episode: CatalogEpisode, watched: Bool) {
        guard !savingEpisodeIDs.contains(episode.id) else { return }
        savingEpisodeIDs.insert(episode.id)
        Task {
            do {
                let mutation: DetailMutation = watched
                    ? .episodeUnwatch(series, season: seasonNumber, episode: episode.episodeNumber)
                    : .episodeLog(series, season: seasonNumber, episode: episode.episodeNumber, watchedAt: .now, rating: nil, episodeTitle: episode.title)
                try await services.mutate(mutation)
            } catch {
                notice = ("Mosaic couldn’t save that change. Try again.", .failure)
            }
            savingEpisodeIDs.remove(episode.id)
        }
    }
}

private struct EpisodeRow: View {
    let episode: CatalogEpisode
    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            MosaicArtwork(url: episode.stillURL, mediaType: .tv)
                .frame(width: 104, height: 104 / MosaicArtworkRatio.still)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(EpisodeCode.format(season: episode.seasonNumber, episode: episode.episodeNumber)).font(.caption.weight(.bold)).foregroundStyle(CatalogMediaType.tv.accent)
                Text(episode.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                Text(EpisodeMetadata.line(for: episode)).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, MosaicSpace.xxSmall)
        .contentShape(Rectangle())
    }
}

enum EpisodeMetadata {
    /// Episode ratings come from TMDB on its 0–10 scale.
    static func line(for episode: CatalogEpisode) -> String {
        [episode.runtimeMinutes.map { "\($0)m" }, episode.airDate, episode.publicRating.flatMap { CommunityRating(raw: $0, provider: "tmdb", count: episode.publicRatingCount) }.map { "★ \($0.formattedValue)" }].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct EpisodeExperienceView: View {
    let series: CatalogMedia
    let seasonRoute: SeriesSeasonRoute
    let episode: CatalogEpisode
    let episodes: [CatalogEpisode]
    @Environment(\.mosaicServices) private var services
    @State private var personal = SeriesPersonalStateViewModel()
    @State private var isSaving = false
    @State private var presentsLog = false
    @State private var notice: (String, MosaicNotice.Tone)?

    private var isWatched: Bool { personal.value?.watched(episode) == true }
    private var watchRecord: SeriesPersonalState.WatchedEpisode? { personal.value?.episodes.first { $0.seasonNumber == episode.seasonNumber && $0.episodeNumber == episode.episodeNumber } }

    var body: some View {
        MosaicScreen {
            MosaicArtwork(url: episode.stillURL, fallbackURL: series.backdropURL ?? series.posterURL, mediaType: .tv)
                .aspectRatio(MosaicArtworkRatio.still, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicEyebrow(title: "\(series.title) · \(EpisodeCode.format(season: episode.seasonNumber, episode: episode.episodeNumber))", color: CatalogMediaType.tv.accent)
                Text(episode.title).font(MosaicType.display).foregroundStyle(MosaicColor.primaryText).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                let line = EpisodeMetadata.line(for: episode)
                if !line.isEmpty { Text(line).font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
            if let overview = episode.overview, !overview.isEmpty { DetailAbout(text: overview) }
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                MosaicSectionHeader("Your episode")
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    Label(isWatched ? watchedText : "Not watched", systemImage: isWatched ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isWatched ? CatalogMediaType.tv.accent : MosaicColor.secondaryText)
                    if isWatched {
                        Button("Mark unwatched", systemImage: "arrow.uturn.backward") { unwatch() }.buttonStyle(.bordered).disabled(isSaving)
                    } else {
                        Button("Log this episode", systemImage: "plus.circle.fill") { presentsLog = true }
                            .buttonStyle(.borderedProminent).tint(CatalogMediaType.tv.accent).foregroundStyle(MosaicColor.onLight).disabled(isSaving || personal.value == nil && personal.isLoading)
                    }
                    if let notice { MosaicNotice(text: notice.0, tone: notice.1) }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
            EpisodeAdjacentNavigation(series: series, seasonRoute: seasonRoute, episode: episode, episodes: episodes)
        }
        .navigationTitle(EpisodeCode.format(season: episode.seasonNumber, episode: episode.episodeNumber))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await personal.load(series.route, services: services) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { _ in Task { await personal.refresh(series.route, services: services) } }
        .sheet(isPresented: $presentsLog) { EpisodeLogSheet { date, rating in log(date: date, rating: rating) } }
    }

    private var watchedText: String {
        guard let record = watchRecord else { return "Watched" }
        let rating = record.rating.map { " · \(UserRating.format($0)) ★" } ?? ""
        return "Watched \(record.watchedAt.formatted(date: .abbreviated, time: .omitted))\(rating)"
    }

    private func log(date: Date, rating: Double?) {
        perform(.episodeLog(series, season: seasonRoute.seasonNumber, episode: episode.episodeNumber, watchedAt: date, rating: rating, episodeTitle: episode.title), success: "Episode logged.")
    }
    private func unwatch() { perform(.episodeUnwatch(series, season: seasonRoute.seasonNumber, episode: episode.episodeNumber), success: "Episode marked unwatched.") }

    private func perform(_ mutation: DetailMutation, success: String) {
        guard !isSaving else { return }
        isSaving = true; notice = nil
        Task {
            do { try await services.mutate(mutation); notice = (success, .success) }
            catch { notice = ("Mosaic couldn’t save that change. Try again.", .failure) }
            isSaving = false
        }
    }
}

private struct EpisodeLogSheet: View {
    let onSave: (Date, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var rating: Double?
    var body: some View {
        NavigationStack {
            Form {
                Section("Watched") { DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date) }
                Section("Your rating") {
                    Picker("Rating", selection: $rating) {
                        Text("No rating").tag(Double?.none)
                        ForEach(UserRating.options.reversed(), id: \.self) { Text("\(UserRating.format($0)) ★").tag(Optional($0)) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MosaicColor.background)
            .navigationTitle("Log episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(date, rating); dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct EpisodeAdjacentNavigation: View {
    let series: CatalogMedia
    let seasonRoute: SeriesSeasonRoute
    let episode: CatalogEpisode
    let episodes: [CatalogEpisode]
    var body: some View {
        let index = episodes.firstIndex { $0.id == episode.id }
        HStack {
            if let previous = index.flatMap({ $0 > 0 ? episodes[$0 - 1] : nil }) {
                NavigationLink { EpisodeExperienceView(series: series, seasonRoute: seasonRoute, episode: previous, episodes: episodes) } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .accessibilityLabel("Previous episode, \(previous.title)")
            }
            Spacer()
            if let next = index.flatMap({ $0 + 1 < episodes.count ? episodes[$0 + 1] : nil }) {
                NavigationLink { EpisodeExperienceView(series: series, seasonRoute: seasonRoute, episode: next, episodes: episodes) } label: {
                    Label("Next", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle())
                }
                .accessibilityLabel("Next episode, \(next.title)")
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(MosaicColor.accent)
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View { HStack(spacing: 4) { configuration.title; configuration.icon } }
}

/// The user's watched episodes and season states for one series. Every
/// season and episode screen reads the same cached value, so ticks agree.
@MainActor @Observable
final class SeriesPersonalStateViewModel {
    private(set) var value: SeriesPersonalState?
    private(set) var isLoading = false
    private var task: Task<Void, Never>?

    func load(_ route: MediaDetailRoute, services: MosaicServices) async {
        if let cached = await SeriesPersonalStateCache.shared.value(for: route) { value = cached; return }
        guard task == nil else { await task?.value; return }
        isLoading = true
        let task = Task {
            do {
                let loaded = try await services.seriesState(route)
                await SeriesPersonalStateCache.shared.store(loaded, for: route)
                value = loaded
            } catch is CancellationError {
            } catch {
                seriesLogger.error("Personal Series state failed")
            }
            isLoading = false
        }
        self.task = task
        await task.value
        self.task = nil
    }

    func refresh(_ route: MediaDetailRoute, services: MosaicServices) async {
        task?.cancel(); task = nil
        await SeriesPersonalStateCache.shared.invalidate(route)
        await load(route, services: services)
    }
}

import Observation
import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(PersonalStateStore.self) private var personal
    @Environment(\.mosaicServices) private var services
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @SceneStorage("mosaic.profileSection") private var section = "Overview"
    @State private var stats = Loadable<ProfileStatsDTO>.idle
    @State private var activity = Loadable<[ProfileActivity]>.idle
    @State private var lists = Loadable<[UserList]>.idle
    @State private var mosaic: MosaicSnapshot?
    @State private var editingProfile = false
    private let sections = ["Overview", "Diary", "Reviews", "Lists", "Stats"]

    var body: some View {
        MosaicScreen {
            ProfileIdentity(profile: session.currentUser?.profile, edit: { editingProfile = true })
            if let error = session.backendError {
                MosaicNotice(text: error, tone: .failure).padding(.horizontal, MosaicLayout.pageHorizontal)
            }
            if let line = ProfileSections.collectionLine(mosaic) {
                Text(line).font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, MosaicLayout.pageHorizontal)
            }
            Picker("Profile sections", selection: $section) {
                ForEach(sections, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, MosaicLayout.pageHorizontal)
            switch section {
            case "Diary": diarySection
            case "Reviews": ProfileReviewsContent(state: personal.state)
            case "Lists": listsSection
            case "Stats":
                statsSection
                profileLink("See all stats", subtitle: "Explore your statistics", symbol: "chart.bar", route: .stats)
            default:
                overviewSection
                favouritesSection
                diarySection
                profileLink("Stats", subtitle: "Explore your statistics", symbol: "chart.bar", route: .stats)
                if MosaicUniverseView.isAvailable {
                    profileLink("Your Mosaic", subtitle: "Explore your stories", symbol: "sparkles", route: .mosaic(nil))
                }
                if RecapView.isAvailable {
                    profileLink("This year's recap", subtitle: "Your year in stories", symbol: "calendar", route: .recap(String(Calendar.current.component(.year, from: Date()))))
                }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editingProfile = true }
                    .accessibilityHint("Change your name, username, bio and photo")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: MosaicRoute.settings) { Label("Settings", systemImage: "gearshape") }
            }
            QuickLogToolbarItem()
        }
        .sheet(isPresented: $editingProfile) { NavigationStack { EditProfileView() } }
        .task { personal.load(services); await load() }
        .refreshable { personal.refresh(services); await load(force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { notification in
            personal.handleStateChange(notification, services: services)
            Task { await load(force: true) }
        }
    }

    private func profileLink(_ title: String, subtitle: String, symbol: String, route: MosaicRoute) -> some View {
        ProfileLink(title: title, subtitle: subtitle, systemImage: symbol, route: route)
            .padding(.horizontal, MosaicLayout.pageHorizontal)
    }

    @ViewBuilder private var overviewSection: some View {
        MosaicSectionHeader("Your story so far")
        switch personal.state {
        case .idle, .loading:
            ProgressView("Loading your history")
        case let .failed(error):
            MosaicStateMessage(title: MosaicErrorCopy.title(for: error, subject: "your history"), message: MosaicErrorCopy.message(for: error), systemImage: "exclamationmark.triangle", actionTitle: "Try again") { personal.refresh(services) }
        case let .loaded(snapshot):
            statGrid {
                ForEach(ProfileSections.metrics(snapshot)) { metric in
                    VStack(alignment: .leading, spacing: MosaicSpace.small) {
                        ProfileStat(value: metric.value.formatted(), label: metric.label, detail: nil, mediaType: metric.type)
                        if !metric.artwork.isEmpty {
                            HStack(spacing: MosaicSpace.xxSmall) {
                                ForEach(metric.artwork) { media in
                                    NavigationLink(value: MosaicRoute.media(media)) {
                                        MosaicArtwork(url: media.posterURL, fallbackURL: media.backdropURL, mediaType: media.mediaType, title: media.title)
                                            .frame(width: 36, height: 54).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small))
                                    }.buttonStyle(.plain).accessibilityLabel(media.title)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var statsSection: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            MosaicSectionHeader("Your story so far", eyebrow: "All time")
            switch stats {
            case .idle, .loading:
                statGrid { ForEach(0..<4, id: \.self) { _ in MosaicSkeleton(aspectRatio: 2).accessibilityHidden(true) } }
            case let .failed(error):
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    MosaicNotice(text: "\(MosaicErrorCopy.title(for: error, subject: "your statistics")). \(MosaicErrorCopy.message(for: error))", tone: .failure)
                    Button("Try again") { Task { await loadStats() } }.font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            case let .loaded(stats):
                statGrid {
                    // Labels name exactly what each server count measures.
                    ProfileStat(value: stats.movie.watches.formatted(), label: "Movie watches", detail: stats.movie.rewatches > 0 ? "\(Plural.count(stats.movie.uniqueMovies, "film")) · \(Plural.count(stats.movie.rewatches, "rewatch", "rewatches"))" : nil, mediaType: .movie)
                    ProfileStat(value: stats.tv.uniqueEpisodesWatched.formatted(), label: "Episodes watched", detail: stats.tv.completedSeasons > 0 ? "\(Plural.count(stats.tv.completedSeasons, "season")) completed" : nil, mediaType: .tv)
                    ProfileStat(value: stats.game.completedPlaythroughs.formatted(), label: "Playthroughs completed", detail: stats.game.playtimeMinutes > 0 ? "\(MosaicDuration.playtime(stats.game.playtimeMinutes)) recorded" : nil, mediaType: .game)
                    ProfileStat(value: stats.book.finished.formatted(), label: "Books finished", detail: nil, mediaType: .book)
                }
            }
        }
    }

    private func statGrid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 320 : 150), spacing: MosaicSpace.small)], spacing: MosaicSpace.small) { content() }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
    }

    @ViewBuilder private var diarySection: some View {
        MosaicSectionHeader("Diary") { NavigationLink("Open full history", value: MosaicRoute.activity) }
        switch activity {
        case let .loaded(items) where !items.isEmpty:
            VStack(spacing: MosaicSpace.medium) {
                ForEach(items.sorted { $0.occurredAt > $1.occurredAt }.prefix(section == "Overview" ? 5 : 20)) { event in
                    NavigationLink(value: MosaicRoute.media(event.media)) { ActivityEventRow(event: event) }.buttonStyle(.plain)
                }
            }.padding(.horizontal, MosaicLayout.pageHorizontal)
        case .loaded:
            MosaicStateMessage(title: "No history yet", message: "Your real activity will appear here after you log it.", systemImage: "clock")
        case .failed:
            MosaicNotice(text: "Recent activity couldn’t be loaded. Pull to refresh.", tone: .failure).padding(.horizontal, MosaicLayout.pageHorizontal)
        case .idle, .loading: ProgressView("Loading your activity")
        }
    }

    @ViewBuilder private var favouritesSection: some View {
        if let snapshot = personal.snapshot {
            ForEach(ProfileSections.favourites(snapshot)) { shelf in
                MosaicSectionHeader(shelf.title)
                MosaicRail {
                    ForEach(shelf.items) { media in
                        NavigationLink(value: MosaicRoute.media(media)) { MosaicPosterCard(summary: MosaicMediaSummary(media), width: 104) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var listsSection: some View {
        MosaicSectionHeader("Your lists") { NavigationLink("Manage lists", value: MosaicRoute.lists) }
        switch lists {
        case let .loaded(items) where !items.isEmpty:
            MosaicRail {
                ForEach(items) { list in
                    NavigationLink(value: MosaicRoute.list(list)) { ListCoverCard(list: list) }.buttonStyle(.plain)
                }
            }
        case .loaded:
            MosaicStateMessage(title: "Make a list that crosses formats", message: "Build one list with movies, series, games, and books.", systemImage: "list.bullet.rectangle")
        case .failed:
            MosaicNotice(text: "Your lists couldn’t be loaded. Pull to refresh.", tone: .failure).padding(.horizontal, MosaicLayout.pageHorizontal)
        case .idle, .loading: ProgressView("Loading your lists")
        }
    }

    private func load(force: Bool = false) async {
        async let s: Void = loadStats(force: force)
        async let a: Void = loadActivity(force: force)
        async let l: Void = loadLists(force: force)
        async let m: Void = loadMosaic()
        _ = await (s, a, l, m)
    }
    private func loadStats(force: Bool = true) async {
        guard force || stats.value == nil else { return }
        if stats.value == nil { stats = .loading }
        do { stats = .loaded(try await services.stats()) } catch is CancellationError {} catch { if stats.value == nil { stats = .failed(error) } }
    }
    private func loadActivity(force: Bool) async {
        guard force || activity.value == nil else { return }
        if activity.value == nil { activity = .loading }
        do { activity = .loaded(try await services.activity(20)) } catch is CancellationError {} catch { if activity.value == nil { activity = .failed(error) } }
    }
    private func loadLists(force: Bool) async {
        guard force || lists.value == nil else { return }
        if lists.value == nil { lists = .loading }
        do { lists = .loaded(try await services.lists()) } catch is CancellationError {} catch { if lists.value == nil { lists = .failed(error) } }
    }
    private func loadMosaic() async {
        do { mosaic = try await services.mosaic("all") } catch { mosaic = nil }
    }
}

private struct ProfileIdentity: View {
    let profile: Profile?
    var edit: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: MosaicSpace.medium) {
            MosaicAvatarView(value: profile?.avatar, name: profile?.displayName).frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                Text(profile?.displayName ?? visibleUsername ?? "Your profile").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText).lineLimit(2).accessibilityAddTraits(.isHeader)
                // Generated `user_…` handles are placeholders, not identities.
                if let visibleUsername { Text("@\(visibleUsername)").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }
                if let bio = profile?.bio, !bio.isEmpty {
                    Text(bio).font(.footnote).foregroundStyle(MosaicColor.secondaryText).lineLimit(3)
                } else {
                    Button("Add a bio", action: edit).font(.footnote)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
    private var visibleUsername: String? { profile?.username.flatMap { $0.hasPrefix("user_") ? nil : $0 } }
}

private struct ProfileStat: View {
    let value: String
    let label: String
    let detail: String?
    let mediaType: CatalogMediaType
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(MosaicColor.primaryText).monospacedDigit()
            HStack(spacing: 5) {
                Circle().fill(mediaType.accent).frame(width: 6, height: 6)
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText)
            }
            if let detail { Text(detail).font(.caption2).foregroundStyle(MosaicColor.mutedText).lineLimit(2) }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(MosaicSpace.medium)
        .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).strokeBorder(MosaicColor.border) }
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileLink: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let route: MosaicRoute
    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: MosaicSpace.medium) {
                Image(systemName: systemImage).font(.body.weight(.semibold)).foregroundStyle(MosaicColor.accent).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(MosaicColor.primaryText)
                    Text(subtitle).font(.caption).foregroundStyle(MosaicColor.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(MosaicColor.mutedText).accessibilityHidden(true)
            }
            .padding(.horizontal, MosaicSpace.medium)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One diary event, labelled with the web's `activityLabel` rules.
struct ActivityEventRow: View {
    let event: ProfileActivity
    var showsDate = true
    var body: some View {
        MosaicMediaRow(summary: MosaicMediaSummary(title: event.media.title, mediaType: event.media.mediaType, posterURL: event.media.posterURL, backdropURL: event.media.backdropURL, subtitle: nil), lines: [summary], thumbnailWidth: 44) {
            if showsDate {
                Text(event.occurredAt.formatted(.dateTime.month(.abbreviated).day())).font(.caption2).foregroundStyle(MosaicColor.mutedText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens details")
    }
    private var summary: String {
        [event.label, event.rating.map { "\(UserRating.format($0)) ★" }, event.detail].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Pure projections shared by Profile, the full reviews route and fixture tests.
nonisolated enum ProfileSections {
    struct Metric: Identifiable {
        let type: CatalogMediaType
        let label: String
        let value: Int
        let artwork: [CatalogMedia]
        var id: CatalogMediaType { type }
    }
    struct FavouriteShelf: Identifiable {
        let type: CatalogMediaType
        let title: String
        let items: [CatalogMedia]
        var id: CatalogMediaType { type }
    }
    private struct EpisodeKey: Hashable {
        let series: String
        let season: Int
        let episode: Int
    }

    static func metrics(_ snapshot: MosaicStateSnapshot) -> [Metric] {
        let episodes = Set(snapshot.episodeWatches.filter { $0.isRewatch != true }.map {
            EpisodeKey(series: $0.series.mediaKey, season: $0.seasonNumber, episode: $0.episodeNumber)
        })
        let games = snapshot.gamePlaythroughs.filter { $0.status == "completed" }
        let books = snapshot.bookReadings.filter { $0.status == "finished" }
        return [
            Metric(type: .movie, label: "Movies watched", value: snapshot.movieWatches.count,
                   artwork: recentArtwork(snapshot.movieWatches.map { ($0.media, $0.watchedAt) })),
            Metric(type: .tv, label: "Unique episodes watched", value: episodes.count,
                   artwork: episodes.isEmpty ? [] : recentArtwork(snapshot.episodeWatches.map { ($0.series, $0.watchedAt) })),
            Metric(type: .game, label: "Games completed", value: games.count,
                   artwork: recentArtwork(games.map { ($0.media, $0.updatedAt) })),
            Metric(type: .book, label: "Books read", value: books.count,
                   artwork: recentArtwork(books.map { ($0.media, $0.updatedAt) }))
        ]
    }

    private static func recentArtwork(_ records: [(media: CatalogMedia, at: String)]) -> [CatalogMedia] {
        var seen = Set<String>()
        return Array(records.sorted { $0.at > $1.at }.compactMap { record in
            seen.insert(record.media.mediaKey).inserted ? record.media : nil
        }.prefix(3))
    }

    static func favourites(_ snapshot: MosaicStateSnapshot) -> [FavouriteShelf] {
        let types: [(CatalogMediaType, String)] = [(.movie, "movies"), (.tv, "series"), (.game, "games"), (.book, "books")]
        return types.compactMap { type, label in
            let items = Array(snapshot.library.filter { $0.isFavorite && $0.media.mediaType == type }.map(\.media).prefix(5))
            return items.isEmpty ? nil : FavouriteShelf(type: type, title: "Favourite \(label)", items: items)
        }
    }

    static func collectionLine(_ snapshot: MosaicSnapshot?) -> String? {
        guard let snapshot, snapshot.totals.storiesRepresented > 0 else { return nil }
        let count = snapshot.totals.storiesRepresented
        var parts = ["\(count.formatted(.number.locale(Locale(identifier: "en_US")))) \(count == 1 ? "story" : "stories") logged"]
        let mix = snapshot.totals.byMediaType
        let media = [mix.movie, mix.series, mix.game, mix.book].filter { $0 > 0 }.count
        if media > 1 { parts.append("across \(media) media") }
        if let earliest = snapshot.tiles.compactMap({ $0.activity.firstActivityAt.flatMap(date) }).min() {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "MMM yyyy"
            parts.append("earliest activity \(formatter.string(from: earliest))")
        }
        return parts.joined(separator: " · ")
    }

    static func reviewExcerpt(_ review: MosaicStateSnapshot.Review) -> String {
        review.containsSpoilers ? "Contains spoilers" : String(review.body.prefix(150))
    }

    static func sortedReviews(_ reviews: [MosaicStateSnapshot.Review]) -> [MosaicStateSnapshot.Review] {
        reviews.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(secondsFromGMT: 0)
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: value)
    }
}

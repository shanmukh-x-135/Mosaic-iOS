import Observation
import SwiftUI

/// Identity first, then honest statistics, recent history, favourites and the
/// user's lists. Every number is a server projection; nothing is inferred.
struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.mosaicServices) private var services
    @Environment(LibraryStore.self) private var library
    @State private var stats = Loadable<ProfileStatsDTO>.idle
    @State private var activity = Loadable<[ProfileActivity]>.idle
    @State private var lists = Loadable<[UserList]>.idle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        MosaicScreen {
            ProfileIdentity(profile: session.currentUser?.profile)
            if let error = session.backendError { MosaicNotice(text: error, tone: .failure).padding(.horizontal, MosaicLayout.pageHorizontal) }
            statsSection
            recentSection
            favouritesSection
            listsSection
            VStack(spacing: 0) {
                ProfileLink(title: "Activity", subtitle: "Your full diary of logs and updates", systemImage: "clock.arrow.circlepath", route: .activity)
                Divider().overlay(MosaicColor.border).padding(.leading, 56)
                ProfileLink(title: "Lists", subtitle: lists.value.map { "\($0.count) \($0.count == 1 ? "list" : "lists")" } ?? "Your collections", systemImage: "list.bullet.rectangle", route: .lists)
                Divider().overlay(MosaicColor.border).padding(.leading, 56)
                ProfileLink(title: "Settings", subtitle: "Account and sign out", systemImage: "gearshape", route: .settings)
            }
            .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: MosaicRadius.card, style: .continuous).strokeBorder(MosaicColor.border) }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
        .navigationTitle("Profile")
        .toolbar { QuickLogToolbarItem() }
        .task { await load() }
        .refreshable { await load(force: true) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { _ in Task { await load(force: true) } }
    }

    // MARK: Sections

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

    @ViewBuilder private var recentSection: some View {
        switch activity {
        case let .loaded(items) where !items.isEmpty:
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Recently logged", eyebrow: "Personal history") { NavigationLink("See all", value: MosaicRoute.activity) }
                VStack(spacing: MosaicSpace.small) {
                    ForEach(items.prefix(5)) { event in
                        NavigationLink(value: MosaicRoute.media(event.media)) { ActivityEventRow(event: event) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
        case .loaded:
            MosaicStateMessage(title: "Start your personal history", message: "Log a movie, episode, game session, or reading update and it will appear here.", systemImage: "person.text.rectangle")
        case .failed:
            MosaicNotice(text: "Recent activity couldn’t be loaded. Pull to refresh.", tone: .failure).padding(.horizontal, MosaicLayout.pageHorizontal)
        case .idle, .loading:
            EmptyView()
        }
    }

    @ViewBuilder private var favouritesSection: some View {
        let favourites = library.items.filter(\.isFavorite)
        if !favourites.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Favourite stories", eyebrow: "Taste profile")
                MosaicRail {
                    ForEach(favourites.prefix(12)) { item in
                        NavigationLink(value: MosaicRoute.media(item)) { MosaicPosterCard(summary: MosaicMediaSummary(item), width: 104, showsMedium: true) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var listsSection: some View {
        if let lists = lists.value, !lists.isEmpty {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Your lists", eyebrow: "Collections") { NavigationLink("See all", value: MosaicRoute.lists) }
                MosaicRail {
                    ForEach(lists.prefix(8)) { list in
                        NavigationLink(value: MosaicRoute.list(list)) { ListCoverCard(list: list) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Loading

    private func load(force: Bool = false) async {
        async let s: Void = loadStats(force: force)
        async let a: Void = loadActivity(force: force)
        async let l: Void = loadLists(force: force)
        _ = await (s, a, l)
    }
    private func loadStats(force: Bool = true) async {
        guard force || stats.value == nil else { return }
        if stats.value == nil { stats = .loading }
        do { stats = .loaded(try await services.stats()) } catch is CancellationError {} catch { if stats.value == nil { stats = .failed(error) } }
    }
    private func loadActivity(force: Bool) async {
        guard force || activity.value == nil else { return }
        if activity.value == nil { activity = .loading }
        do { activity = .loaded(try await services.activity(6)) } catch is CancellationError {} catch { if activity.value == nil { activity = .failed(error) } }
    }
    private func loadLists(force: Bool) async {
        guard force || lists.value == nil else { return }
        do { lists = .loaded(try await services.lists()) } catch is CancellationError {} catch { if lists.value == nil { lists = .failed(error) } }
    }
}

private struct ProfileIdentity: View {
    let profile: Profile?
    var body: some View {
        HStack(alignment: .center, spacing: MosaicSpace.medium) {
            ProfileAvatar(url: profile?.avatarURL).frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                MosaicEyebrow(title: "Your Mosaic")
                Text(profile?.displayName ?? visibleUsername ?? "Your profile").font(MosaicType.title).foregroundStyle(MosaicColor.primaryText).lineLimit(2).accessibilityAddTraits(.isHeader)
                // Generated `user_…` handles are placeholders, not identities.
                if let visibleUsername { Text("@\(visibleUsername)").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }
    private var visibleUsername: String? { profile?.username.flatMap { $0.hasPrefix("user_") ? nil : $0 } }
}

/// Remote avatars, or the web's bundled SVG presets, with a gradient fallback.
/// Preset paths are relative to the web app, so they resolve against the API base.
private struct ProfileAvatar: View {
    let url: URL?
    var body: some View {
        Group {
            if let resolved {
                AsyncImage(url: resolved) { phase in
                    if case let .success(image) = phase { image.resizable().scaledToFill() } else { placeholder }
                }
            } else { placeholder }
        }
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(MosaicColor.highlight) }
        .accessibilityHidden(true)
    }
    private var resolved: URL? {
        guard let url else { return nil }
        if url.scheme == nil { return URL(string: url.relativeString, relativeTo: AppConfiguration.current.apiBaseURL)?.absoluteURL }
        return url.pathExtension.lowercased() == "svg" ? nil : url
    }
    private var placeholder: some View {
        LinearGradient(colors: [MosaicColor.accent, CatalogMediaType.tv.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "person.fill").font(.title2).foregroundStyle(.white.opacity(0.9)))
    }
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

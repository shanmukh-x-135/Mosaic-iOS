import Observation
import SwiftUI

struct ProfileView: View {
    @Bindable var session: SessionStore
    @State private var model: ProfileViewModel

    init(session: SessionStore) {
        self.session = session
        _model = State(initialValue: ProfileViewModel(client: MosaicAPIClient(baseURL: AppConfiguration.current.apiBaseURL), accessToken: { try await session.currentAccessToken() }))
    }

    var body: some View {
        NavigationStack {
            MosaicScreen {
                ProfileIdentity(profile: session.currentUser?.profile)
                if let error = session.backendError { Text(error).font(.footnote).foregroundStyle(MosaicColor.secondaryText) }
                switch model.state {
                case .idle, .loading: ProfileSkeleton()
                case let .loaded(snapshot): ProfileOverview(snapshot: snapshot)
                case .empty: ProfileEmpty()
                case let .error(error): ProfileError(error: error, retry: model.retry)
                }
                Button("Sign Out", role: .destructive) { Task { await session.signOut() } }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(MosaicColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { GlobalSearchLink() } }
            .task { model.load() }
            .refreshable { model.retry() }
        }
    }
}

@MainActor @Observable
final class ProfileViewModel {
    enum State { case idle, loading, loaded(ProfileSnapshot), empty, error(MosaicAPIError) }
    private let client: MosaicAPIClient
    private let accessToken: @MainActor () async throws -> String
    private var task: Task<Void, Never>?
    private(set) var state: State = .idle

    init(client: MosaicAPIClient, accessToken: @escaping @MainActor () async throws -> String) {
        self.client = client; self.accessToken = accessToken
    }

    func load() {
        guard task == nil else { return }
        state = .loading
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.task = nil }
            do {
                let token = try await self.accessToken()
                async let stats: ProfileStatsDTO = self.client.request("/api/me/stats", token: token)
                async let library: LibraryResponseDTO = self.client.request("/api/me/library", token: token)
                async let activity: ProfileActivityResponse = self.client.request("/api/me/activity?limit=6", token: token)
                let snapshot = try await ProfileSnapshot(stats: stats, library: library.items, activity: activity.items)
                self.state = snapshot.library.isEmpty && snapshot.activity.isEmpty ? .empty : .loaded(snapshot)
            } catch is CancellationError { self.state = .idle
            } catch let error as MosaicAPIError { self.state = .error(error)
            } catch { self.state = .error(.network("Unable to load your profile.")) }
        }
    }
    func retry() { load() }
}

struct ProfileSnapshot {
    let stats: ProfileStatsDTO
    let library: [LibraryItemDTO]
    let activity: [ProfileActivity]
}

struct ProfileStatsDTO: Decodable {
    struct MediaMix: Decodable { let movie, tv, game, book: Int }
    struct Movie: Decodable { let watches, rewatches, uniqueMovies: Int }
    struct TV: Decodable { let uniqueEpisodesWatched, episodeWatchLogs, episodeRewatches, completedSeasons, showsInProgress: Int }
    struct Game: Decodable { let completedPlaythroughs, playtimeMinutes: Int }
    struct Book: Decodable { let finished, pagesRead: Int }
    let mediaMix: MediaMix
    let movie: Movie
    let tv: TV
    let game: Game
    let book: Book
}

struct ProfileActivityResponse: Decodable { let items: [ProfileActivity] }
struct ProfileActivity: Decodable, Identifiable {
    let eventID: String
    let media: CatalogMedia
    let occurredAt: Date
    let eventType: String
    let rating: Double?
    let detail: String?
    private enum CodingKeys: String, CodingKey { case eventID = "eventId", media, occurredAt, eventType, rating, detail }
    var id: String { eventID }
    var label: String {
        switch eventType {
        case "movie_watch": "Watched"
        case "episode_watch": "Watched an episode"
        case "tv_watch": "Updated series"
        case "game_update": "Updated playthrough"
        default: "Updated reading"
        }
    }
}

private struct ProfileIdentity: View {
    let profile: Profile?
    var body: some View {
        HStack(alignment: .top, spacing: MosaicSpace.medium) {
            Group {
                if let url = profile?.avatarURL { AsyncImage(url: url) { phase in if case let .success(image) = phase { image.resizable().scaledToFill() } else { placeholder } } }
                else { placeholder }
            }
            .frame(width: 76, height: 76).clipShape(Circle())
            VStack(alignment: .leading, spacing: 5) {
                MosaicEyebrow(title: "Your Mosaic")
                Text(profile?.displayName ?? profile?.username ?? "Your profile").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                if let username = profile?.username, !username.hasPrefix("user_") { Text("@\(username)").font(.subheadline).foregroundStyle(MosaicColor.secondaryText) }
                Text("One identity for everything you watch, play, and read.").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
            }
        }
    }
    private var placeholder: some View { LinearGradient(colors: [MosaicColor.accent, MosaicColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing).overlay(Image(systemName: "person.fill").foregroundStyle(.white)) }
}

private struct ProfileOverview: View {
    let snapshot: ProfileSnapshot
    private var favorites: [LibraryItemDTO] { snapshot.library.filter(\.isFavorite) }
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xLarge) {
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader("Your story so far", eyebrow: "All time")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MosaicSpace.small) {
                    ProfileStat(value: snapshot.stats.movie.watches, label: "Movies watched")
                    ProfileStat(value: snapshot.stats.tv.uniqueEpisodesWatched, label: "Episodes watched")
                    ProfileStat(value: snapshot.stats.game.completedPlaythroughs, label: "Games completed")
                    ProfileStat(value: snapshot.stats.book.finished, label: "Books read")
                }
            }
            if !snapshot.activity.isEmpty {
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    MosaicSectionHeader("Recently logged", eyebrow: "Personal history")
                    ForEach(snapshot.activity) { event in
                        NavigationLink { MediaDetailContainer(route: event.media.route, preview: MediaDetailPreview(media: event.media)) } label: { ProfileActivityRow(event: event) }.buttonStyle(.plain)
                    }
                }
            }
            if !favorites.isEmpty {
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    MosaicSectionHeader("Favourite stories", eyebrow: "Taste profile")
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: MosaicSpace.medium) {
                            ForEach(favorites.prefix(10)) { item in
                                NavigationLink { MediaDetailContainer(route: item.route, preview: MediaDetailPreview(library: item)) } label: {
                                    VStack(alignment: .leading, spacing: 6) { MosaicArtwork(url: item.posterURL, fallbackURL: item.backdropURL, symbol: item.mediaType.symbolName).frame(width: 112, height: 164).clipShape(RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous)); Text(item.title).font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2).frame(width: 112, alignment: .leading) }
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, MosaicSpace.large)
                    }.scrollIndicators(.hidden)
                }
            }
        }
    }
}

private struct ProfileStat: View {
    let value: Int; let label: String
    var body: some View { VStack(alignment: .leading, spacing: 5) { Text(value.formatted()).font(.title2.weight(.bold)).foregroundStyle(MosaicColor.primaryText); Text(label).font(.caption).foregroundStyle(MosaicColor.secondaryText) }.frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).padding(MosaicSpace.medium).background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous)) }
}

private struct ProfileActivityRow: View {
    let event: ProfileActivity
    private var summary: String {
        let rating = event.rating.map { "★ \($0.formatted(.number.precision(.fractionLength(1))))" }
        return [event.label, rating, event.detail].compactMap { $0 }.joined(separator: " · ")
    }
    private var dateLabel: String { event.occurredAt.formatted(.dateTime.month(.abbreviated).day()) }
    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            MosaicArtwork(url: event.media.posterURL, fallbackURL: event.media.backdropURL, symbol: event.media.mediaType.symbolName)
                .frame(width: 52, height: 70).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(event.media.mediaType.displayName.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(MosaicColor.accent)
                Text(event.media.title).font(.headline).foregroundStyle(MosaicColor.primaryText).lineLimit(1)
                Text(summary).font(.caption).foregroundStyle(MosaicColor.secondaryText)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(dateLabel).font(.caption2).foregroundStyle(MosaicColor.mutedText)
        }
    }
}

private struct ProfileSkeleton: View { var body: some View { VStack(alignment: .leading, spacing: MosaicSpace.medium) { MosaicSectionHeader("Your story so far", eyebrow: "All time"); LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MosaicSpace.small) { ForEach(0..<4, id: \.self) { _ in MosaicSkeleton().frame(height: 88) } }; MosaicSkeleton().frame(height: 170) }.redacted(reason: .placeholder) } }
private struct ProfileEmpty: View { var body: some View { ContentUnavailableView("Start your personal history", systemImage: "person.text.rectangle", description: Text("Log a movie, episode, game session, or reading update to see your story here.")) } }
private struct ProfileError: View { let error: MosaicAPIError; let retry: () -> Void; var body: some View { VStack(spacing: MosaicSpace.medium) { ContentUnavailableView("Your profile is unavailable", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription)); Button("Try again", action: retry).buttonStyle(.borderedProminent) } } }

import Observation
import SwiftUI

enum MosaicTab: String, Hashable, CaseIterable { case home, discover, library, profile, search }

/// Values pushed onto a tab's navigation stack.
enum MosaicRoute: Hashable {
    case media(MediaDetailRoute, MediaDetailPreview)
    case lists
    case list(UserList)
    case activity
    case settings

    static func media(_ media: CatalogMedia) -> MosaicRoute { .media(media.route, MediaDetailPreview(media: media)) }
    static func media(_ item: LibraryItemDTO) -> MosaicRoute { .media(item.route, MediaDetailPreview(library: item)) }
    static func media(_ story: ContinueStory) -> MosaicRoute { .media(story.detailRoute, MediaDetailPreview(story: story)) }
}

/// Root navigation state: one selected tab, one path per tab, and the global
/// Quick Log sheet. Selecting the current tab again pops it to its root, the
/// standard iOS behaviour.
@MainActor @Observable
final class MosaicRouter {
    var selectedTab: MosaicTab = .home
    var paths: [MosaicTab: [MosaicRoute]] = [:]
    var isQuickLogPresented = false

    init(selectedTab: MosaicTab = .home, paths: [MosaicTab: [MosaicRoute]] = [:]) {
        self.selectedTab = selectedTab
        self.paths = paths
    }

    func path(for tab: MosaicTab) -> Binding<[MosaicRoute]> {
        Binding { self.paths[tab] ?? [] } set: { self.paths[tab] = $0 }
    }

    func select(_ tab: MosaicTab) {
        if tab == selectedTab { paths[tab] = [] } else { selectedTab = tab }
    }

    func open(_ route: MosaicRoute, in tab: MosaicTab? = nil) {
        let target = tab ?? selectedTab
        selectedTab = target
        paths[target, default: []].append(route)
    }

    func presentQuickLog() { isQuickLogPresented = true }
}

/// The signed-in user's tracked Library, loaded once and shared by Home,
/// Library, Discover and detail screens. It refreshes after any successful
/// mutation and keeps showing the last good result while it does.
@MainActor @Observable
final class LibraryStore {
    private(set) var state: Loadable<[LibraryItemDTO]> = .idle
    private(set) var savingKeys: Set<String> = []
    private var entriesByKey: [String: LibraryItemDTO] = [:]
    private var task: Task<Void, Never>?

    var items: [LibraryItemDTO] { state.value ?? [] }
    var hasLoaded: Bool { state.value != nil }

    func entry(for key: String) -> LibraryItemDTO? { entriesByKey[key] }
    func entry(for media: CatalogMedia) -> LibraryItemDTO? { entriesByKey[media.mediaKey] }
    func isTracked(_ media: CatalogMedia) -> Bool { entriesByKey[media.mediaKey] != nil }

    func load(_ services: MosaicServices, force: Bool = false) {
        guard task == nil, force || state.value == nil else { return }
        if state.value == nil { state = .loading }
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.task = nil }
            do {
                let items = try await services.library()
                self.entriesByKey = Dictionary(items.map { ($0.mediaKey, $0) }, uniquingKeysWith: { first, _ in first })
                self.state = .loaded(items)
            } catch is CancellationError {
                if self.state.value == nil { self.state = .idle }
            } catch {
                // A failed refresh keeps the last good Library instead of blanking it.
                if self.state.value == nil { self.state = .failed(error) }
            }
        }
    }

    func refresh(_ services: MosaicServices) { task?.cancel(); task = nil; load(services, force: true) }

    enum SaveOutcome { case added, alreadyTracked }

    /// Save for later (`addIfUntracked`): skips tracked items locally and asks
    /// the server to keep any existing entry (`onlyIfUntracked`).
    func saveForLater(_ media: CatalogMedia, using services: MosaicServices) async throws -> SaveOutcome {
        if isTracked(media) { return .alreadyTracked }
        savingKeys.insert(media.mediaKey)
        defer { savingKeys.remove(media.mediaKey) }
        try await services.mutate(.saveForLater(media))
        return .added
    }

    /// Fixture and test seeding only.
    func seed(_ items: [LibraryItemDTO]) {
        entriesByKey = Dictionary(items.map { ($0.mediaKey, $0) }, uniquingKeysWith: { first, _ in first })
        state = .loaded(items)
    }
}

/// Shared personal history, loaded lazily and replaced by mutation responses.
@MainActor @Observable
final class PersonalStateStore {
    private(set) var state: Loadable<MosaicStateSnapshot> = .idle
    private var task: Task<Void, Never>?
    private var generation = 0

    var snapshot: MosaicStateSnapshot? { state.value }

    func load(_ services: MosaicServices) {
        guard task == nil, snapshot == nil else { return }
        start(services)
    }

    func refresh(_ services: MosaicServices) {
        cancelLoad()
        start(services)
    }

    private func start(_ services: MosaicServices) {
        if snapshot == nil { state = .loading }
        let generation = generation
        task = Task { [weak self] in
            guard let self else { return }
            defer { if self.generation == generation { self.task = nil } }
            do {
                let snapshot = try await services.stateSnapshot()
                try Task.checkCancellation()
                guard self.generation == generation else { return }
                self.state = .loaded(snapshot)
            } catch {
                guard self.generation == generation else { return }
                if self.snapshot == nil {
                    self.state = error is CancellationError ? .idle : .failed(error)
                }
            }
        }
    }

    private func cancelLoad() {
        generation += 1
        task?.cancel()
        task = nil
    }

    func apply(_ snapshot: MosaicStateSnapshot) {
        cancelLoad()
        state = .loaded(snapshot)
    }

    /// Fixture and test seeding only.
    func seed(_ snapshot: MosaicStateSnapshot) { apply(snapshot) }

    func handleStateChange(_ notification: Notification, services: MosaicServices) {
        if let snapshot = notification.mosaicStateSnapshot { apply(snapshot) }
        else if snapshot != nil { refresh(services) }
    }
}

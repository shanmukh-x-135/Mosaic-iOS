import SwiftUI

/// The signed-in shell. Four content tabs plus the system search tab; Quick
/// Log is a toolbar action on every root screen rather than a fake tab.
struct AppShell: View {
    let services: MosaicServices
    @State private var router: MosaicRouter
    @State private var library = LibraryStore()
    @State private var personalState: PersonalStateStore
    @SceneStorage("mosaic.selectedTab") private var storedTab = MosaicTab.home.rawValue
    /// Only a default shell restores the last tab; an injected router (fixtures) wins.
    private let restoresTab: Bool

    init(services: MosaicServices, router: MosaicRouter? = nil, personalState: PersonalStateStore? = nil) {
        self.services = services
        _router = State(initialValue: router ?? MosaicRouter())
        _personalState = State(initialValue: personalState ?? PersonalStateStore())
        restoresTab = router == nil
    }

    var body: some View {
        TabView(selection: Binding(get: { router.selectedTab }, set: { router.select($0) })) {
            Tab("Home", systemImage: "house", value: MosaicTab.home) { stack(.home) { HomeView() } }
            Tab("Discover", systemImage: "sparkles", value: MosaicTab.discover) { stack(.discover) { DiscoverView() } }
            Tab("Library", systemImage: "books.vertical", value: MosaicTab.library) { stack(.library) { LibraryView() } }
            Tab("Profile", systemImage: "person.crop.circle", value: MosaicTab.profile) { stack(.profile) { ProfileView() } }
            Tab(value: MosaicTab.search, role: .search) { stack(.search) { SearchView() } }
        }
        .sheet(isPresented: $router.isQuickLogPresented) { QuickLogView() }
        .environment(router)
        .environment(library)
        .environment(personalState)
        .environment(\.mosaicServices, services)
        .task { library.load(services) }
        .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { notification in
            library.refresh(services)
            personalState.handleStateChange(notification, services: services)
        }
        .onAppear { if restoresTab, let tab = MosaicTab(rawValue: storedTab) { router.selectedTab = tab } }
        .onChange(of: router.selectedTab) { _, tab in storedTab = tab.rawValue }
    }

    private func stack<Root: View>(_ tab: MosaicTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            root().mosaicDestinations()
        }
    }
}

extension View {
    /// Every pushable screen, registered once per stack.
    func mosaicDestinations() -> some View {
        navigationDestination(for: MosaicRoute.self) { route in
            switch route {
            case let .media(identity, preview): MediaDetailContainer(route: identity, preview: preview)
            case .lists: ListsView()
            case let .list(list): ListDetailView(list: list)
            case .activity: ActivityView()
            case .settings: SettingsView()
            }
        }
    }
}

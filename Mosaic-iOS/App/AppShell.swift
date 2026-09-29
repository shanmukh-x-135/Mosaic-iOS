import SwiftUI

struct AppShell: View {
    @Bindable var session: SessionStore

    var body: some View {
        TabView {
            HomeView(session: session).tabItem { Label("Home", systemImage: "house.fill") }
            DiscoverView().tabItem { Label("Discover", systemImage: "sparkles") }
            LibraryView(session: session).tabItem { Label("Library", systemImage: "books.vertical.fill") }
            SearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }
            ProfileView(session: session).tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

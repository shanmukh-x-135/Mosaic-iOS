import SwiftUI

struct AppShell: View {
    @Bindable var session: SessionStore

    var body: some View {
        TabView {
            PlaceholderTab(title: "Home", symbol: "house.fill", detail: "Your active stories will appear here.").tabItem { Label("Home", systemImage: "house.fill") }
            PlaceholderTab(title: "Discover", symbol: "sparkles", detail: "Discovery is coming in a later milestone.").tabItem { Label("Discover", systemImage: "sparkles") }
            PlaceholderTab(title: "Library", symbol: "books.vertical.fill", detail: "Your library will appear here.").tabItem { Label("Library", systemImage: "books.vertical.fill") }
            PlaceholderTab(title: "Search", symbol: "magnifyingglass", detail: "Search is coming in a later milestone.").tabItem { Label("Search", systemImage: "magnifyingglass") }
            ProfilePlaceholder(session: session).tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

private struct PlaceholderTab: View {
    let title: String; let symbol: String; let detail: String
    var body: some View {
        NavigationStack { ContentUnavailableView(title, systemImage: symbol, description: Text(detail)).navigationTitle(title) }
    }
}

private struct ProfilePlaceholder: View {
    @Bindable var session: SessionStore
    var body: some View {
        NavigationStack {
            VStack(spacing: MosaicSpace.large) {
                Image("AvatarPlaceholder")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .accessibilityLabel("Profile avatar")
                Text(session.currentUser?.profile?.displayName ?? "Signed in").font(MosaicType.title)
                if let backendError = session.backendError {
                    Text(backendError)
                        .font(.footnote)
                        .foregroundStyle(MosaicColor.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Button("Sign Out", role: .destructive) { Task { await session.signOut() } }.buttonStyle(.bordered)
            }.navigationTitle("Profile")
        }
    }
}

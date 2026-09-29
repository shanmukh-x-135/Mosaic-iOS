import SwiftUI

struct AppShell: View {
    @Bindable var session: SessionStore

    var body: some View {
        TabView {
            HomeView(session: session).tabItem { Label("Home", systemImage: "house.fill") }
            LibraryView(session: session).tabItem { Label("Library", systemImage: "books.vertical.fill") }
            SearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }
            AccountView(session: session).tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}

private struct AccountView: View {
    @Bindable var session: SessionStore
    var body: some View {
        NavigationStack {
            VStack(spacing: MosaicSpace.large) {
                Spacer(minLength: MosaicSpace.large)
                Image("AvatarPlaceholder")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
                    .accessibilityLabel("Profile avatar")
                Text(session.currentUser?.profile?.displayName ?? session.currentUser?.profile?.username ?? "Signed in").font(MosaicType.title)
                if let username = session.currentUser?.profile?.username { Text("@\(username)").foregroundStyle(MosaicColor.secondaryText) }
                if let backendError = session.backendError {
                    Text(backendError)
                        .font(.footnote)
                        .foregroundStyle(MosaicColor.secondaryText)
                        .multilineTextAlignment(.center)
                }
                Button("Sign Out", role: .destructive) { Task { await session.signOut() } }.buttonStyle(.bordered)
                Spacer()
            }.padding(MosaicSpace.large).frame(maxWidth: .infinity).background(MosaicColor.background).navigationTitle("Account")
        }
    }
}

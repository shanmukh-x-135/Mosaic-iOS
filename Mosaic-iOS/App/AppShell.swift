import SwiftUI

struct AppShell: View {
    @Bindable var session: SessionStore
    @State private var isLogPresented = false

    var body: some View {
        TabView {
            HomeView(session: session).tabItem { Label("Home", systemImage: "house.fill") }
            DiscoverView().tabItem { Label("Discover", systemImage: "sparkles") }
            LibraryView(session: session).tabItem { Label("Library", systemImage: "books.vertical.fill") }
            ProfileView(session: session).tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .overlay(alignment: .bottom) {
            Button { isLogPresented = true } label: {
                MosaicGlassControl {
                    Label("Log", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MosaicColor.primaryText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log")
            .accessibilityHint("Opens the Log entry screen")
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $isLogPresented) { LogEntryView() }
    }
}

private struct LogEntryView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            MosaicScreen {
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    MosaicEyebrow(title: "Add to your story")
                    Text("Log").font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                    Text("Find a movie, series, game, or book before recording activity. Logging details will follow the selected story.")
                        .foregroundStyle(MosaicColor.secondaryText)
                }
                .padding(.horizontal, MosaicLayout.screenMargin)
                NavigationLink { SearchView() } label: {
                    Label("Search the catalog", systemImage: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(MosaicColor.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, MosaicSpace.medium)
                        .background(MosaicColor.primaryText, in: RoundedRectangle(cornerRadius: MosaicRadius.control, style: .continuous))
                }
                .padding(.horizontal, MosaicLayout.screenMargin)
            }
            .navigationTitle("Log")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done", action: dismiss.callAsFunction) } }
        }
    }
}

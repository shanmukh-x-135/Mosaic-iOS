import SwiftUI

/// Account settings that exist today. Watch region, imports and exports stay
/// on the web until they have mobile contracts.
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var confirmsSignOut = false

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Name", value: session.currentUser?.profile?.displayName ?? "Not set")
                if let username = session.currentUser?.profile?.username, !username.hasPrefix("user_") {
                    LabeledContent("Username", value: "@\(username)")
                }
                LabeledContent("Sign-in", value: "Google")
            }
            .listRowBackground(MosaicColor.elevated)
            Section {
                Text("Watch region, imports, exports and profile editing are available on Mosaic for the web. Changes there appear here automatically.")
                    .font(.footnote).foregroundStyle(MosaicColor.secondaryText)
            } header: { Text("On the web") }
            .listRowBackground(MosaicColor.elevated)
            Section {
                Button("Sign Out", role: .destructive) { confirmsSignOut = true }
            } footer: {
                Text(versionText)
            }
            .listRowBackground(MosaicColor.elevated)
        }
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle("Settings")
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("Sign out of Mosaic?", isPresented: $confirmsSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { Task { await session.signOut() } }
        } message: { Text("Your Mosaic stays saved to your account.") }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Mosaic \(version) (\(build))"
    }
}

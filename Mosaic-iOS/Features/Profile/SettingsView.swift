import SwiftUI

/// Account settings: the profile the app can edit, the watch region Discover
/// uses, and sign-out.
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var confirmsSignOut = false
    @State private var editingProfile = false

    private var profile: Profile? { session.currentUser?.profile }

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Name", value: profile?.displayName ?? "Not set")
                if let username = profile?.username, !username.hasPrefix("user_") {
                    LabeledContent("Username", value: "@\(username)")
                }
                LabeledContent("Sign-in", value: "Google")
                Button("Edit Profile") { editingProfile = true }
                    .accessibilityHint("Change your name, username, bio and photo")
            }
            .listRowBackground(MosaicColor.elevated)

            Section {
                NavigationLink {
                    WatchRegionView()
                } label: {
                    LabeledContent("Watch region", value: WatchRegion.label(for: profile?.watchRegion))
                }
            } header: { Text("Discovery") } footer: {
                Text("Release dates and streaming availability in Discover follow this region.")
            }
            .listRowBackground(MosaicColor.elevated)

            Section {
                Text("Imports and exports are available on Mosaic for the web. Changes there appear here automatically.")
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
        .sheet(isPresented: $editingProfile) { NavigationStack { EditProfileView() } }
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

/// The release regions Mosaic offers, mirrored from the web's region picker and
/// extended with the common TMDB regions. The server accepts any ISO 3166-1
/// alpha-2 code, so search narrows this list rather than restricting it.
nonisolated enum WatchRegion {
    struct Option: Identifiable, Hashable, Sendable {
        let code: String; let name: String
        var id: String { code }
        var label: String { "\(name) (\(code))" }
    }

    static let all: [Option] = [
        Option(code: "US", name: "United States"), Option(code: "IN", name: "India"),
        Option(code: "GB", name: "United Kingdom"), Option(code: "CA", name: "Canada"),
        Option(code: "AU", name: "Australia"), Option(code: "NZ", name: "New Zealand"),
        Option(code: "IE", name: "Ireland"), Option(code: "DE", name: "Germany"),
        Option(code: "FR", name: "France"), Option(code: "ES", name: "Spain"),
        Option(code: "IT", name: "Italy"), Option(code: "NL", name: "Netherlands"),
        Option(code: "SE", name: "Sweden"), Option(code: "NO", name: "Norway"),
        Option(code: "DK", name: "Denmark"), Option(code: "FI", name: "Finland"),
        Option(code: "PT", name: "Portugal"), Option(code: "PL", name: "Poland"),
        Option(code: "CH", name: "Switzerland"), Option(code: "JP", name: "Japan"),
        Option(code: "KR", name: "South Korea"), Option(code: "CN", name: "China"),
        Option(code: "HK", name: "Hong Kong"), Option(code: "TW", name: "Taiwan"),
        Option(code: "SG", name: "Singapore"), Option(code: "AE", name: "United Arab Emirates"),
        Option(code: "ZA", name: "South Africa"), Option(code: "BR", name: "Brazil"),
        Option(code: "MX", name: "Mexico"), Option(code: "AR", name: "Argentina"),
    ]

    static func option(for code: String?) -> Option? { all.first { $0.code == code } }
    static func label(for code: String?) -> String {
        guard let code, !code.isEmpty else { return "Not set" }
        return option(for: code)?.label ?? code
    }
}

/// Searchable region list. Choosing a region PATCHes `settings.watchRegion` and
/// refreshes the signed-in profile so Discover reloads immediately.
struct WatchRegionView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var saving: String?
    @State private var failure: String?

    private var selected: String? { session.currentUser?.profile?.watchRegion }
    private var options: [WatchRegion.Option] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return WatchRegion.all }
        return WatchRegion.all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) || $0.code.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        List {
            Section {
                row(code: nil, label: "Not set", detail: "Mosaic uses the United States by default.")
            } footer: {
                if let failure { Text(failure).foregroundStyle(MosaicColor.danger) }
            }
            Section("Regions") {
                ForEach(options) { option in
                    row(code: option.code, label: option.name, detail: option.code)
                }
            }
        }
        .searchable(text: $query, prompt: "Search regions")
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle("Watch region")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(code: String?, label: String, detail: String?) -> some View {
        Button {
            select(code)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).foregroundStyle(MosaicColor.primaryText)
                    if let detail { Text(detail).font(.caption).foregroundStyle(MosaicColor.secondaryText) }
                }
                Spacer(minLength: 0)
                if saving == (code ?? "") { ProgressView() }
                else if selected == code { Image(systemName: "checkmark").foregroundStyle(MosaicColor.accent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(saving != nil)
    }

    private func select(_ code: String?) {
        guard selected != code else { dismiss(); return }
        saving = code ?? ""
        failure = nil
        Task {
            do {
                try await services.mutate(.watchRegion(code))
                dismiss()
            } catch {
                failure = "Mosaic couldn’t save that region. Check your connection and try again."
            }
            saving = nil
        }
    }
}

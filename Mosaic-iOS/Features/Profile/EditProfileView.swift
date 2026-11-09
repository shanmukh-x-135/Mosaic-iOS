import SwiftUI

/// Edits the four fields `PATCH /api/me/profile` owns: display name, username,
/// bio and avatar. Client validation mirrors the server so the failure appears
/// inline instead of as a generic request error.
struct EditProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Draft()
    @State private var loaded = false
    @State private var isSaving = false
    @State private var failure: String?

    struct Draft: Equatable {
        var displayName = ""
        var username = ""
        var bio = ""
        var avatar = ""
    }

    private var validationMessage: String? { Self.validate(draft) }
    private var canSave: Bool { !isSaving && validationMessage == nil && !draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            Section {
                HStack(spacing: MosaicSpace.medium) {
                    AvatarPreview(value: draft.avatar, initials: initials)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayNamePreview).font(.headline).foregroundStyle(MosaicColor.primaryText)
                        Text("@\(draft.username.isEmpty ? "username" : draft.username)").font(.subheadline).foregroundStyle(MosaicColor.secondaryText)
                    }
                }
                .listRowBackground(MosaicColor.elevated)
            }

            Section {
                TextField("Display name", text: $draft.displayName)
                    .textContentType(.name)
                HStack(spacing: 2) {
                    Text("@").foregroundStyle(MosaicColor.secondaryText)
                    TextField("username", text: $draft.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("Identity")
            } footer: {
                Text("3–30 lowercase letters, numbers or underscores.")
            }
            .listRowBackground(MosaicColor.elevated)

            Section {
                TextField("A short line about you", text: $draft.bio, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Bio")
            } footer: {
                HStack {
                    Text("Up to 500 characters.")
                    Spacer()
                    Text("\(draft.bio.count)/500").monospacedDigit()
                }
            }
            .listRowBackground(MosaicColor.elevated)

            Section {
                TextField("https://… image link", text: $draft.avatar)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                presetGrid
                if !draft.avatar.isEmpty {
                    Button("Remove photo", role: .destructive) { draft.avatar = "" }
                }
            } header: { Text("Photo") } footer: {
                Text("Use a Mosaic avatar or a full https:// image link.")
            }
            .listRowBackground(MosaicColor.elevated)

            if let message = validationMessage ?? failure {
                Section { MosaicNotice(text: message, tone: .failure) }
                    .listRowBackground(MosaicColor.elevated)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save", action: save).disabled(!canSave)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            guard !loaded else { return }
            loaded = true
            let profile = session.currentUser?.profile
            draft = Draft(
                displayName: profile?.displayName ?? "",
                username: profile?.username ?? "",
                bio: profile?.bio ?? "",
                avatar: profile?.avatar ?? ""
            )
        }
    }

    private var presetGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MosaicSpace.small) {
                ForEach(AvatarPreset.all) { preset in
                    Button {
                        draft.avatar = preset.path
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(LinearGradient(colors: [MosaicColor.accent, CatalogMediaType.tv.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                                Text(String(preset.name.prefix(1))).font(.headline).foregroundStyle(.white)
                            }
                            .frame(width: 44, height: 44)
                            .overlay { Circle().strokeBorder(draft.avatar == preset.path ? MosaicColor.accent : MosaicColor.border, lineWidth: 2) }
                            Text(preset.name).font(.caption2).foregroundStyle(MosaicColor.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(preset.name) avatar")
                    .accessibilityAddTraits(draft.avatar == preset.path ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var displayNamePreview: String {
        let trimmed = draft.displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Your name" : trimmed
    }

    private var initials: String {
        let name = draft.displayName.trimmingCharacters(in: .whitespaces)
        return name.first.map { String($0).uppercased() } ?? "M"
    }

    private func save() {
        guard validationMessage == nil else { return }
        isSaving = true
        failure = nil
        let bio = draft.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatar = draft.avatar.trimmingCharacters(in: .whitespaces)
        let update = ProfileUpdateRequest(
            displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            username: draft.username.trimmingCharacters(in: .whitespaces).lowercased(),
            bio: bio.isEmpty ? nil : bio,
            avatar: avatar.isEmpty ? nil : avatar
        )
        Task {
            do {
                _ = try await services.updateProfile(update)
                dismiss()
            } catch let error as MosaicAPIError {
                failure = error.errorDescription ?? "Mosaic couldn’t save your profile. Try again."
            } catch {
                failure = "Mosaic couldn’t save your profile. Try again."
            }
            isSaving = false
        }
    }

    static func validate(_ draft: Draft) -> String? {
        let name = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.count > 80 { return "Display names must be between 1 and 80 characters." }
        let username = draft.username.trimmingCharacters(in: .whitespaces).lowercased()
        if username.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) == nil {
            return "Use a username with 3–30 lowercase letters, numbers, or underscores."
        }
        if draft.bio.count > 500 { return "Bios can be at most 500 characters." }
        let avatar = draft.avatar.trimmingCharacters(in: .whitespaces)
        if !avatar.isEmpty, AvatarPreset.name(for: avatar) == nil {
            // Mirrors `avatarUrlProblem` in the web's src/lib/profile/avatars.ts.
            if avatar.count > 2048 { return "That image link is too long." }
            guard let url = URL(string: avatar), let scheme = url.scheme else { return "Enter a full image link starting with https://." }
            if scheme.lowercased() != "https" { return "Image links must use https://." }
        }
        return nil
    }
}

/// A local preview of the chosen avatar. Bundled web SVGs cannot render in
/// `AsyncImage`, so presets show the same gradient placeholder the profile uses.
private struct AvatarPreview: View {
    let value: String
    let initials: String

    var body: some View {
        Group {
            if value.hasPrefix("https://"), let url = URL(string: value), url.pathExtension.lowercased() != "svg" {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase { image.resizable().scaledToFill() } else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(MosaicColor.highlight) }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [MosaicColor.accent, CatalogMediaType.tv.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initials).font(.title2.weight(.bold)).foregroundStyle(.white)
        }
    }
}

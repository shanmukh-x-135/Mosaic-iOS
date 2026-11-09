import Foundation

nonisolated struct CurrentUser: Decodable, Equatable, Sendable { let id: String; let profile: Profile? }
nonisolated struct Profile: Decodable, Equatable, Sendable {
    let displayName: String?; let username: String?; let avatarURL: URL?
    /// The stored avatar value. Mosaic presets are site-relative paths such as
    /// `/brand/mosaic/avatars/orbit.svg`, so the raw string is kept for editing.
    let avatar: String?
    let bio: String?
    let watchRegion: String?

    init(displayName: String? = nil, username: String? = nil, avatarURL: URL? = nil, avatar: String? = nil, bio: String? = nil, watchRegion: String? = nil) {
        self.displayName = displayName; self.username = username; self.avatarURL = avatarURL
        self.avatar = avatar; self.bio = bio; self.watchRegion = watchRegion
    }

    private enum CodingKeys: String, CodingKey { case displayName, username, avatarURL = "avatarUrl", bio, watchRegion }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        avatar = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        avatarURL = avatar.flatMap { URL(string: $0) }
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        watchRegion = try container.decodeIfPresent(String.self, forKey: .watchRegion)
    }
}

/// The editable subset of a profile. `PATCH /api/me/profile` replaces all four
/// fields, so omitted optional values are sent as explicit `null` to clear them.
nonisolated struct ProfileUpdateRequest: Encodable, Equatable {
    let displayName: String
    let username: String
    let bio: String?
    let avatar: String?

    private enum CodingKeys: String, CodingKey { case displayName, username, bio, avatarURL = "avatarUrl" }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(username, forKey: .username)
        try container.encode(bio, forKey: .bio)
        try container.encode(avatar, forKey: .avatarURL)
    }
}

nonisolated struct ProfileUpdateResponse: Decodable, Sendable { let profile: Profile }

/// Mosaic's avatar presets, mirrored from `src/lib/profile/avatars.ts`.
nonisolated enum AvatarPreset {
    struct Option: Identifiable, Hashable, Sendable {
        let id: String; let name: String
        var path: String { "/brand/mosaic/avatars/\(id).svg" }
    }
    static let all: [Option] = [
        Option(id: "orbit", name: "Orbit"), Option(id: "prism", name: "Prism"),
        Option(id: "eclipse", name: "Eclipse"), Option(id: "nebula", name: "Nebula"),
        Option(id: "portal", name: "Portal"), Option(id: "aurora", name: "Aurora"),
        Option(id: "monolith", name: "Monolith"), Option(id: "mosaic", name: "Mosaic"),
    ]
    static func name(for path: String?) -> String? { all.first { $0.path == path }?.name }
}

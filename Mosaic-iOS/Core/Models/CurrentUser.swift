import Foundation

struct CurrentUser: Decodable, Equatable, Sendable { let id: String; let profile: Profile? }
struct Profile: Decodable, Equatable, Sendable {
    let displayName: String?; let username: String?; let avatarURL: URL?
    enum CodingKeys: String, CodingKey { case displayName = "display_name"; case username; case avatarURL = "avatar_url" }
}

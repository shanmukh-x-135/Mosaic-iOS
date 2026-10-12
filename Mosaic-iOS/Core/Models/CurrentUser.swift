import Foundation

nonisolated struct CurrentUser: Decodable, Equatable, Sendable { let id: String; let profile: Profile? }
nonisolated struct Profile: Decodable, Equatable, Sendable {
    let displayName: String?; let username: String?; let avatarURL: URL?
}

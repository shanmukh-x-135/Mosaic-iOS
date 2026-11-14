import Foundation

nonisolated enum WatchProviderKind: String, Codable, Sendable { case flatrate, free, ads, rent, buy }

nonisolated struct WatchProvider: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let logoURL: URL?
    let kind: WatchProviderKind
    private enum CodingKeys: String, CodingKey { case id, name, kind; case logoURL = "logoUrl" }
}

nonisolated struct WatchAvailability: Decodable, Sendable {
    let country: String
    let link: URL?
    let providers: [WatchProvider]
}

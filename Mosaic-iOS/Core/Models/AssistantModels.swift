import Foundation

nonisolated struct AssistantRequest: Encodable, Sendable {
    struct Turn: Encodable, Sendable {
        enum Role: String, Encodable, Sendable { case user, assistant }
        let role: Role
        let text: String
    }
    let message: String
    var history: [Turn] = []
    var about: String? = nil
    private enum CodingKeys: String, CodingKey { case message, history, about }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        if !history.isEmpty { try container.encode(history, forKey: .history) }
        if let about, !about.isEmpty { try container.encode(about, forKey: .about) }
    }
}

nonisolated struct AssistantRefMedia: Decodable, Sendable {
    let provider: String
    let mediaType: CatalogMediaType
    let providerID: String
    let title: String
    let posterURL: URL?
    let releaseYear: Int?
    private enum CodingKeys: String, CodingKey {
        case provider, mediaType, title, releaseYear
        case providerID = "providerId", posterURL = "posterUrl"
    }
    var route: MediaDetailRoute { .init(provider: provider, mediaType: mediaType, providerID: providerID) }
}
nonisolated struct AssistantRef: Decodable, Identifiable, Sendable {
    enum Origin: String, Decodable, Sendable { case yourMosaic = "your_mosaic", catalog }
    struct Facts: Decodable, Sendable {
        let status: String?
        let userRating: Double?
        let isFavorite: Bool?
        private enum CodingKeys: String, CodingKey { case status, userRating, isFavorite }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try? container.decode(String.self, forKey: .status)
            userRating = try? container.decode(Double.self, forKey: .userRating)
            isFavorite = try? container.decode(Bool.self, forKey: .isFavorite)
        }
    }
    let id: String
    let origin: Origin
    let media: AssistantRefMedia
    let facts: Facts?
    let reason, seed: String?
}

nonisolated enum AssistantEvent: Decodable, Sendable {
    struct ScopeItem: Decodable, Sendable { let tool, summary: String }
    struct Usage: Decodable, Sendable { let inputTokens, outputTokens, modelCalls, toolCalls: Int }
    case status(tool: String, label: String)
    case text(delta: String)
    case refs([AssistantRef])
    case scope([ScopeItem])
    case done(truncated: Bool, cited: [String], usage: Usage?)
    case error(code: String, message: String, retryable: Bool)
    case unknown

    private enum CodingKeys: String, CodingKey { case type, tool, label, delta, refs, items, truncated, cited, usage, code, message, retryable }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "status": self = .status(tool: try container.decode(String.self, forKey: .tool), label: try container.decode(String.self, forKey: .label))
        case "text": self = .text(delta: try container.decode(String.self, forKey: .delta))
        case "refs": self = .refs(try container.decode([AssistantRef].self, forKey: .refs))
        case "scope": self = .scope(try container.decode([ScopeItem].self, forKey: .items))
        case "done": self = .done(truncated: try container.decode(Bool.self, forKey: .truncated), cited: try container.decode([String].self, forKey: .cited), usage: try container.decodeIfPresent(Usage.self, forKey: .usage))
        case "error": self = .error(code: try container.decode(String.self, forKey: .code), message: try container.decode(String.self, forKey: .message), retryable: try container.decode(Bool.self, forKey: .retryable))
        default: self = .unknown
        }
    }
}

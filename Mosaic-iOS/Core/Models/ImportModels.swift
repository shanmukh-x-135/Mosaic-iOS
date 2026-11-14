import Foundation

nonisolated enum ImportSource: String, Codable, CaseIterable, Sendable {
    case letterboxd, backloggd, serializd, fable
    case serializdNormalizedV1 = "serializd_normalized_v1"
    case genericMovies = "generic_movies", genericSeries = "generic_series", genericGames = "generic_games", genericBooks = "generic_books"

    static let sources: [ImportSourceDescription] = [
        .init(value: .letterboxd, label: "Letterboxd", detail: "Official account export (.zip)", native: true),
        .init(value: .genericMovies, label: "Movies CSV", detail: "Mosaic movie template", native: false),
        .init(value: .serializdNormalizedV1, label: "Serializd JSON", detail: "Recommended: prepared normalized export v1", native: false),
        .init(value: .serializd, label: "Serializd CSV", detail: "Legacy / limited: Mosaic series template", native: false),
        .init(value: .backloggd, label: "Backloggd", detail: "Use Mosaic's games CSV template", native: false),
        .init(value: .fable, label: "Fable", detail: "Use Mosaic's books CSV template", native: false),
    ]
    static func templateURL(for type: CatalogMediaType, baseURL: URL) -> URL {
        let name: String = switch type { case .movie: "movies"; case .tv: "series"; case .game: "games"; case .book: "books" }
        return baseURL.appendingPathComponent("templates").appendingPathComponent("\(name).csv")
    }
}
nonisolated struct ImportSourceDescription: Sendable { let value: ImportSource; let label, detail: String; let native: Bool }
nonisolated enum ImportConflictPolicy: String, Codable, Sendable { case keepMosaic = "keep_mosaic", useImported = "use_imported", review }
nonisolated enum MatchConfidence: String, Codable, Sendable { case exact, high, medium, ambiguous, unmatched }
nonisolated enum ReconciliationDecision: String, Codable, Sendable { case accepted, review, skipped }
nonisolated struct ImportRowError: Codable, Sendable { let row: Int; let field: String?; let message: String }

nonisolated struct ProviderIdentity: Codable, Equatable, Sendable {
    let provider: String
    let mediaType: CatalogMediaType
    let providerID: String
    private enum CodingKeys: String, CodingKey { case provider, mediaType; case providerID = "providerId" }
    var route: MediaDetailRoute { .init(provider: provider, mediaType: mediaType, providerID: providerID) }
}
nonisolated struct ImportListContext: Codable, Sendable {
    let sourceListKey, title: String
    let description: String?
    let position: Int
    let note: String?
}

/// A single record covers all four media kinds. Import payloads use JSONDecoder()
/// so source-owned metadata keys and normalized summary keys remain verbatim.
nonisolated struct NormalizedImportRecord: Codable, Sendable {
    let source: ImportSource
    let sourceRecordKey: String
    let mediaType: CatalogMediaType
    let title: String
    var originalTitle: String?
    var year: Int?
    var rating: Double?
    var review: String?
    var providerIdentity: ProviderIdentity?
    let sourceMetadata: [String: String]
    var recordKind: String?
    var status: String?
    var watchedDate: String?
    var isRewatch: Bool?
    var tags: [String]?
    var list: ImportListContext?
    var targetType: String?
    var tmdbSeasonId: Int?
    var seasonState: String?
    var stateFacts: [String: Bool?]?
    var isFavorite: Bool?
    var defaultImport: Bool?
    var isLog: Bool?
    var containsSpoilers: Bool?
    var sourceCreatedAt: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var episodeTitle: String?
    var episodeProviderId: String?
    var platform: String?
    var startedAt: String?
    var completedAt: String?
    var playtimeMinutes: Int?
    var progressPercent: Double?
    var author: String?
    var finishedAt: String?
    var currentPage: Int?
    var totalPages: Int?
}
nonisolated struct MatchCandidate: Codable, Sendable { let media: CatalogMedia; let score: Double; let reasons: [String] }
nonisolated struct MatchResult: Codable, Sendable { let confidence: MatchConfidence; let resolved: CatalogMedia?; let candidates: [MatchCandidate] }
nonisolated struct ReconciliationRow: Codable, Sendable {
    let record: NormalizedImportRecord
    let match: MatchResult
    var decision: ReconciliationDecision
    var selected: CatalogMedia?
}
nonisolated struct ImportPreviewCounts: Codable, Sendable {
    let total, automaticMatches, needsReview, unmatched, libraryEntries, ratings, reviews: Int
    let movieWatches, episodeWatches, gamePlaythroughs, bookReadings, lists, duplicates, invalid, skipped: Int
}
nonisolated struct ImportPreview: Codable, Sendable {
    let jobId: String?
    let source: ImportSource
    let filename: String
    var rows: [ReconciliationRow]
    let counts: ImportPreviewCounts
    let errors: [ImportRowError]
    let warnings: [String]
    let normalizedSummary: [String: Int]?
}
nonisolated enum ImportHistoryStatus: String, Codable, Sendable {
    case uploaded, ready, importing, completed, failed, undone
    case needsReview = "needs_review", partiallyUndone = "partially_undone"
}
nonisolated struct ImportHistoryItem: Decodable, Identifiable, Sendable {
    let id: String
    let source: ImportSource
    let filename: String
    let status: ImportHistoryStatus
    let totalRecords, importedRecords, skippedRecords, failedRecords: Int
    let createdAt: String
    let completedAt, errorSummary: String?
}
nonisolated struct ImportHistoryResponse: Decodable, Sendable { let jobs: [ImportHistoryItem] }
nonisolated struct ImportUndoResult: Decodable, Sendable { let removed, preserved, missing: Int }
nonisolated struct ImportApplyRequest: Encodable, Sendable {
    struct Resolution: Encodable, Sendable {
        let sourceRecordKey: String
        let decision: ReconciliationDecision
        var selected: CatalogMedia? = nil
    }
    let conflictPolicy: ImportConflictPolicy
    var importFavorites: Bool = true
    let resolutions: [Resolution]
}
nonisolated struct ImportApplyResult: Decodable, Sendable {
    let imported, skipped, conflicts: Int
    let wasReimport: Bool
    let failed: Int
}

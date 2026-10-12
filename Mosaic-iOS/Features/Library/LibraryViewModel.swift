import Foundation
import Observation

/// Library filtering is local over the complete, unpaginated `/api/me/library`
/// collection (documented as safe to filter client-side). Statuses come from
/// the shared per-medium list, so a filter can never offer a status that does
/// not apply.
@MainActor @Observable
final class LibraryViewModel {
    var mediaFilter: LibraryMediaFilter = .all { didSet { if mediaFilter != oldValue { statusFilter = nil } } }
    var statusFilter: LibraryStatus?
    var query = ""
    var sort: LibrarySort = .updated

    var isFiltered: Bool { mediaFilter != .all || statusFilter != nil || !normalizedQuery.isEmpty }
    var normalizedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var availableStatuses: [LibraryStatus] { mediaFilter.mediaType.map(LibraryStatus.statuses(for:)) ?? [] }

    func count(of filter: LibraryMediaFilter, in items: [LibraryItemDTO]) -> Int {
        filter.mediaType.map { type in items.filter { $0.mediaType == type }.count } ?? items.count
    }

    func count(of status: LibraryStatus, in items: [LibraryItemDTO]) -> Int {
        items.filter { $0.mediaType == mediaFilter.mediaType && $0.status == status.rawValue }.count
    }

    func visibleItems(from items: [LibraryItemDTO]) -> [LibraryItemDTO] {
        var filtered = mediaFilter.mediaType.map { type in items.filter { $0.mediaType == type } } ?? items
        if let statusFilter { filtered = filtered.filter { $0.status == statusFilter.rawValue } }
        if !normalizedQuery.isEmpty { filtered = filtered.filter { $0.title.localizedStandardContains(normalizedQuery) } }
        switch sort {
        case .updated: return filtered.sorted { ($0.updatedAt, $1.id) > ($1.updatedAt, $0.id) }
        case .title: return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        // Unrated and unknown years sort last, matching the server's `rating` and `release` sorts.
        case .rating: return filtered.sorted { ($0.userRating ?? -1) > ($1.userRating ?? -1) }
        case .release: return filtered.sorted { ($0.releaseYear ?? Int.min) > ($1.releaseYear ?? Int.min) }
        }
    }

    /// "Movies · Watched", "Everything".
    var collectionTitle: String {
        [mediaFilter == .all ? "Everything" : mediaFilter.title, statusFilter?.label].compactMap { $0 }.joined(separator: " · ")
    }

    /// "42 tracked · 12 movies · 8 series · 3 games · 1 book".
    static func summary(of items: [LibraryItemDTO]) -> String? {
        guard !items.isEmpty else { return nil }
        let parts = DiscoverRails.order.compactMap { type -> String? in
            let count = items.filter { $0.mediaType == type }.count
            guard count > 0 else { return nil }
            let noun = switch type { case .movie: count == 1 ? "movie" : "movies"; case .tv: "series"; case .game: count == 1 ? "game" : "games"; case .book: count == 1 ? "book" : "books" }
            return "\(count) \(noun)"
        }
        return (["\(items.count) tracked"] + parts).joined(separator: " · ")
    }

    func clearFilters() { mediaFilter = .all; statusFilter = nil; query = "" }
}

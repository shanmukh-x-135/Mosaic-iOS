import XCTest
@testable import Mosaic_iOS

@MainActor
final class RelatedTitlesTests: XCTestCase {
    func testHeadingsMatchEachMedium() throws {
        XCTAssertEqual(RelatedTitlesSection.heading(for: try media(.movie)), "Related stories")
        XCTAssertEqual(RelatedTitlesSection.heading(for: try media(.tv)), "Related stories")
        XCTAssertEqual(RelatedTitlesSection.heading(for: try media(.game)), "Similar games")
        XCTAssertEqual(RelatedTitlesSection.heading(for: try media(.book, authors: ["Ursula K. Le Guin", "Another author"])), "More by Ursula K. Le Guin")
        XCTAssertEqual(RelatedTitlesSection.heading(for: try media(.book, authors: [])), "Related books")
        XCTAssertEqual(RelatedTitlesSection.heading(for: try media(.book)), "Related books")
    }

    func testFirstFailureMessageWinsOverFallbackForEveryMedium() throws {
        let failures = [CatalogFailure(provider: "catalog", message: "Provider is unavailable."),
                        CatalogFailure(provider: "other", message: "Another failure.")]
        for type in [CatalogMediaType.movie, .tv, .game, .book] {
            XCTAssertEqual(RelatedTitlesSection.emptyMessage(for: try media(type), failures: failures), "Provider is unavailable.")
        }
        XCTAssertEqual(RelatedTitlesSection.emptyMessage(for: try media(.book), failures: [CatalogFailure(provider: "catalog", message: "")]), "")
    }

    func testEmptyFallbackDistinguishesBooksFromOtherMedia() throws {
        XCTAssertEqual(RelatedTitlesSection.emptyMessage(for: try media(.book), failures: []), "No related books are available from this provider right now.")
        for type in [CatalogMediaType.movie, .tv, .game] {
            XCTAssertEqual(RelatedTitlesSection.emptyMessage(for: try media(type), failures: []), "No related titles are available from this provider right now.")
        }
    }

    func testFilteringExcludesOnlyTheSameProviderQualifiedTitle() throws {
        let current = try media(.movie)
        let updatedSnapshot = try media(.movie, title: "Updated title")
        let otherTitle = try media(.movie, id: "2")
        let otherProvider = try media(.movie, provider: "other")
        let otherMedium = try media(.tv)
        XCTAssertEqual(RelatedTitlesSection.filteredItems([current, otherTitle, updatedSnapshot, otherProvider, otherMedium], excluding: current),
                       [otherTitle, otherProvider, otherMedium])
        XCTAssertTrue(RelatedTitlesSection.filteredItems([current], excluding: current).isEmpty)
    }

    private func media(_ type: CatalogMediaType, provider: String = "catalog", id: String = "1", title: String = "Title", authors: [String]? = nil) throws -> CatalogMedia {
        var json: [String: Any] = ["provider": provider, "providerId": id, "mediaType": type.rawValue, "title": title, "genres": []]
        if let authors { json["authors"] = authors }
        return try JSONDecoder().decode(CatalogMedia.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

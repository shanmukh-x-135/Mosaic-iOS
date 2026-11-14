import XCTest
@testable import Mosaic_iOS

@MainActor
final class FranchiseCreditsTests: XCTestCase {
    func testFranchiseLinkOnlyMatchesProviderQualifiedMembers() throws {
        let dune = try media(.init(provider: "tmdb", mediaType: .movie, providerID: "438631"))
        XCTAssertTrue(FranchiseLink.isAvailable)
        XCTAssertEqual(FranchiseLink(media: dune).franchise?.slug, "dune")
        let nonMember = try media(.init(provider: "tmdb", mediaType: .movie, providerID: "999999"))
        XCTAssertNil(FranchiseLink(media: nonMember).franchise)
        let otherProvider = try media(.init(provider: "igdb", mediaType: .movie, providerID: "438631"))
        XCTAssertNil(FranchiseLink(media: otherProvider).franchise)
    }

    func testGroupingPreservesWebAndCuratedOrderWhileSkippingFailure() throws {
        let identities: [ProviderIdentity] = [
            .init(provider: "mock", mediaType: .book, providerID: "book"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "second-release"),
            .init(provider: "igdb", mediaType: .game, providerID: "game"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "failed"),
            .init(provider: "tmdb", mediaType: .tv, providerID: "series"),
            .init(provider: "tmdb", mediaType: .movie, providerID: "first-release"),
        ]
        let results = try identities.map { identity in
            (identity: identity, media: identity.providerID == "failed" ? nil : try media(identity))
        }
        let groups = FranchiseView.groupedItems(results)
        XCTAssertTrue(FranchiseView.isAvailable)
        XCTAssertEqual(groups.map(\.title), ["Movies", "Series", "Games", "Books"])
        XCTAssertEqual(groups.map { $0.items.map(\.providerID) }, [["second-release", "first-release"], ["series"], ["game"], ["book"]])
        XCTAssertTrue(FranchiseView.groupedItems(identities.map { ($0, nil) }).isEmpty)
        XCTAssertTrue(FranchiseView.groupedItems([]).isEmpty)
    }

    func testCreditsMatchWebCopyAndLinks() {
        XCTAssertTrue(CreditsView.isAvailable)
        XCTAssertEqual(CreditsView.intro, "Mosaic combines provider metadata with the ratings, reviews, lists, and progress you create. Provider data remains attributed to its source.")
        XCTAssertEqual(CreditsView.credits.map(\.title), ["Movies and series", "Watch availability", "Video games", "Books"])
        XCTAssertEqual(CreditsView.credits.map(\.copy), [
            "This product uses the TMDB API but is not endorsed or certified by TMDB.",
            "Movie and series availability is supplied through TMDB watch-provider data, powered by JustWatch. Availability varies by selected region.",
            "Game metadata, platforms, covers, and artwork are provided by IGDB.com.",
            "Book metadata and cover images are supplied through the Google Books API Family.",
        ])
        XCTAssertEqual(CreditsView.credits.map { $0.url.absoluteString }, ["https://www.themoviedb.org", "https://www.justwatch.com", "https://www.igdb.com", "https://books.google.com"])
        XCTAssertEqual(CreditsView.footer, "Provider names and marks belong to their respective owners. Their appearance identifies data sources and does not imply sponsorship or endorsement of Mosaic.")
    }

    private func media(_ identity: ProviderIdentity) throws -> CatalogMedia {
        let data = try JSONSerialization.data(withJSONObject: [
            "provider": identity.provider, "mediaType": identity.mediaType.rawValue,
            "providerId": identity.providerID, "title": identity.providerID, "genres": [],
        ])
        return try JSONDecoder().decode(CatalogMedia.self, from: data)
    }
}

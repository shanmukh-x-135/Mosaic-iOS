import XCTest
@testable import Mosaic_iOS

final class DetailBrandTests: XCTestCase {
    func testPlatformsAreTrimmedAndDeduplicatedPreservingFirstSpellingAndOrder() {
        XCTAssertEqual(GameCredits.normalizedPlatforms(["PC", "pc ", " ", "PlayStation 5"]), ["PC", "PlayStation 5"])
        XCTAssertEqual(GameCredits.normalizedPlatforms([" PC ", "Pc", "\n", " Xbox ", "xbox"]), ["PC", "Xbox"])
        XCTAssertTrue(GameCredits.normalizedPlatforms([]).isEmpty)
    }

    func testMovieBrandUsesStudioAndItsLogo() throws {
        let brand = try XCTUnwrap(DetailBrand(media: media(.movie)))
        XCTAssertEqual(brand.name, "Studio name")
        XCTAssertEqual(brand.accessibilityLabel, "Studio: Studio name")
        XCTAssertEqual(brand.logoURL?.absoluteString, "https://example.com/studio.png")
    }

    func testSeriesBrandUsesNetworkAndItsLogo() throws {
        let brand = try XCTUnwrap(DetailBrand(media: media(.tv)))
        XCTAssertEqual(brand.name, "Network name")
        XCTAssertEqual(brand.accessibilityLabel, "Network: Network name")
        XCTAssertEqual(brand.logoURL?.absoluteString, "https://example.com/network.png")
    }

    func testBrandRequiresNameAndOnlySupportsMoviesAndSeries() throws {
        XCTAssertNil(DetailBrand(media: try media(.game)))
        XCTAssertNil(DetailBrand(media: try media(.book)))
        XCTAssertNil(DetailBrand(media: try media(.movie, overrides: ["studio": NSNull()])))
        XCTAssertNil(DetailBrand(media: try media(.tv, overrides: ["network": " \n "])))
        let brand = try XCTUnwrap(DetailBrand(media: media(.movie, overrides: ["studioLogoUrl": NSNull()])))
        XCTAssertEqual(brand.name, "Studio name")
        XCTAssertNil(brand.logoURL)
    }

    func testGameSectionIsHiddenWithoutPlatformsOrCompanies() throws {
        XCTAssertFalse(GameCredits(media: try media(.game)).isVisible)
        XCTAssertFalse(GameCredits(media: try media(.game, overrides: ["platforms": [" "], "developer": "\n", "publisher": " "])).isVisible)
        XCTAssertTrue(GameCredits(media: try media(.game, overrides: ["platforms": ["PC"]])).isVisible)
        XCTAssertTrue(GameCredits(media: try media(.game, overrides: ["developer": "Developer"])).isVisible)
        XCTAssertTrue(GameCredits(media: try media(.game, overrides: ["publisher": "Publisher"])).isVisible)
    }

    func testCompanyRowsUseWebLabelsAndOmitBlankNames() throws {
        let credits = GameCredits(media: try media(.game, overrides: ["developer": " Dev ", "publisher": "Pub"]))
        XCTAssertEqual(credits.companies.map(\.label), ["Developed by", "Published by"])
        XCTAssertEqual(credits.companies.compactMap(\.value), ["Dev", "Pub"])
    }

    func testGameFactsKeepReleaseWithoutRepeatingCreditsOrPlatforms() throws {
        let game = try media(.game, overrides: ["platforms": ["PC"], "developer": "Dev", "publisher": "Pub"])
        let facts = DetailMetadata.facts(for: game)
        XCTAssertEqual(facts.map(\.label), ["Released"])
        XCTAssertEqual(facts.first?.value, "2026-10-01")
    }

    func testMovieFactsDoNotRepeatStudioBrand() throws {
        XCTAssertFalse(DetailMetadata.facts(for: try media(.movie)).contains { $0.label == "Studio" })
    }

    private func media(_ type: CatalogMediaType, overrides: [String: Any] = [:]) throws -> CatalogMedia {
        var json: [String: Any] = [
            "provider": "mock", "providerId": "1", "mediaType": type.rawValue,
            "title": "Title", "genres": [], "releaseDate": "2026-10-01",
            "studio": "Studio name", "studioLogoUrl": "https://example.com/studio.png",
            "network": "Network name", "networkLogoUrl": "https://example.com/network.png"
        ]
        json.merge(overrides) { _, new in new }
        return try JSONDecoder().decode(CatalogMedia.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

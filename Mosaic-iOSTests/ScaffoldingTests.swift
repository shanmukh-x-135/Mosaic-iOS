import XCTest
@testable import Mosaic_iOS

@MainActor
final class ScaffoldingTests: XCTestCase {
    /// Tracks which parity placeholders have shipped. Update this table as each
    /// milestone switches its features on (see docs/parity/TRACKER.md).
    func testPlaceholderAvailabilityMatchesShippedMilestones() {
        let shipped = [ // M1
            RelatedTitlesSection.isAvailable, WatchProvidersSection.isAvailable, EpisodeRatingsSection.isAvailable,
            FranchiseLink.isAvailable, FranchiseView.isAvailable, CreditsView.isAvailable,
            // M2
            MovieHistorySection.isAvailable, ReviewButton.isAvailable, ReviewSection.isAvailable,
            // M3
            AddToListButton.isAvailable,
            // M4
            StatsView.isAvailable, ReviewsListView.isAvailable,
        ]
        let pending = [
            AskAboutButton.isAvailable,
            MosaicUniverseView.isAvailable,
            RecapView.isAvailable, AskView.isAvailable, YourDataView.isAvailable, ExportDataView.isAvailable, ImportFlowView.isAvailable,
        ]
        XCTAssertEqual(shipped.count + pending.count, 19)
        XCTAssertTrue(shipped.allSatisfy { $0 })
        XCTAssertTrue(pending.allSatisfy { !$0 })
    }

    func testNewRoutesAreHashableDistinctAndAppendToTheSelectedTab() throws {
        let series = try JSONDecoder.mosaic.decode(CatalogMedia.self, from: Data(
            #"{"provider":"tmdb","providerId":"76331","mediaType":"tv","title":"Succession","genres":[]}"#.utf8
        ))
        let routes: [MosaicRoute] = [
            .franchise("dune"), .season(series, 1), .reviews, .diary, .stats,
            .mosaic(nil), .recap("2026"), .yourData, .credits, .importFlow, .ask(nil), .exportData,
            .franchise("star-wars"), .season(series, 2), .mosaic("2026"), .recap("2026-10"), .ask("dune"),
        ]
        XCTAssertEqual(Set(routes).count, routes.count)
        XCTAssertEqual(Set(routes + routes).count, routes.count)
        XCTAssertNotEqual(MosaicRoute.diary, .activity)
        let router = MosaicRouter(selectedTab: .profile, paths: [.profile: [.settings]])
        for (index, route) in routes.enumerated() {
            router.open(route)
            XCTAssertEqual(router.selectedTab, .profile)
            XCTAssertEqual(router.paths[.profile], [.settings] + Array(routes.prefix(index + 1)))
        }
        for (index, route) in routes.enumerated() {
            router.open(route, in: .discover)
            XCTAssertEqual(router.selectedTab, .discover)
            XCTAssertEqual(router.paths[.discover], Array(routes.prefix(index + 1)))
        }
        XCTAssertEqual(router.paths[.profile], [.settings] + routes)
    }

    func testDuneFranchiseResolves() throws {
        let dune = try XCTUnwrap(Franchises.bySlug("dune"))
        XCTAssertEqual(dune.slug, "dune")
        XCTAssertEqual(dune.title, "Dune")
        XCTAssertFalse(dune.items.isEmpty)
    }
}

import XCTest
@testable import Mosaic_iOS

@MainActor
final class WatchProvidersTests: XCTestCase {
    func testGroupingUsesWebOrderAndKeepsProviderOrder() {
        let providers: [WatchProvider] = [
            provider(1, .buy), provider(2, .ads), provider(3, .flatrate),
            provider(4, .rent), provider(5, .free), provider(6, .flatrate)
        ]
        let groups = WatchProvidersSection.groups(providers)
        XCTAssertEqual(groups.map(\.kind), [.flatrate, .free, .ads, .rent, .buy])
        XCTAssertEqual(groups.map(\.label), ["Stream", "Free", "Free with ads", "Rent", "Buy"])
        XCTAssertEqual(groups.first?.providers.map(\.id), [3, 6])
    }

    func testGroupingSkipsEmptyKinds() {
        XCTAssertTrue(WatchProvidersSection.groups([]).isEmpty)
        XCTAssertEqual(WatchProvidersSection.groups([provider(1, .buy), provider(2, .free)]).map(\.kind), [.free, .buy])
    }

    func testMovieAndSeriesCopy() {
        XCTAssertTrue(WatchProvidersSection.isAvailable)
        XCTAssertEqual(WatchProvidersSection.title(for: .movie), "Where to watch")
        XCTAssertEqual(WatchProvidersSection.title(for: .tv), "Where to watch this series")
        XCTAssertEqual(WatchProvidersSection.hint(for: .movie), "Choose your region to see local streaming, rental, and purchase availability.")
        XCTAssertEqual(WatchProvidersSection.hint(for: .tv), "Availability is reported for the series; individual season availability can vary by provider.")
    }

    func testEveryAvailabilityStateCopy() {
        for type: CatalogMediaType in [.movie, .tv] {
            XCTAssertEqual(WatchProvidersSection.copy(for: .noRegion, type: type, region: nil), WatchProvidersSection.hint(for: type))
            XCTAssertEqual(WatchProvidersSection.copy(for: .loading, type: type, region: "IN"), "Checking availability…")
            XCTAssertEqual(WatchProvidersSection.copy(for: .failure, type: type, region: "IN"), "Watch-provider data is temporarily unavailable.")
            XCTAssertEqual(WatchProvidersSection.copy(for: .empty, type: type, region: "IN"), "No streaming options found for India.")
            XCTAssertEqual(WatchProvidersSection.copy(for: .empty, type: type, region: "NZ"), "No streaming options found for NZ.")
            XCTAssertNil(WatchProvidersSection.copy(for: .available, type: type, region: "IN"))
        }
    }

    func testRegionLabelsAndPickerOrder() {
        XCTAssertEqual(WatchProvidersSection.regions.map(\.code), ["IN", "US", "GB", "CA", "AU"])
        for (code, label) in [("IN", "India"), ("US", "United States"), ("GB", "United Kingdom"), ("CA", "Canada"), ("AU", "Australia")] {
            XCTAssertEqual(WatchProvidersSection.regionLabel(code), label)
        }
        XCTAssertEqual(WatchProvidersSection.regionLabel(nil), "Choose a region")
        XCTAssertEqual(WatchProvidersSection.regionLabel(""), "Choose a region")
        XCTAssertEqual(WatchProvidersSection.regionLabel("NZ"), "NZ")
    }

    func testRegionChangeBuildsNullableWatchRegionMutation() throws {
        for code in ["IN", "US", "GB", "CA", "AU", nil] as [String?] {
            let mutation = WatchProvidersSection.regionMutation(code)
            XCTAssertEqual(mutation, .watchRegion(code))
            XCTAssertEqual(mutation.type, "settings.watchRegion")
            let data = try JSONEncoder().encode(mutation)
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(payload["type"] as? String, "settings.watchRegion")
            if let code {
                XCTAssertEqual(payload["value"] as? String, code)
            } else {
                XCTAssertTrue(payload["value"] is NSNull)
            }
        }
    }

    private func provider(_ id: Int, _ kind: WatchProviderKind) -> WatchProvider {
        WatchProvider(id: id, name: "Provider \(id)", logoURL: nil, kind: kind)
    }
}

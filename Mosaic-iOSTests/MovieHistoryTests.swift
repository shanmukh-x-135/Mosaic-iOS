import XCTest
@testable import Mosaic_iOS

@MainActor
final class MovieHistoryTests: XCTestCase {
    func testUntouchedEditEncodesEveryOriginalField() throws {
        let watch = try watch()
        let payload = try json(MovieWatchDraft(watch: watch).mutation(for: watch))
        XCTAssertEqual(payload["type"] as? String, "movie.update")
        XCTAssertEqual(payload["watchId"] as? String, watch.id)
        XCTAssertEqual(payload["watchedAt"] as? String, "2026-01-02")
        XCTAssertEqual(payload["isRewatch"] as? Bool, true)
        XCTAssertEqual(payload["rating"] as? Double, 4.5)
        XCTAssertEqual(payload["review"] as? String, "  Keep this review.\n")
        XCTAssertEqual(payload["viewingContext"] as? String, "streaming")
        XCTAssertEqual(payload["streamingService"] as? String, "MUBI")
        XCTAssertEqual((payload["media"] as? [String: Any])?["providerId"] as? String, "1")
    }

    func testDateOnlyRoundTripWestOfUTC() throws {
        // Use an explicit zone so this test cannot change the process-wide
        // timezone of other tests or the shared mutation encoder.
        let west = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        for day in ["2026-01-02", "2026-07-02", "2026-03-08", "2026-11-01"] {
            let date = try XCTUnwrap(MovieWatchDay.parse(day))
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = west
            formatter.dateFormat = "yyyy-MM-dd"
            XCTAssertEqual(formatter.string(from: MovieWatchDay.mutationDate(date, timeZone: west)), day)
            XCTAssertEqual(MovieWatchDay.calendar.component(.day, from: date), Int(day.suffix(2)))
            XCTAssertEqual(try json(MovieWatchDraft(watch: watch(day: day)).mutation(for: watch(day: day)))["watchedAt"] as? String, day)
        }
    }

    func testNilRatingAndReviewRemainOmittedAndServiceRequiresStreaming() throws {
        var watch = try watch()
        watch.rating = nil
        watch.review = nil
        watch.viewingContext = "television"
        let payload = try json(MovieWatchDraft(watch: watch).mutation(for: watch))
        XCTAssertNil(payload["rating"])
        XCTAssertNil(payload["review"])
        XCTAssertNil(payload["streamingService"])
        XCTAssertEqual(payload["viewingContext"] as? String, "television")

        watch.review = ""
        watch.viewingContext = nil
        let empty = try json(MovieWatchDraft(watch: watch).mutation(for: watch))
        XCTAssertEqual(empty["review"] as? String, "")
        XCTAssertNil(empty["viewingContext"])
    }

    func testEditedValuesReplaceOriginalFields() throws {
        let watch = try watch()
        var draft = MovieWatchDraft(watch: watch)
        draft.date = try XCTUnwrap(MovieWatchDay.parse("2025-12-31"))
        draft.isRewatch = false
        draft.rating = nil
        draft.review = "New review"
        draft.viewingContext = .theater
        let payload = try json(draft.mutation(for: watch))
        XCTAssertEqual(payload["watchedAt"] as? String, "2025-12-31")
        XCTAssertEqual(payload["isRewatch"] as? Bool, false)
        XCTAssertNil(payload["rating"])
        XCTAssertEqual(payload["review"] as? String, "New review")
        XCTAssertEqual(payload["viewingContext"] as? String, "theater")
        XCTAssertNil(payload["streamingService"])
    }

    func testValidationBoundaries() throws {
        var draft = MovieWatchDraft(watch: try watch())
        draft.review = String(repeating: "x", count: 10_000)
        draft.streamingService = String(repeating: "x", count: 120)
        XCTAssertNil(draft.validationMessage)
        draft.review.append("x")
        XCTAssertNotNil(draft.validationMessage)
        draft.review = ""
        draft.streamingService.append("x")
        XCTAssertNotNil(draft.validationMessage)
        draft.viewingContext = .physical
        XCTAssertNil(draft.validationMessage)
    }

    func testRowTextAndAccessibility() throws {
        var watch = try watch()
        XCTAssertEqual(MovieHistorySection.dateText(watch, locale: Locale(identifier: "en_US")), "Watched Jan 2, 2026")
        XCTAssertEqual(MovieHistorySection.detailsText(watch), "Rewatch · Streaming · MUBI · ★ 4.5")
        XCTAssertEqual(MovieHistorySection.accessibilityLabel(watch, locale: Locale(identifier: "en_US")),
                       "Watched Jan 2, 2026, Rewatch, Your rating 4.5 out of 5")
        watch.isRewatch = false
        watch.viewingContext = "television"
        watch.streamingService = nil
        watch.rating = nil
        XCTAssertEqual(MovieHistorySection.detailsText(watch), "First watch · TV / Broadcast")
        watch.viewingContext = nil
        XCTAssertEqual(MovieHistorySection.detailsText(watch), "First watch")
    }

    func testSnapshotFiltersMovieAndOrdersNewestFirst() throws {
        let oldest = try watch(id: "old", day: "2024-12-31")
        let newest = try watch(id: "new", day: "2026-02-01")
        let middle = try watch(id: "middle", day: "2026-01-02")
        let unrelated = try watch(id: "other", day: "2026-03-01", mediaID: "2")
        let snapshot = MosaicStateSnapshot(movieWatches: [oldest, unrelated, newest, middle])
        XCTAssertEqual(snapshot.movieWatches(for: oldest.media).map(\.id), ["new", "middle", "old"])
        XCTAssertTrue(MosaicStateSnapshot().movieWatches(for: oldest.media).isEmpty)
        XCTAssertTrue(MovieHistorySection.isAvailable)
    }

    func testDeleteUsesOnlyWatchIdentity() throws {
        let payload = try json(MovieHistorySection.deleteMutation(for: watch()))
        XCTAssertEqual(payload["type"] as? String, "movie.delete")
        XCTAssertEqual(payload["watchId"] as? String, "watch-1")
        XCTAssertEqual(Set(payload.keys), ["type", "watchId"])
    }

    private func json(_ mutation: DetailMutation) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(mutation)) as? [String: Any])
    }

    private func watch(id: String = "watch-1", day: String = "2026-01-02", mediaID: String = "1") throws -> MosaicStateSnapshot.MovieWatch {
        let media = try JSONDecoder().decode(CatalogMedia.self, from: JSONSerialization.data(withJSONObject: [
            "provider": "tmdb", "providerId": mediaID, "mediaType": "movie", "title": "Movie", "genres": []
        ]))
        return .init(media: media, watchedAt: day, id: id, isRewatch: true, rating: 4.5,
                     review: "  Keep this review.\n", viewingContext: "streaming", streamingService: "MUBI")
    }
}

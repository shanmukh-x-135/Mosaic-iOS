import XCTest
@testable import Mosaic_iOS

final class ReviewTests: XCTestCase {
    func testNewReviewTrimsBodyAndOmitsIDAndAbsentRating() throws {
        let media = try media()
        let payload = try encode(ReviewEditorView.makeSaveMutation(
            existing: nil, media: media, body: " \n Stayed with me. \t", spoilers: true, rating: nil
        ))
        XCTAssertEqual(payload["type"] as? String, "review.save")
        XCTAssertEqual(payload["body"] as? String, "Stayed with me.")
        XCTAssertEqual(payload["containsSpoilers"] as? Bool, true)
        XCTAssertEqual((payload["media"] as? [String: Any])?["providerId"] as? String, media.providerID)
        XCTAssertNil(payload["id"])
        XCTAssertNil(payload["rating"])
    }

    func testEditSendsExistingIDAndCurrentRating() throws {
        let media = try media()
        let existing = MosaicStateSnapshot.Review(id: "review-1", media: media, body: "Before", containsSpoilers: true, rating: 2, updatedAt: "2026-11-14T10:00:00.000Z")
        let payload = try encode(ReviewEditorView.makeSaveMutation(
            existing: existing, media: media, body: " After\n", spoilers: false, rating: 4.5
        ))
        XCTAssertEqual(payload["id"] as? String, existing.id)
        XCTAssertEqual(payload["body"] as? String, "After")
        XCTAssertEqual(payload["containsSpoilers"] as? Bool, false)
        XCTAssertEqual(payload["rating"] as? Double, 4.5)
        let unrated = try encode(ReviewEditorView.makeSaveMutation(
            existing: existing, media: media, body: "After", spoilers: false, rating: nil
        ))
        XCTAssertNil(unrated["rating"], "Do not reuse the review’s old rating when there is no current rating")
    }

    func testValidationRejectsEmptyWhitespaceAndOverLimitBodies() {
        for body in ["", " \t\n\r", String(repeating: "a", count: 10_001)] {
            XCTAssertNotNil(ReviewEditorView.validate(body))
        }
        XCTAssertNil(ReviewEditorView.validate("A"))
        XCTAssertNil(ReviewEditorView.validate(" \n" + String(repeating: "a", count: 10_000) + "\n "))
    }

    func testValidationMatchesWebUTF16Length() {
        XCTAssertNil(ReviewEditorView.validate(String(repeating: "😀", count: 5_000)))
        XCTAssertNotNil(ReviewEditorView.validate(String(repeating: "😀", count: 5_001)))
    }

    func testDeleteEncodesReviewID() throws {
        let payload = try encode(.reviewDelete(id: "review-1"))
        XCTAssertEqual(payload["type"] as? String, "review.delete")
        XCTAssertEqual(payload["id"] as? String, "review-1")
        XCTAssertEqual(Set(payload.keys), ["type", "id"])
    }

    private func encode(_ mutation: DetailMutation) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(mutation)) as? [String: Any])
    }

    private func media() throws -> CatalogMedia {
        try JSONDecoder().decode(CatalogMedia.self, from: Data(#"{"provider":"tmdb","providerId":"123","mediaType":"movie","title":"A story","genres":[]}"#.utf8))
    }
}

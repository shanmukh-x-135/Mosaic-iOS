import XCTest
@testable import Mosaic_iOS

final class AddToListTests: XCTestCase {
    func testContainsMediaUsesMediaKeyRatherThanTitleOrMetadata() throws {
        let original = try media()
        let list = list("one", items: [.init(id: "item", media: original, position: 0, note: nil)])
        XCTAssertTrue(AddToListSheet.containsMedia(list, try media(title: "Renamed")))
        XCTAssertFalse(AddToListSheet.containsMedia(list, try media(id: "456")))
        XCTAssertFalse(AddToListSheet.containsMedia(list, try media(type: "tv")))
        XCTAssertFalse(AddToListSheet.containsMedia(list, try media(provider: "mock")))
        XCTAssertFalse(AddToListSheet.containsMedia(self.list("empty"), original))
    }

    func testNewListIDDiffIgnoresReorderingAndUpdatesToExistingLists() {
        let before = [list("one"), list("two")]
        let after = [list("two", updatedAt: 50), list("new"), list("one")]
        XCTAssertEqual(AddToListSheet.newListID(before: before, after: after), "new")
        XCTAssertNil(AddToListSheet.newListID(before: before, after: [list("two", updatedAt: 90), list("one")]))
        XCTAssertNil(AddToListSheet.newListID(before: before, after: []))
        XCTAssertNil(AddToListSheet.newListID(before: [], after: []))
        XCTAssertEqual(AddToListSheet.newListID(before: [], after: [list("first")]), "first")
    }

    func testListOrderingIsNewestFirstWithStableTies() {
        let lists = [list("old", updatedAt: 1), list("b", updatedAt: 3), list("a", updatedAt: 3), list("middle", updatedAt: 2)]
        XCTAssertEqual(AddToListSheet.orderedLists(lists).map(\.id), ["a", "b", "middle", "old"])
        XCTAssertTrue(AddToListSheet.orderedLists([]).isEmpty)
    }

    func testTitleValidationTrimsAndEnforcesLength() {
        for title in ["", " \t\n\r", String(repeating: "a", count: 121)] {
            XCTAssertNotNil(AddToListSheet.validateTitle(title))
        }
        XCTAssertNil(AddToListSheet.validateTitle("A"))
        XCTAssertNil(AddToListSheet.validateTitle(" \n" + String(repeating: "a", count: 120) + "\t "))
        XCTAssertNil(AddToListSheet.validateTitle(String(repeating: "😀", count: 60)))
        XCTAssertNotNil(AddToListSheet.validateTitle(String(repeating: "😀", count: 61)))
    }

    func testAddCommandEncodesListIDAndMedia() throws {
        let media = try media()
        let command = DetailMutation.listAdd(listID: "list-123", media: media, note: nil)
        let data = try JSONEncoder().encode(command)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["type"] as? String, "list.add")
        XCTAssertEqual(payload["listId"] as? String, "list-123")
        let encodedMedia = try XCTUnwrap(payload["media"] as? [String: Any])
        XCTAssertEqual(encodedMedia["provider"] as? String, media.provider)
        XCTAssertEqual(encodedMedia["providerId"] as? String, media.providerID)
        XCTAssertEqual(encodedMedia["mediaType"] as? String, "movie")
        XCTAssertEqual(encodedMedia["title"] as? String, media.title)
        XCTAssertNil(payload["note"])
    }

    private func list(_ id: String, updatedAt: TimeInterval = 0, items: [UserList.Item] = []) -> UserList {
        UserList(id: id, title: id, description: "", visibility: .private, items: items, updatedAt: Date(timeIntervalSince1970: updatedAt))
    }

    private func media(id: String = "123", title: String = "A story", type: String = "movie", provider: String = "tmdb") throws -> CatalogMedia {
        let data = try JSONSerialization.data(withJSONObject: ["provider": provider, "providerId": id, "mediaType": type, "title": title, "genres": []])
        return try JSONDecoder().decode(CatalogMedia.self, from: data)
    }
}

import XCTest
@testable import Mosaic_iOS

final class ListEditorTests: XCTestCase {
    func testNewListIDUsesDifferenceRatherThanOrder() {
        let old = list("old")
        let new = list("new")
        XCTAssertEqual(ListEditor.newListID(before: [old], after: [old, new]), "new")
        XCTAssertEqual(ListEditor.newListID(before: [], after: [new]), "new")
        XCTAssertNil(ListEditor.newListID(before: [old, new], after: [new, old]))
        XCTAssertNil(ListEditor.newListID(before: [old], after: []))
    }

    func testReorderIncludesEveryIDInMovedOrder() throws {
        let media = try media()
        let items = (0..<4).map { UserList.Item(id: "item-\($0)", media: media, position: $0, note: nil) }
        let ids = ListEditor.reorderedIDs(items, from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(ids, ["item-1", "item-2", "item-0", "item-3"])
        XCTAssertEqual(ListEditor.reorderedIDs(items, from: IndexSet(integer: 3), to: 0), ["item-3", "item-0", "item-1", "item-2"])
        XCTAssertEqual(ListEditor.reorderedIDs(items, from: IndexSet([0, 2]), to: 4), ["item-1", "item-3", "item-0", "item-2"])
        XCTAssertEqual(ListEditor.reorderedIDs([], from: [], to: 0), [])
        let payload = try encode(.listReorder(listID: "list", itemIDs: ids))
        XCTAssertEqual(payload["itemIds"] as? [String], ids)
        XCTAssertEqual(Set(payload.keys), ["type", "listId", "itemIds"])
    }

    func testDuplicatesUseProviderMediaTypeAndProviderID() throws {
        let original = try media()
        let collection = list(items: [.init(id: "entry", media: original, position: 0, note: nil)])
        XCTAssertTrue(ListEditor.isAlreadyAdded(try media(title: "Renamed"), in: collection))
        XCTAssertFalse(ListEditor.isAlreadyAdded(try media(provider: "other"), in: collection))
        XCTAssertFalse(ListEditor.isAlreadyAdded(try media(type: "tv"), in: collection))
        XCTAssertFalse(ListEditor.isAlreadyAdded(try media(id: "other"), in: collection))
        XCTAssertFalse(ListEditor.isAlreadyAdded(original, in: list()))
    }

    func testTitleValidationAtLimitsAndTrimming() {
        for validate in [ListEditor.validateCreate, ListEditor.validateUpdate] {
            XCTAssertNil(validate(String(repeating: "a", count: 120), ""))
            XCTAssertNotNil(validate(String(repeating: "a", count: 121), ""))
            XCTAssertNil(validate(" \n" + String(repeating: "a", count: 120) + "\t", ""))
            XCTAssertNotNil(validate(" \n\t", ""))
            XCTAssertNotNil(validate("", ""))
            XCTAssertNil(validate(String(repeating: "😀", count: 60), ""))
            XCTAssertNotNil(validate(String(repeating: "😀", count: 61), ""))
        }
    }

    func testDescriptionAndNoteLimitsMatchWeb() {
        XCTAssertNil(ListEditor.validateCreate(title: "List", description: String(repeating: "a", count: 1000)))
        XCTAssertNotNil(ListEditor.validateCreate(title: "List", description: String(repeating: "a", count: 1001)))
        XCTAssertNil(ListEditor.validateCreate(title: "List", description: " " + String(repeating: "a", count: 1000) + "\n"))
        XCTAssertNil(ListEditor.validateUpdate(title: "List", description: String(repeating: "a", count: 2000)))
        XCTAssertNotNil(ListEditor.validateUpdate(title: "List", description: String(repeating: "a", count: 2001)))
        XCTAssertNotNil(ListEditor.validateUpdate(title: "List", description: " " + String(repeating: "a", count: 2000)))
        XCTAssertNil(ListEditor.validateNote(""), "Empty notes clear the existing note")
        XCTAssertNil(ListEditor.validateNote(String(repeating: "a", count: 2000)))
        XCTAssertNotNil(ListEditor.validateNote(String(repeating: "a", count: 2001)))
        XCTAssertNil(ListEditor.validateNote(String(repeating: "😀", count: 1000)))
        XCTAssertNotNil(ListEditor.validateNote(String(repeating: "😀", count: 1001)))
    }

    func testShareURLIsOnlyAvailableForPublicAndUnlisted() throws {
        let base = try XCTUnwrap(URL(string: "https://mosaic.example"))
        XCTAssertNil(ListEditor.shareURL(for: list("private", visibility: .private), base: base))
        for visibility in [UserList.Visibility.public, .unlisted] {
            XCTAssertEqual(ListEditor.shareURL(for: list("abc-123", visibility: visibility), base: base)?.absoluteString, "https://mosaic.example/lists/abc-123")
        }
    }

    func testCommandsEncodeExactWebSchemaKeysAndValues() throws {
        let create = try encode(.listCreate(title: "Collection", description: "Description", visibility: .private))
        XCTAssertEqual(Set(create.keys), ["type", "title", "description", "visibility"])
        XCTAssertEqual(create["type"] as? String, "list.create")
        XCTAssertEqual(create["title"] as? String, "Collection")
        XCTAssertEqual(create["description"] as? String, "Description")
        XCTAssertEqual(create["visibility"] as? String, "private")

        let update = try encode(.listUpdate(listID: "list", title: "Changed", description: "New", visibility: .unlisted))
        XCTAssertEqual(Set(update.keys), ["type", "listId", "title", "description", "visibility"])
        XCTAssertEqual(update["type"] as? String, "list.update")
        XCTAssertEqual(update["listId"] as? String, "list")
        XCTAssertEqual(update["title"] as? String, "Changed")
        XCTAssertEqual(update["description"] as? String, "New")
        XCTAssertEqual(update["visibility"] as? String, "unlisted")

        let add = try encode(.listAdd(listID: "list", media: media()))
        XCTAssertEqual(Set(add.keys), ["type", "listId", "media"])
        XCTAssertEqual(add["type"] as? String, "list.add")
        XCTAssertEqual(add["listId"] as? String, "list")
        XCTAssertEqual((add["media"] as? [String: Any])?["providerId"] as? String, "123")
        let notedAdd = try encode(.listAdd(listID: "list", media: media(), note: "Note"))
        XCTAssertEqual(notedAdd["note"] as? String, "Note")

        let note = try encode(.listItemUpdate(listID: "list", itemID: "entry", note: ""))
        XCTAssertEqual(Set(note.keys), ["type", "listId", "itemId", "note"])
        XCTAssertEqual(note["type"] as? String, "list.item.update")
        XCTAssertEqual(note["listId"] as? String, "list")
        XCTAssertEqual(note["itemId"] as? String, "entry")
        XCTAssertEqual(note["note"] as? String, "")

        let remove = try encode(.listItemRemove(listID: "list", itemID: "entry"))
        XCTAssertEqual(Set(remove.keys), ["type", "listId", "itemId"])
        XCTAssertEqual(remove["type"] as? String, "list.item.remove")
        XCTAssertEqual(remove["listId"] as? String, "list")
        XCTAssertEqual(remove["itemId"] as? String, "entry")
        let reorder = try encode(.listReorder(listID: "list", itemIDs: ["b", "a"]))
        XCTAssertEqual(reorder["type"] as? String, "list.reorder")
        XCTAssertEqual(reorder["listId"] as? String, "list")
        XCTAssertEqual(reorder["itemIds"] as? [String], ["b", "a"])
    }

    private func list(_ id: String = "list", visibility: UserList.Visibility = .private, items: [UserList.Item] = []) -> UserList {
        .init(id: id, title: "List", description: "", visibility: visibility, items: items, updatedAt: .distantPast)
    }

    private func media(provider: String = "tmdb", type: String = "movie", id: String = "123", title: String = "Story") throws -> CatalogMedia {
        let data = try JSONSerialization.data(withJSONObject: ["provider": provider, "mediaType": type, "providerId": id, "title": title, "genres": []])
        return try JSONDecoder().decode(CatalogMedia.self, from: data)
    }

    private func encode(_ mutation: DetailMutation) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(mutation)) as? [String: Any])
    }
}

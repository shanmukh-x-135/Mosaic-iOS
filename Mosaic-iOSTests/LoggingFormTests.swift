import XCTest
@testable import Mosaic_iOS

@MainActor
final class LoggingFormTests: XCTestCase {
    func testMoviesCanSaveWhileLibraryIsLoadingOrFailed() {
        let states: [Loadable<[LibraryItemDTO]>] = [.idle, .loading, .failed(URLError(.notConnectedToInternet))]
        for state in states {
            XCTAssertTrue(MediaLogForm.canSave(.init(), mediaType: .movie, libraryState: state, isSaving: false))
        }
    }

    func testGamesAndBooksRequireLoadedRecordsToSave() {
        let states: [Loadable<[LibraryItemDTO]>] = [.idle, .loading, .failed(URLError(.notConnectedToInternet))]
        for type in [CatalogMediaType.game, .book] {
            for state in states {
                XCTAssertFalse(MediaLogForm.canSave(.init(), mediaType: type, libraryState: state, isSaving: false))
            }
            XCTAssertTrue(MediaLogForm.canSave(.init(), mediaType: type, libraryState: .loaded([]), isSaving: false))
        }
    }

    func testMoviesStillRequireValidFieldsAndCannotSaveConcurrently() {
        var draft = MediaLogForm.Draft()
        XCTAssertFalse(MediaLogForm.canSave(draft, mediaType: .movie, libraryState: .loading, isSaving: true))
        draft.viewingContext = .streaming
        draft.streamingService = String(repeating: "a", count: 121)
        XCTAssertFalse(MediaLogForm.canSave(draft, mediaType: .movie, libraryState: .loading, isSaving: false))
    }

    func testLateFavoritePrefillPreservesUserChoiceAndOtherFields() throws {
        let favorite = try item("favorite", isFavorite: true)
        var draft = MediaLogForm.Draft()
        draft.review = "Already typing"
        draft.prefillFavorite(from: favorite, userChanged: false)
        XCTAssertTrue(draft.isFavorite)
        draft.isFavorite = false
        draft.prefillFavorite(from: favorite, userChanged: true)
        XCTAssertFalse(draft.isFavorite)
        draft.isFavorite = true
        draft.prefillFavorite(from: nil, userChanged: true)
        XCTAssertTrue(draft.isFavorite)
        XCTAssertEqual(draft.review, "Already typing")
        draft.prefillFavorite(from: nil, userChanged: false)
        XCTAssertFalse(draft.isFavorite)
        XCTAssertTrue(MediaLogForm.shouldSendFavoriteFollowUp(isOn: true, alreadyFavorite: draft.isFavorite))
    }

    func testMovieLogEncodesContextAndOnlySendsServiceForStreaming() throws {
        let media = CatalogMedia(identity: try item("movie"))
        var draft = MediaLogForm.Draft()
        draft.streamingService = "  MUBI \n"
        for context in MovieViewingContext.allCases {
            draft.viewingContext = context
            let payload = try encode(MediaLogForm.mutation(for: draft, media: media))
            XCTAssertEqual(payload["type"] as? String, "movie.log")
            XCTAssertEqual(payload["viewingContext"] as? String, context.rawValue)
            XCTAssertEqual(payload["streamingService"] as? String, context == .streaming ? "MUBI" : nil)
        }
        draft.viewingContext = nil
        let unspecified = try encode(MediaLogForm.mutation(for: draft, media: media))
        XCTAssertNil(unspecified["viewingContext"])
        XCTAssertNil(unspecified["streamingService"])
        draft.viewingContext = .streaming
        draft.streamingService = " \n "
        XCTAssertNil(try encode(MediaLogForm.mutation(for: draft, media: media))["streamingService"])
    }

    func testFavoriteFollowUpOnlyForNewlySelectedFavorite() {
        for isOn in [false, true] {
            for alreadyFavorite in [false, true] {
                XCTAssertEqual(MediaLogForm.shouldSendFavoriteFollowUp(isOn: isOn, alreadyFavorite: alreadyFavorite),
                               isOn && !alreadyFavorite)
            }
        }
    }

    func testMovieDraftStartsWithSavedFavorite() throws {
        let favorite = try item("favorite", isFavorite: true)
        let media = CatalogMedia(identity: favorite)
        XCTAssertTrue(MediaLogForm.initialDraft(media: media, entry: favorite, seriesState: nil).isFavorite)
        XCTAssertFalse(MediaLogForm.initialDraft(media: media, entry: nil, seriesState: nil).isFavorite)
        let ordinary = try item("ordinary")
        XCTAssertFalse(MediaLogForm.initialDraft(media: CatalogMedia(identity: ordinary), entry: ordinary, seriesState: nil).isFavorite)
    }

    func testStreamingServiceValidationBoundaryAndHiddenDraft() {
        var draft = MediaLogForm.Draft()
        draft.viewingContext = .streaming
        draft.streamingService = String(repeating: "a", count: 120)
        XCTAssertNil(MediaLogForm.validate(draft, mediaType: .movie))
        draft.streamingService += "a"
        XCTAssertEqual(MediaLogForm.validate(draft, mediaType: .movie), "Streaming service must be 120 characters or fewer.")
        for context in MovieViewingContext.allCases where context != .streaming {
            draft.viewingContext = context
            XCTAssertNil(MediaLogForm.validate(draft, mediaType: .movie))
        }
        draft.viewingContext = nil
        XCTAssertNil(MediaLogForm.validate(draft, mediaType: .movie))
        XCTAssertEqual(draft.streamingService.count, 121)
        XCTAssertNil(MediaLogForm.validate(draft, mediaType: .tv))
    }

    func testRecentChoicesSortBeforeDeduplicationAndCapAtEight() throws {
        let older = try item("duplicate", updated: 1, rowID: "old")
        let newer = try item("duplicate", updated: 20, rowID: "new")
        let others = try (2...11).map { try item(String($0), updated: $0) }
        let choices = QuickLogChoices.recentChoices(from: [older] + others + [newer], filter: .all)
        XCTAssertEqual(choices.map(\.providerID), ["duplicate", "11", "10", "9", "8", "7", "6", "5"])
        XCTAssertEqual(choices.first?.id, "new")
        XCTAssertEqual(Set(choices.map(\.mediaKey)).count, 8)
        XCTAssertTrue(QuickLogChoices.recentChoices(from: [], filter: .movies).isEmpty)
    }

    func testRecentChoicesFilterBeforeCappingAndKeepMediumIdentitiesDistinct() throws {
        let movies = try (1...9).map { try item(String($0), updated: $0 + 10) }
        let series = try item("1", type: .tv, updated: 4)
        let game = try item("1", type: .game, updated: 3)
        let book = try item("1", type: .book, updated: 2)
        let items = movies + [series, game, book]
        for (filter, expected) in [(CatalogFilter.series, series), (.games, game), (.books, book)] {
            XCTAssertEqual(QuickLogChoices.recentChoices(from: items, filter: filter), [expected])
        }
        XCTAssertEqual(QuickLogChoices.recentChoices(from: items, filter: .movies).count, 8)
        XCTAssertEqual(QuickLogChoices.recentChoices(from: [movies[0], series, game, book]).count, 4)
        XCTAssertEqual(CatalogMedia(identity: series).route, series.route)
    }

    func testRecentChoicesPreserveInputOrderForEqualDates() throws {
        let items = try [item("b"), item("a")]
        XCTAssertEqual(QuickLogChoices.recentChoices(from: items), items)
    }

    private func item(_ id: String, type: CatalogMediaType = .movie, updated: Int = 1,
                      rowID: String? = nil, isFavorite: Bool = false) throws -> LibraryItemDTO {
        let payload: [String: Any] = [
            "id": rowID ?? "\(type.rawValue):\(id)", "provider": "tmdb", "providerId": id,
            "mediaType": type.rawValue, "title": "Title \(id)", "status": "watched",
            "isFavorite": isFavorite, "updatedAt": "2026-11-\(String(format: "%02d", updated))T10:00:00.000Z",
        ]
        return try JSONDecoder.mosaic.decode(LibraryItemDTO.self, from: JSONSerialization.data(withJSONObject: payload))
    }

    private func encode(_ mutation: DetailMutation) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(mutation)) as? [String: Any])
    }
}

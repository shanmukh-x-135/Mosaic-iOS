import XCTest
@testable import Mosaic_iOS

/// Cross-platform product rules shared with the web app (Tracking App `bc49972`)
/// and regression tests for the Phase 2 alignment fixes.
@MainActor
final class MosaicAlignmentTests: XCTestCase {
    // MARK: Ratings (`src/lib/media/ratings.ts`)

    func testCommunityRatingsNormalizeEveryProviderToTenWithSource() {
        XCTAssertEqual(CommunityRating(raw: 7.456, provider: "tmdb")?.value, 7.5)
        XCTAssertEqual(CommunityRating(raw: 4.4, provider: "igdb")?.value, 8.8)
        XCTAssertEqual(CommunityRating(raw: 4.2, provider: "googlebooks")?.value, 8.4)
        XCTAssertEqual(CommunityRating(raw: 3, provider: "mock")?.value, 6)
        XCTAssertEqual(CommunityRating(raw: 4.4, provider: "igdb")?.source.shortLabel, "IGDB")
        XCTAssertEqual(CommunityRating(raw: 4.2, provider: "googlebooks")?.formattedValue, "8.4")
    }

    func testCommunityRatingRejectsMissingInvalidAndUnvotedZero() {
        XCTAssertNil(CommunityRating(raw: nil, provider: "tmdb"))
        XCTAssertNil(CommunityRating(raw: 0, provider: "tmdb"), "Providers report 0 when nobody voted")
        XCTAssertEqual(CommunityRating(raw: 0, provider: "tmdb", count: 3)?.value, 0)
        XCTAssertNil(CommunityRating(raw: 6, provider: "igdb"), "Out of the stored 0–5 range")
        XCTAssertNil(CommunityRating(raw: .nan, provider: "tmdb"))
        XCTAssertNil(CommunityRating(raw: 5, provider: "unknown"))
        XCTAssertEqual(CommunityRating(raw: 8, provider: "tmdb", count: 1)?.accessibilityDescription, "Community rating 8.0 out of 10 on TMDB from 1 rating")
    }

    // MARK: Statuses (`mediaStatuses`, `statusLabels`, `saveForLaterStatus`)

    func testStatusesAreMediumSpecificWithWebLabels() {
        XCTAssertEqual(LibraryStatus.statuses(for: .movie), [.watchlist, .watched])
        XCTAssertEqual(LibraryStatus.statuses(for: .tv), [.watchlist, .watching, .completed, .paused, .dropped])
        XCTAssertEqual(LibraryStatus.statuses(for: .game), [.backlog, .playing, .paused, .completed, .dropped])
        XCTAssertEqual(LibraryStatus.statuses(for: .book), [.wantToRead, .reading, .paused, .finished, .dnf])
        XCTAssertEqual(LibraryStatus.dnf.label, "Did not finish")
        XCTAssertEqual(LibraryStatus.label(for: "want_to_read"), "Want to read")
        XCTAssertFalse(LibraryStatus.watched.applies(to: .book))
    }

    func testSaveForLaterNeverStartsASeries() {
        XCTAssertEqual(LibraryStatus.saveForLater(for: .tv), .watchlist)
        XCTAssertEqual(LibraryStatus.saveForLater(for: .game), .backlog)
        XCTAssertEqual(LibraryStatus.saveForLater(for: .book), .wantToRead)
        XCTAssertEqual(LibraryStatus.saveForLater(for: .movie), .watchlist)
    }

    // MARK: Mutations

    func testSaveForLaterOnlyInsertsUntrackedAndKeepsFavourite() throws {
        let payload = try encode(.saveForLater(media(.tv)))
        XCTAssertEqual(payload["type"] as? String, "library.upsert")
        XCTAssertEqual(payload["status"] as? String, "watchlist")
        XCTAssertEqual(payload["onlyIfUntracked"] as? Bool, true)
        XCTAssertNil(payload["isFavorite"], "Omitted means unchanged on the server")
    }

    func testStatusChangeOmitsFavourite() throws {
        let payload = try encode(.library(media(.game), status: "paused"))
        XCTAssertEqual(payload["status"] as? String, "paused")
        XCTAssertNil(payload["isFavorite"])
        XCTAssertNil(payload["onlyIfUntracked"])
    }

    /// Regression: clearing a rating must send `"value": null`; an omitted key
    /// fails the server's `rating.nullable()` schema.
    func testClearingARatingSendsExplicitNull() throws {
        let data = try JSONEncoder().encode(DetailMutation.rating(media(.movie), nil))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(payload.keys.contains("value"))
        XCTAssertTrue(payload["value"] is NSNull)
        XCTAssertEqual(try encode(.rating(media(.movie), 3.5))["value"] as? Double, 3.5)
    }

    func testLibraryIdentityIsSchemaValidForEveryMedium() throws {
        let item = try JSONDecoder.mosaic.decode(LibraryItemDTO.self, from: Data(#"{"id":"igdb:game:7","mediaType":"game","provider":"igdb","providerId":"7","title":"Hades","status":"playing","userRating":null,"isFavorite":false,"updatedAt":"2026-09-19T10:00:00.000Z"}"#.utf8))
        let payload = try encode(.removeLibrary(CatalogMedia(identity: item)))
        let media = try XCTUnwrap(payload["media"] as? [String: Any])
        XCTAssertEqual(media["providerId"] as? String, "7")
        XCTAssertEqual(media["genres"] as? [String], [])
        XCTAssertEqual(media["platforms"] as? [String], [], "The game schema requires platforms")
    }

    // MARK: Game and book progress target the existing record

    /// Regression: an update without `playthroughId`/`readingId` inserts a new row,
    /// so the form must prefill them from the Library entry.
    func testGameUpdateTargetsLibraryProgressRecordAndKeepsItsValues() throws {
        let game = media(.game)
        let entry = try libraryEntry("""
        {"id":"tmdb:game:1","mediaType":"game","provider":"tmdb","providerId":"1","title":"Title","status":"playing","userRating":4,"isFavorite":false,"updatedAt":"2026-10-01T00:00:00.000Z","progressId":"current","progress":{"playtimeMinutes":245,"percent":40,"platform":"PC"}}
        """)
        let draft = MediaLogForm.initialDraft(media: game, entry: entry, seriesState: nil)
        XCTAssertEqual(draft.playthroughID, "current")
        XCTAssertEqual(draft.platform, "PC")
        XCTAssertEqual(draft.playtimeHours, "4.08")
        XCTAssertEqual(draft.percent, "40")
        XCTAssertEqual(draft.rating, 4)
        let payload = try encode(MediaLogForm.mutation(for: draft, media: game))
        XCTAssertEqual(payload["type"] as? String, "game.upsert")
        XCTAssertEqual(payload["playthroughId"] as? String, "current")
        XCTAssertEqual(payload["playtimeMinutes"] as? Int, 245, "An untouched playtime round-trips exactly")
        XCTAssertEqual(payload["rating"] as? Double, 4)
    }

    func testFirstGameUpdateStartsANewPlaythroughFromLibraryStatus() throws {
        let entry = try libraryEntry("""
        {"id":"tmdb:game:1","mediaType":"game","provider":"tmdb","providerId":"1","title":"Title","status":"backlog","userRating":null,"isFavorite":false,"updatedAt":"2026-10-01T00:00:00.000Z"}
        """)
        let draft = MediaLogForm.initialDraft(media: media(.game), entry: entry, seriesState: nil)
        XCTAssertNil(draft.playthroughID)
        XCTAssertEqual(draft.status, "backlog")
        let payload = try encode(MediaLogForm.mutation(for: draft, media: media(.game)))
        XCTAssertNil(payload["playthroughId"])
        XCTAssertNil(payload["progressPercent"], "A blank percentage is not recorded as 0")
        XCTAssertEqual(payload["playtimeMinutes"] as? Int, 0)
    }

    func testBookUpdateTargetsTheExistingReadingAndValidatesPages() throws {
        let book = media(.book)
        let entry = try libraryEntry("""
        {"id":"tmdb:book:1","mediaType":"book","provider":"tmdb","providerId":"1","title":"Title","status":"reading","userRating":null,"isFavorite":false,"updatedAt":"2026-10-09T09:00:00.000Z","progressId":"reading-1","progress":{"currentPage":96,"totalPages":304,"percent":32}}
        """)
        var draft = MediaLogForm.initialDraft(media: book, entry: entry, seriesState: nil)
        XCTAssertEqual(draft.readingID, "reading-1")
        XCTAssertEqual(draft.currentPage, "96")
        XCTAssertEqual(draft.totalPages, "304")
        let payload = try encode(MediaLogForm.mutation(for: draft, media: book))
        XCTAssertEqual(payload["readingId"] as? String, "reading-1")
        XCTAssertNil(payload["progressPercent"], "With a page total the server derives the percentage")
        draft.currentPage = "400"
        XCTAssertEqual(MediaLogForm.validate(draft, mediaType: .book), "Current page cannot exceed total pages.")
        draft.currentPage = "100"; draft.percent = "120"
        XCTAssertNotNil(MediaLogForm.validate(draft, mediaType: .book))
    }

    func testEpisodeFormStartsAtTheNextUnwatchedEpisode() throws {
        let series = try JSONDecoder.mosaic.decode(CatalogMedia.self, from: Data(#"{"provider":"tmdb","providerId":"1","mediaType":"tv","title":"Show","genres":[],"seasonNumbers":[0,1,2],"eligibleEpisodeCounts":{"0":3,"1":2,"2":5}}"#.utf8))
        let state = try JSONDecoder.mosaic.decode(SeriesPersonalState.self, from: Data(#"{"status":"watching","isFavorite":false,"userRating":null,"episodes":[{"seasonNumber":1,"episodeNumber":1,"watchedAt":"2026-01-01T00:00:00.000Z","rating":null},{"seasonNumber":1,"episodeNumber":2,"watchedAt":"2026-01-02T00:00:00.000Z","rating":null}],"seasons":[]}"#.utf8))
        let draft = MediaLogForm.initialDraft(media: series, entry: nil, seriesState: state)
        XCTAssertEqual(draft.season, 2, "Specials (season 0) are skipped")
        XCTAssertEqual(draft.episode, 1)
    }

    // MARK: Discover (`discovery.ts`, `genres.ts`, `recommendations.ts`)

    func testDiscoverRailsUseEachSectionsOwnMediumAndAreHonestWhenEmpty() {
        let movie = media(.movie), game = media(.game)
        let sections = [
            CatalogDiscoverySection(id: "a", label: "Trending movies", mediaType: .movie, items: [movie, game]),
            CatalogDiscoverySection(id: "b", label: "Games", mediaType: .game, items: [game]),
        ]
        let all = DiscoverRails.rails(sections, type: nil)
        XCTAssertEqual(all.map(\.mediaType), [.movie, .tv, .game, .book])
        XCTAssertEqual(all[0].items.map(\.mediaType), [.movie], "A game in a movie section is not shown as a movie")
        XCTAssertTrue(all[1].items.isEmpty, "Series get an empty rail, never another medium's items")
        XCTAssertEqual(DiscoverRails.rails(sections, type: .book).first?.id, "unavailable-book")
        let spotlight = DiscoverRails.spotlight(sections, type: .game)
        XCTAssertEqual(spotlight.items.map(\.mediaType), [.game])
        XCTAssertEqual(spotlight.source, "Games")
    }

    func testGenresArePerMediumAndBooksHaveNone() {
        XCTAssertEqual(GenreCatalog.forTab(nil)?.label, "TMDB movie genres")
        XCTAssertEqual(GenreCatalog.forTab(.tv)?.label, "TMDB series genres")
        XCTAssertEqual(GenreCatalog.forTab(.game)?.label, "IGDB game genres")
        XCTAssertNil(GenreCatalog.forTab(.book))
        XCTAssertEqual(GenreCatalog.genre(35, afterSwitchFrom: .movie, to: .tv), 35, "Comedy is the same TMDB genre for series")
        XCTAssertNil(GenreCatalog.genre(28, afterSwitchFrom: .movie, to: .tv), "Action is a movie-only TMDB genre")
        XCTAssertNil(GenreCatalog.genre(35, afterSwitchFrom: .movie, to: .game), "IGDB IDs mean something else")
        XCTAssertFalse(MosaicTheme.forTab(.book).contains { $0.id == "slow-burn" })
        XCTAssertEqual(MosaicTheme.forTab(nil).count, 15)
    }

    func testRecommendationSeedsComeOnlyFromLoggedWatches() throws {
        let liked = try catalog(#"{"provider":"tmdb","providerId":"1","mediaType":"movie","title":"Liked","genres":[]}"#)
        let disliked = try catalog(#"{"provider":"tmdb","providerId":"2","mediaType":"movie","title":"Disliked","genres":[]}"#)
        let series = try catalog(#"{"provider":"tmdb","providerId":"3","mediaType":"tv","title":"Series","genres":[]}"#)
        let tracked = try catalog(#"{"provider":"tmdb","providerId":"4","mediaType":"movie","title":"Tracked","genres":[]}"#)
        let fresh = try catalog(#"{"provider":"tmdb","providerId":"5","mediaType":"movie","title":"Fresh","genres":[]}"#)
        let snapshot = MosaicStateSnapshot(
            library: [.init(media: tracked, status: "watchlist")],
            ratings: [.init(mediaKey: disliked.mediaKey, value: 2)],
            movieWatches: [.init(media: liked, watchedAt: "2026-10-01"), .init(media: disliked, watchedAt: "2026-10-05"), .init(media: liked, watchedAt: "2026-09-01")],
            episodeWatches: [.init(series: series, watchedAt: "2026-10-03T00:00:00.000Z")]
        )
        let seeds = Recommendations.seeds(from: snapshot, type: nil)
        XCTAssertEqual(seeds.map(\.title), ["Series", "Liked"], "Newest first, one per title, disliked excluded")
        XCTAssertTrue(Recommendations.seeds(from: snapshot, type: .game).isEmpty)
        let rows = Recommendations.build(seeds: seeds, results: [[tracked, fresh], nil], snapshot: snapshot)
        XCTAssertEqual(rows.map(\.seed.title), ["Series"])
        XCTAssertEqual(rows.first?.items.map(\.title), ["Fresh"], "Tracked titles are never recommended")
    }

    // MARK: Activity (`activityLabel`)

    func testActivityLabelsMatchTheWeb() {
        XCTAssertEqual(ActivityLabel.text(eventType: "movie_watch", repeatKind: "rewatch", targetType: "media", seasonNumber: nil, episode: nil, progressPercent: nil), "Rewatched")
        XCTAssertEqual(ActivityLabel.text(eventType: "episode_watch", repeatKind: nil, targetType: "episode", seasonNumber: nil, episode: (2, 3), progressPercent: nil), "Watched S02E03")
        XCTAssertEqual(ActivityLabel.text(eventType: "tv_watch", repeatKind: nil, targetType: "season", seasonNumber: 4, episode: nil, progressPercent: nil), "Watched season 4")
        XCTAssertEqual(ActivityLabel.text(eventType: "game_update", repeatKind: nil, targetType: nil, seasonNumber: nil, episode: nil, progressPercent: 100), "Completed playthrough")
        XCTAssertEqual(ActivityLabel.text(eventType: "book_update", repeatKind: nil, targetType: nil, seasonNumber: nil, episode: nil, progressPercent: 50), "Updated reading")
        XCTAssertEqual(ActivityLabel.text(eventType: "something_new", repeatKind: nil, targetType: nil, seasonNumber: nil, episode: nil, progressPercent: nil), "Updated", "Unknown events are not called reading")
    }

    func testListsKeepServerPositionOrder() throws {
        let response = try JSONDecoder.mosaic.decode(UserListsResponse.self, from: Data(#"{"items":[{"id":"l1","title":"Picks","description":"","visibility":"private","updatedAt":"2026-10-01T00:00:00.000Z","items":[{"id":"b","media":{"provider":"tmdb","providerId":"2","mediaType":"movie","title":"Second","genres":[]},"position":1},{"id":"a","media":{"provider":"tmdb","providerId":"1","mediaType":"tv","title":"First","genres":[]},"position":0,"note":"Start here"}]}]}"#.utf8))
        let list = try XCTUnwrap(response.items.values.first)
        XCTAssertEqual(list.orderedItems.map(\.media.title), ["First", "Second"])
        XCTAssertEqual(list.mediaTypes, [.tv, .movie])
        XCTAssertEqual(list.visibility.label, "Private")
    }

    func testLibraryStoreSkipsSavingTrackedTitles() async throws {
        var mutations: [DetailMutation] = []
        var services = MosaicServices.unavailable
        services.mutate = { mutations.append($0) }
        let store = LibraryStore()
        let tracked = try JSONDecoder.mosaic.decode(LibraryItemDTO.self, from: Data(#"{"id":"tmdb:movie:1","mediaType":"movie","provider":"tmdb","providerId":"1","title":"Arrival","status":"watched","userRating":null,"isFavorite":false,"updatedAt":"2026-09-19T10:00:00.000Z"}"#.utf8))
        store.seed([tracked])
        let outcome = try await store.saveForLater(media(.movie, id: "1"), using: services)
        XCTAssertEqual(outcome, .alreadyTracked)
        XCTAssertTrue(mutations.isEmpty, "An existing entry is never reset to watchlist")
        _ = try await store.saveForLater(media(.movie, id: "2"), using: services)
        XCTAssertEqual(mutations.map(\.type), ["library.upsert"])
    }

    // MARK: Library progress identity and watch counts

    func testLibraryEntryDecodesProgressIdWatchCountAndPlatform() throws {
        let game = try libraryEntry(#"{"id":"igdb:game:7","mediaType":"game","provider":"igdb","providerId":"7","title":"Hades","status":"playing","userRating":null,"isFavorite":false,"updatedAt":"2026-09-19T10:00:00.000Z","progressId":"play-1","progress":{"playtimeMinutes":245,"percent":40,"platform":"PC"}}"#)
        XCTAssertEqual(game.progressID, "play-1")
        XCTAssertEqual(game.progress?.platform, "PC")
        XCTAssertEqual(game.progressLine?.text, "40% · 4h 5m recorded")

        let movie = try libraryEntry(#"{"id":"tmdb:movie:1","mediaType":"movie","provider":"tmdb","providerId":"1","title":"Arrival","status":"watched","userRating":4,"isFavorite":false,"updatedAt":"2026-09-19T10:00:00.000Z","watchCount":2}"#)
        XCTAssertEqual(movie.watchCount, 2)
        XCTAssertEqual(movie.progressLine?.text, "2 watches logged")
        XCTAssertNil(movie.progressLine?.fraction, "There is no resumable movie progress to draw")
    }

    func testMovieWatchCountIsHonestForOneZeroAndMissing() throws {
        func line(_ watchCount: String) throws -> String? {
            let extra = watchCount.isEmpty ? "" : ",\"watchCount\":\(watchCount)"
            let json = "{\"id\":\"tmdb:movie:1\",\"mediaType\":\"movie\",\"provider\":\"tmdb\",\"providerId\":\"1\",\"title\":\"Arrival\",\"status\":\"watched\",\"userRating\":null,\"isFavorite\":false,\"updatedAt\":\"2026-09-19T10:00:00.000Z\"\(extra)}"
            return try libraryEntry(json).progressLine?.text
        }
        XCTAssertEqual(try line("1"), "1 watch logged")
        XCTAssertNil(try line("0"))
        XCTAssertNil(try line(""))
    }

    // MARK: Profile

    func testProfileDecodesBioRegionAndRelativeAvatar() throws {
        let user = try JSONDecoder.mosaic.decode(CurrentUser.self, from: Data(#"{"id":"u","profile":{"displayName":"Name","username":"name","avatarUrl":"/brand/mosaic/avatars/orbit.svg","bio":"Hello","watchRegion":"IN"}}"#.utf8))
        XCTAssertEqual(user.profile?.bio, "Hello")
        XCTAssertEqual(user.profile?.watchRegion, "IN")
        XCTAssertEqual(user.profile?.avatar, "/brand/mosaic/avatars/orbit.svg")
        XCTAssertNil(user.profile?.avatarURL?.scheme, "Preset paths stay relative to the web origin")
        XCTAssertEqual(AvatarPreset.name(for: user.profile?.avatar), "Orbit")
    }

    func testProfileUpdateSendsExplicitNullsToClearOptionalFields() throws {
        let data = try JSONEncoder().encode(ProfileUpdateRequest(displayName: "Name", username: "name", bio: nil, avatar: nil))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["displayName"] as? String, "Name")
        XCTAssertEqual(payload["username"] as? String, "name")
        XCTAssertTrue(payload.keys.contains("bio"))
        XCTAssertTrue(payload["bio"] is NSNull)
        XCTAssertTrue(payload.keys.contains("avatarUrl"))
        XCTAssertTrue(payload["avatarUrl"] is NSNull)
    }

    func testProfileValidationMirrorsServerRules() {
        func draft(name: String = "Name", username: String = "name", bio: String = "", avatar: String = "") -> EditProfileView.Draft {
            .init(displayName: name, username: username, bio: bio, avatar: avatar)
        }
        XCTAssertNil(EditProfileView.validate(draft()))
        XCTAssertNil(EditProfileView.validate(draft(username: "a_b1", avatar: "/brand/mosaic/avatars/orbit.svg")))
        XCTAssertNil(EditProfileView.validate(draft(avatar: "https://example.com/me.jpg")))
        XCTAssertNotNil(EditProfileView.validate(draft(name: "  ")))
        XCTAssertNotNil(EditProfileView.validate(draft(name: String(repeating: "a", count: 81))))
        XCTAssertNotNil(EditProfileView.validate(draft(username: "ab")))
        XCTAssertNotNil(EditProfileView.validate(draft(username: "Name")))
        XCTAssertNotNil(EditProfileView.validate(draft(bio: String(repeating: "a", count: 501))))
        XCTAssertNotNil(EditProfileView.validate(draft(avatar: "http://example.com/me.jpg")))
        XCTAssertNotNil(EditProfileView.validate(draft(avatar: "not a url")))
    }

    // MARK: Watch region

    func testWatchRegionMutationIsNotMediaScoped() throws {
        let payload = try encode(.watchRegion("IN"))
        XCTAssertEqual(payload["type"] as? String, "settings.watchRegion")
        XCTAssertEqual(payload["value"] as? String, "IN")
        XCTAssertNil(payload["media"])
        let cleared = try encode(.watchRegion(nil))
        XCTAssertTrue(cleared.keys.contains("value"))
        XCTAssertTrue(cleared["value"] is NSNull)
        XCTAssertEqual(WatchRegion.label(for: "IN"), "India (IN)")
        XCTAssertEqual(WatchRegion.label(for: nil), "Not set")
    }

    // MARK: Helpers

    private func media(_ type: CatalogMediaType, id: String = "1") -> CatalogMedia {
        let extra = type == .game ? #","platforms":[]"# : type == .book ? #","authors":[]"# : ""
        return try! catalog(#"{"provider":"tmdb","providerId":"\#(id)","mediaType":"\#(type.rawValue)","title":"Title","genres":[]\#(extra)}"#)
    }
    private func catalog(_ json: String) throws -> CatalogMedia { try JSONDecoder.mosaic.decode(CatalogMedia.self, from: Data(json.utf8)) }
    private func libraryEntry(_ json: String) throws -> LibraryItemDTO { try JSONDecoder.mosaic.decode(LibraryItemDTO.self, from: Data(json.utf8)) }
    private func json(_ media: CatalogMedia) -> String { String(decoding: try! JSONEncoder().encode(media), as: UTF8.self) }
    private func encode(_ mutation: DetailMutation) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(mutation)) as? [String: Any])
    }
}

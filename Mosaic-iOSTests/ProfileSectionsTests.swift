import XCTest
@testable import Mosaic_iOS

final class ProfileSectionsTests: XCTestCase {
    func testMetricsCountLogsAndUniqueNonRewatchEpisodes() throws {
        let movie = try media(.movie)
        let series = try media(.tv)
        let otherSeries = try media(.tv, id: "other")
        let game = try media(.game)
        let book = try media(.book)
        let snapshot = MosaicStateSnapshot(
            movieWatches: [
                .init(media: movie, watchedAt: "2026-01-01"),
                .init(media: movie, watchedAt: "2026-02-01", isRewatch: true)
            ],
            episodeWatches: [
                .init(series: series, watchedAt: "2026-01-01", seasonNumber: 1, episodeNumber: 1),
                .init(series: series, watchedAt: "2026-01-02", seasonNumber: 1, episodeNumber: 1),
                .init(series: series, watchedAt: "2026-01-03", seasonNumber: 1, episodeNumber: 2, isRewatch: true),
                .init(series: series, watchedAt: "2026-01-04", seasonNumber: 2, episodeNumber: 1),
                .init(series: otherSeries, watchedAt: "2026-01-05", seasonNumber: 1, episodeNumber: 1)
            ],
            gamePlaythroughs: [
                .init(id: "g1", media: game, status: "completed", platform: nil, playtimeMinutes: 0, progressPercent: nil, rating: nil, updatedAt: "2026-01-01"),
                .init(id: "g2", media: game, status: "playing", platform: nil, playtimeMinutes: 0, progressPercent: nil, rating: nil, updatedAt: "2026-01-02")
            ],
            bookReadings: [
                .init(id: "b1", media: book, status: "finished", currentPage: nil, totalPages: nil, progressPercent: nil, rating: nil, updatedAt: "2026-01-01"),
                .init(id: "b2", media: book, status: "reading", currentPage: nil, totalPages: nil, progressPercent: nil, rating: nil, updatedAt: "2026-01-02")
            ])
        let metrics = ProfileSections.metrics(snapshot)
        XCTAssertEqual(metrics.map(\.value), [2, 3, 1, 1])
        XCTAssertEqual(metrics.map(\.label), ["Movies watched", "Unique episodes watched", "Games completed", "Books read"])
        XCTAssertEqual(metrics[0].artwork.map(\.mediaKey), [movie.mediaKey])
        XCTAssertEqual(metrics[1].artwork.map(\.mediaKey), [otherSeries.mediaKey, series.mediaKey])
        XCTAssertTrue(ProfileSections.metrics(MosaicStateSnapshot()).allSatisfy { $0.value == 0 && $0.artwork.isEmpty })
    }

    func testRecentArtworkIsUniqueNewestFirstAndCappedAtThree() throws {
        let movies = try (0..<5).map { try media(.movie, id: String($0)) }
        var watches = movies.enumerated().map { MosaicStateSnapshot.MovieWatch(media: $0.element, watchedAt: "2026-01-0\($0.offset + 1)") }
        watches.append(.init(media: movies[0], watchedAt: "2026-02-01", isRewatch: true))
        XCTAssertEqual(ProfileSections.metrics(.init(movieWatches: watches))[0].artwork.map(\.providerID), ["0", "4", "3"])
    }

    func testFavouritesAreGroupedAndCappedAtFive() throws {
        var rows: [MosaicStateSnapshot.LibraryRow] = []
        for type in [CatalogMediaType.movie, .tv, .game, .book] {
            for index in 0..<7 {
                rows.append(.init(media: try media(type, id: String(index)), status: "planned", isFavorite: true))
            }
            rows.insert(.init(media: try media(type, id: "not-favourite"), status: "planned"), at: 0)
        }
        let shelves = ProfileSections.favourites(.init(library: rows))
        XCTAssertEqual(shelves.map(\.title), ["Favourite movies", "Favourite series", "Favourite games", "Favourite books"])
        for shelf in shelves {
            XCTAssertEqual(shelf.items.map(\.providerID), ["0", "1", "2", "3", "4"])
            XCTAssertTrue(shelf.items.allSatisfy { $0.mediaType == shelf.type })
        }
        XCTAssertTrue(ProfileSections.favourites(.init()).isEmpty)
    }

    func testCollectionLineVariants() {
        XCTAssertNil(ProfileSections.collectionLine(nil))
        XCTAssertNil(ProfileSections.collectionLine(mosaic(count: 0)))
        XCTAssertEqual(ProfileSections.collectionLine(mosaic(count: 1)), "1 story logged")
        XCTAssertEqual(ProfileSections.collectionLine(mosaic(count: 3, series: 1)), "3 stories logged · across 2 media")
        XCTAssertEqual(ProfileSections.collectionLine(mosaic(count: 3, series: 1, dates: ["2026-03-05T10:00:00.000Z", "2024-01-01", "invalid"])), "3 stories logged · across 2 media · earliest activity Jan 2024")
    }

    func testReviewExcerptStopsAt150CharactersAndHidesSpoilers() throws {
        let body = String(repeating: "😀", count: 151)
        XCTAssertEqual(ProfileSections.reviewExcerpt(try review(body: body)), String(body.prefix(150)))
        XCTAssertEqual(ProfileSections.reviewExcerpt(try review(body: "Short")), "Short")
        XCTAssertEqual(ProfileSections.reviewExcerpt(try review(body: "Secret", spoilers: true)), "Contains spoilers")
    }

    func testReviewsSortNewestFirst() throws {
        let reviews = try [review(id: "old", at: "2024-01-01T00:00:00Z"), review(id: "new", at: "2026-03-02T00:00:00Z"), review(id: "middle", at: "2025-01-01T00:00:00Z")]
        XCTAssertEqual(ProfileSections.sortedReviews(reviews).map(\.id), ["new", "middle", "old"])
    }

    private func media(_ type: CatalogMediaType, id: String = "1") throws -> CatalogMedia {
        let json = "{\"provider\":\"mock\",\"providerId\":\"\(id)\",\"mediaType\":\"\(type.rawValue)\",\"title\":\"Story \(id)\",\"genres\":[]}"
        return try JSONDecoder().decode(CatalogMedia.self, from: Data(json.utf8))
    }

    private func review(id: String = "r", body: String = "Review", spoilers: Bool = false, at: String = "2026-01-01T00:00:00Z") throws -> MosaicStateSnapshot.Review {
        .init(id: id, media: try media(.movie), body: body, containsSpoilers: spoilers, rating: 4, updatedAt: at)
    }

    private func mosaic(count: Int, series: Int = 0, dates: [String] = []) -> MosaicSnapshot {
        .init(period: .init(kind: .all, label: "All time", year: nil, month: nil), generatedAt: "2026-01-01", totals: .init(storiesRepresented: count, byMediaType: .init(movie: count, series: series, game: 0, book: 0), movieWatchLogs: count), tiles: dates.enumerated().map { index, date in
            .init(key: "mock:movie:\(index)", mediaType: .movie, providerID: String(index), title: "Story", artwork: nil, href: "", activity: .init(firstActivityAt: date, lastActivityAt: date, eventCount: 1, progress: nil, completed: nil), userSignals: .init(rating: nil, favorite: nil, rewatchCount: nil), providerMetadata: .init(year: nil, genres: nil), visualWeight: 1)
        })
    }
}

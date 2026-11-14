import XCTest
@testable import Mosaic_iOS

final class EpisodeRatingsTests: XCTestCase {
    func testLegendMatchesEveryWebLabelColorAndMinimum() {
        XCTAssertEqual(EpisodeRatingCategory.legend.map(\.rawValue), [
            "Absolute Cinema", "Awesome", "Great", "Good", "Average", "Bad", "Garbage",
        ])
        XCTAssertEqual(EpisodeRatingCategory.legend.map(\.hex), [
            0x38BDF8, 0x22C55E, 0x4ADE80, 0xFDE047, 0xF59E0B, 0xFB7185, 0xA855F7,
        ])
        XCTAssertEqual(EpisodeRatingCategory.legend.map(\.minimum), [9.7, 9, 8, 7, 6, 5, 0])
    }

    func testEveryWebCategoryCase() {
        let cases: [(Double?, EpisodeRatingCategory)] = [
            (9.7, .absoluteCinema), (9.0, .awesome), (8.0, .great), (7.0, .good),
            (6.0, .average), (5.0, .bad), (4.9, .garbage), (nil, .unrated),
        ]
        for (rating, expected) in cases {
            XCTAssertEqual(EpisodeRatingCategory.category(for: rating), expected, "Rating: \(String(describing: rating))")
        }
    }

    func testCategoriesUseRawThresholdsWithoutRoundingOrClamping() {
        let cases: [(Double, EpisodeRatingCategory)] = [
            (10, .absoluteCinema), (9.69, .awesome), (8.99, .great), (7.99, .good),
            (6.99, .average), (5.99, .bad), (4.99, .garbage), (0, .garbage),
            (-1, .garbage), (.nan, .garbage),
        ]
        for (rating, expected) in cases {
            XCTAssertEqual(EpisodeRatingCategory.category(for: rating), expected)
        }
    }

    func testFiltersEmptyAndSpecialSeasonsAndSortsBothAxes() {
        let second = [episode(season: 2, number: 3), episode(season: 2, number: 1)]
        let first = [episode(season: 1, number: 2), episode(season: 1, number: 1)]
        let input = [[], second, [episode(season: 0)], first]
        let ordered = EpisodeRatingsContent.orderedSeasons(input)
        XCTAssertEqual(ordered.map { $0[0].seasonNumber }, [1, 2])
        XCTAssertEqual(ordered.map { $0.map(\.episodeNumber) }, [[1, 2], [1, 3]])
        XCTAssertEqual(input[1].map(\.episodeNumber), [3, 1])
        XCTAssertTrue(EpisodeRatingsContent.orderedSeasons([[], [episode(season: 0)]]).isEmpty)
        XCTAssertTrue(EpisodeRatingsContent.orderedSeasons([]).isEmpty)
    }

    func testSubtitleCountsOnlyRetainedEpisodesIncludingUnrated() {
        let seasons = EpisodeRatingsContent.orderedSeasons([
            [], [episode(season: 0)], [episode(season: 3, number: 30)],
            [episode(season: 1, rating: 9.7), episode(season: 1, number: 2)],
        ])
        XCTAssertEqual(EpisodeRatingsContent.subtitle(seasons), "2 seasons · 3 episodes")
        XCTAssertEqual(EpisodeRatingsContent.subtitle([]), "0 seasons · 0 episodes")
    }

    func testAccessibilityMatchesWebWithLocalizedVoteCount() {
        XCTAssertEqual(EpisodeRatingsContent.accessibilityLabel(
            episode(season: 2, number: 3, rating: 9.7, votes: 12345), locale: Locale(identifier: "en_US")
        ), "S2E3: Celebration. Public rating 9.7 out of 10 from 12,345 votes.")
    }

    func testAccessibilityOmitsMissingAndZeroVoteCounts() {
        for count: Int? in [nil, 0] {
            XCTAssertEqual(EpisodeRatingsContent.accessibilityLabel(episode(rating: 8, votes: count)),
                           "S1E1: Celebration. Public rating 8.0 out of 10.")
        }
        XCTAssertEqual(EpisodeRatingsContent.accessibilityLabel(episode(rating: 0, votes: 1)),
                       "S1E1: Celebration. Public rating 0.0 out of 10 from 1 votes.")
    }

    func testUnratedAccessibilityAndCellText() {
        XCTAssertEqual(EpisodeRatingsContent.accessibilityLabel(episode(votes: 12)),
                       "S1E1: Celebration. Public rating unavailable.")
        XCTAssertEqual(EpisodeRatingsContent.ratingText(nil), "—")
        XCTAssertEqual(EpisodeRatingsContent.ratingText(9), "9.0")
        XCTAssertEqual(EpisodeRatingsContent.ratingText(8.34), "8.3")
    }

    private func episode(season: Int = 1, number: Int = 1, rating: Double? = nil, votes: Int? = nil) -> CatalogEpisode {
        CatalogEpisode(id: "s\(season)e\(number)", seasonNumber: season, episodeNumber: number,
                       title: "Celebration", overview: nil, stillURL: nil, airDate: nil,
                       runtimeMinutes: nil, publicRating: rating, publicRatingCount: votes)
    }
}

import SwiftUI

/// Public provider ratings only; personal ratings and watch state are excluded.
nonisolated enum EpisodeRatingCategory: String, CaseIterable {
    case absoluteCinema = "Absolute Cinema"
    case awesome = "Awesome"
    case great = "Great"
    case good = "Good"
    case average = "Average"
    case bad = "Bad"
    case garbage = "Garbage"
    case unrated = "Unrated"

    static let legend = allCases.filter { $0 != .unrated }

    var minimum: Double {
        switch self {
        case .absoluteCinema: 9.7
        case .awesome: 9
        case .great: 8
        case .good: 7
        case .average: 6
        case .bad: 5
        case .garbage, .unrated: 0
        }
    }

    var hex: UInt32 {
        switch self {
        case .absoluteCinema: 0x38BDF8
        case .awesome: 0x22C55E
        case .great: 0x4ADE80
        case .good: 0xFDE047
        case .average: 0xF59E0B
        case .bad: 0xFB7185
        case .garbage: 0xA855F7
        case .unrated: 0
        }
    }

    static func category(for rating: Double?) -> Self {
        guard let rating else { return .unrated }
        return legend.first { rating >= $0.minimum } ?? .garbage
    }
}

nonisolated enum EpisodeRatingsContent {
    static func orderedSeasons(_ seasons: [[CatalogEpisode]]) -> [[CatalogEpisode]] {
        seasons.filter { ($0.first?.seasonNumber ?? 0) > 0 }
            .map { $0.sorted { $0.episodeNumber < $1.episodeNumber } }
            .sorted { $0[0].seasonNumber < $1[0].seasonNumber }
    }

    static func subtitle(_ seasons: [[CatalogEpisode]]) -> String {
        "\(seasons.count) seasons · \(seasons.reduce(0) { $0 + $1.count }) episodes"
    }

    static func ratingText(_ rating: Double?) -> String {
        rating.map { String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "—"
    }

    static func accessibilityLabel(_ episode: CatalogEpisode, locale: Locale = .current) -> String {
        let prefix = "S\(episode.seasonNumber)E\(episode.episodeNumber): \(episode.title). "
        guard episode.publicRating != nil else { return prefix + "Public rating unavailable." }
        let votes = episode.publicRatingCount.flatMap { count in
            count == 0 ? nil : " from \(count.formatted(.number.locale(locale))) votes"
        } ?? ""
        return prefix + "Public rating \(ratingText(episode.publicRating)) out of 10\(votes)."
    }
}

struct EpisodeRatingsSection: View {
    static let isAvailable = true
    let series: CatalogMedia
    @Environment(\.mosaicServices) private var services
    @AppStorage("mosaic.episodeRatingsExpanded") private var isExpanded = false
    @State private var seasons: [[CatalogEpisode]] = []
    @ScaledMetric(relativeTo: .caption) private var cellSize = 38
    @ScaledMetric(relativeTo: .caption) private var columnHeaderHeight = 28

    var body: some View {
        Group {
            if !seasons.isEmpty {
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    header
                    if isExpanded {
                        legend
                        ratingsGrid
                    }
                }
            }
        }
        .task(id: series.route) {
            seasons = []
            do {
                let loaded = try await services.episodeRatings(series.route)
                try Task.checkCancellation()
                seasons = EpisodeRatingsContent.orderedSeasons(loaded)
            } catch {
                // Unavailable public data leaves no empty section behind.
                if !Task.isCancelled { seasons = [] }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
            MosaicEyebrow(title: "Public episode ratings")
            Text("Episode Ratings")
                .font(MosaicType.section)
                .foregroundStyle(MosaicColor.primaryText)
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack {
                    subtitle
                    Spacer(minLength: MosaicSpace.small)
                    toggle
                }
                VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                    subtitle
                    toggle
                }
            }
        }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
    }

    private var subtitle: some View {
        Text(EpisodeRatingsContent.subtitle(seasons))
            .font(MosaicType.metadata)
            .foregroundStyle(MosaicColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var toggle: some View {
        Button { isExpanded.toggle() } label: {
            Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, MosaicSpace.xSmall)
                .frame(minHeight: MosaicLayout.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MosaicColor.accent)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Shows or hides public episode ratings")
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .leading)], alignment: .leading, spacing: MosaicSpace.xSmall) {
            ForEach(EpisodeRatingCategory.legend, id: \.self) { category in
                HStack(spacing: MosaicSpace.xSmall) {
                    Circle().fill(color(category)).frame(width: 8, height: 8)
                    Text(category.rawValue).font(MosaicType.caption)
                        .foregroundStyle(MosaicColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, MosaicSpace.small)
                .padding(.vertical, MosaicSpace.xSmall)
                .background(MosaicColor.surface, in: Capsule())
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, MosaicLayout.pageHorizontal)
        .accessibilityLabel("Episode rating legend")
    }

    private var ratingsGrid: some View {
        let lastEpisode = seasons.flatMap { $0 }.map(\.episodeNumber).max() ?? 0
        return ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: MosaicSpace.xSmall) {
                VStack(spacing: MosaicSpace.xSmall) {
                    gridHeader("Ep.")
                    ForEach(1..<max(lastEpisode + 1, 1), id: \.self) { number in
                        Text("E\(number)")
                            .font(MosaicType.caption)
                            .foregroundStyle(MosaicColor.mutedText)
                            .frame(width: cellSize, height: cellSize)
                            .accessibilityHidden(true)
                    }
                }
                ForEach(seasons, id: \.first?.seasonNumber) { season in
                    seasonColumn(season, lastEpisode: lastEpisode)
                }
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
        .accessibilityLabel("Public episode ratings by season")
    }

    private func gridHeader(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold))
            .foregroundStyle(MosaicColor.secondaryText)
            .frame(minWidth: cellSize, minHeight: columnHeaderHeight)
            .accessibilityAddTraits(.isHeader)
    }

    private func seasonColumn(_ season: [CatalogEpisode], lastEpisode: Int) -> some View {
        // Build each lookup once per column, rather than scanning for every row.
        let episodes = Dictionary(season.map { ($0.episodeNumber, $0) }, uniquingKeysWith: { first, _ in first })
        return VStack(spacing: MosaicSpace.xSmall) {
            gridHeader("S\(season[0].seasonNumber)")
            ForEach(1..<max(lastEpisode + 1, 1), id: \.self) { number in
                if let episode = episodes[number] {
                    ratingCell(episode)
                } else {
                    Color.clear.frame(width: cellSize, height: cellSize).accessibilityHidden(true)
                }
            }
        }
    }

    private func ratingCell(_ episode: CatalogEpisode) -> some View {
        let category = EpisodeRatingCategory.category(for: episode.publicRating)
        return NavigationLink(value: MosaicRoute.season(series, episode.seasonNumber)) {
            Text(EpisodeRatingsContent.ratingText(episode.publicRating))
                .font(.caption.weight(.bold)).monospacedDigit()
                .foregroundStyle(category == .unrated ? MosaicColor.secondaryText : MosaicColor.onLight)
                .frame(width: cellSize, height: cellSize)
                .background(color(category), in: RoundedRectangle(cornerRadius: MosaicRadius.small))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(EpisodeRatingsContent.accessibilityLabel(episode))
        .accessibilityHint("Opens the season episode guide")
    }

    private func color(_ category: EpisodeRatingCategory) -> Color {
        guard category != .unrated else { return MosaicColor.surface }
        let hex = category.hex
        return Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                     green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

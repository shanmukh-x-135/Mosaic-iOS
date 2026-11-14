import SwiftUI
import Charts

/// Presentation only: counts, populations and dated buckets come from the server.
nonisolated enum StatsCopy {
    static func periods(_ years: [Int]) -> [String] { ["all"] + Set(years).sorted(by: >).map(String.init) }
    static func periodTitle(_ value: String) -> String { value == "all" ? "All time" : value }
    static func periodLabel(_ period: StatsPeriod) -> String {
        period.kind == .year ? "in \(period.year.map(String.init) ?? "")" : "so far"
    }
    static func populationNote(_ population: ProfileStats.Ratings.Population, period: StatsPeriod) -> String {
        population == .all ? "every title you have rated" : "rated films and series you logged \(periodLabel(period))"
    }
    static func quiet(unit: String, period: StatsPeriod) -> String { "No \(unit) recorded \(periodLabel(period))." }
    static func average(_ value: Double?) -> String? {
        value.flatMap { $0.isFinite ? String(format: "★ %.1f", locale: Locale(identifier: "en_US"), $0) : nil }
    }
    static let weekdayLabels = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static func weekdays(_ counts: [Int]) -> [(label: String, count: Int)] {
        weekdayLabels.enumerated().map { ($0.element, counts.indices.contains($0.offset) ? counts[$0.offset] : 0) }
    }
    static func mediumTitle(_ medium: CatalogMediaType) -> String {
        switch medium { case .movie: "Movies"; case .tv: "Series"; case .game: "Games"; case .book: "Books" }
    }
    static func unit(_ count: Int, medium: CatalogMediaType) -> String {
        switch medium {
        case .movie: count == 1 ? "film watch" : "film watches"
        case .tv: count == 1 ? "episode logged" : "episodes logged"
        case .game: count == 1 ? "playthrough completed" : "playthroughs completed"
        case .book: count == 1 ? "book finished" : "books finished"
        }
    }
    static func isEmpty(_ s: ProfileStats) -> Bool {
        let statuses = [s.series.status.watching, s.series.status.paused, s.series.status.completed, s.series.status.dropped, s.series.status.watchlist,
                        s.game.statuses.playing, s.game.statuses.paused, s.game.statuses.completed, s.game.statuses.dropped, s.game.statuses.backlog,
                        s.book.statuses.reading, s.book.statuses.paused, s.book.statuses.finished, s.book.statuses.dnf, s.book.statuses.wantToRead]
        return statuses.allSatisfy { $0 == 0 } && s.movie.watchLogs == 0 && s.series.episodeLogs == 0
            && s.game.completedPlaythroughs == 0 && s.game.recordedPlaytimeMinutes == 0 && s.book.finished == 0 && s.ratings.count == 0
            && [s.genres.movie, s.genres.series, s.genres.game, s.genres.book].allSatisfy { $0.titles == 0 }
    }
}

struct StatsView: View {
    static let isAvailable = true
    @Environment(\.mosaicServices) private var services
    @State private var period = "all"
    @State private var years: [Int] = []
    @State private var response = Loadable<ProfileStatsResponse>.idle

    var body: some View {
        VStack(spacing: 0) {
            Picker("Period", selection: $period) {
                ForEach(StatsCopy.periods(years), id: \.self) { Text(StatsCopy.periodTitle($0)).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(MosaicColor.accent)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, MosaicSpace.medium)
            Group {
                switch response {
                case .idle, .loading:
                    ProgressView("Loading your stats").frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .failed(error):
                    MosaicStateMessage(title: MosaicErrorCopy.title(for: error, subject: "your statistics"), message: MosaicErrorCopy.message(for: error), systemImage: "exclamationmark.triangle", actionTitle: "Try again") {
                        Task { await load(period) }
                    }.frame(maxHeight: .infinity)
                case let .loaded(value):
                    StatsContent(stats: value.stats)
                }
            }
        }
        .background(MosaicColor.background)
        .navigationTitle("Stats")
        .toolbar(.hidden, for: .tabBar)
        .task(id: period) { await load(period) }
        .refreshable { await load(period) }
    }

    private func load(_ requested: String) async {
        response = .loading
        do {
            let value = try await services.profileStats(requested)
            try Task.checkCancellation()
            guard requested == period else { return }
            years = value.years
            if requested != "all", !years.contains(where: { String($0) == requested }) {
                period = "all"
                return
            }
            response = .loaded(value)
        } catch is CancellationError {
        } catch {
            guard requested == period, !Task.isCancelled else { return }
            response = .failed(error)
        }
    }
}

private struct StatsContent: View {
    let stats: ProfileStats

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: MosaicLayout.sectionSpacing) {
                intro
                if StatsCopy.isEmpty(stats) {
                    MosaicStateMessage(title: "No stats yet", message: "Your stats appear here as you log what you watch, play and read.", systemImage: "chart.bar")
                }
                footprint
                StatsActivity(series: stats.activity.movie, period: stats.period, medium: .movie)
                StatsActivity(series: stats.activity.series, period: stats.period, medium: .tv)
                note("Games and books keep their latest progress rather than dated sessions, so they are not charted over time.")
                ratings
                genres
                details
            }
            .padding(.horizontal, MosaicSpace.medium)
        }
        .foregroundStyle(MosaicColor.primaryText)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            Text(stats.period.kind == .year ? "\(stats.period.year.map(String.init) ?? ""), in stories" : "Your story, in numbers").font(MosaicType.title)
            let parts = [stats.movie.watchLogs > 0 ? Plural.count(stats.movie.watchLogs, "film watch", "film watches") : nil,
                         stats.series.episodeLogs > 0 ? "\(Plural.count(stats.series.episodeLogs, "episode")) logged" : nil].compactMap { $0 }
            if !parts.isEmpty {
                note("\(parts.joined(separator: " and ")) \(StatsCopy.periodLabel(stats.period)). Games and books are shown as they stand today.")
            } else {
                note(stats.period.kind == .year ? "Nothing dated was logged \(StatsCopy.periodLabel(stats.period))." : "Your stats appear here as you log what you watch, play and read.")
            }
        }
    }

    private var footprint: some View {
        StatsSection("Your media footprint") {
            footprintRow(.movie, count: stats.movie.watchLogs, facts: [Plural.count(stats.movie.uniqueTitles, "unique film"), Plural.count(stats.movie.rewatchLogs, "rewatch", "rewatches")])
            posters("Recent films", items: stats.movie.recent.map { ($0, "") })
            Divider()
            footprintRow(.tv, count: stats.series.episodeLogs, facts: [Plural.count(stats.series.uniqueEpisodes, "unique episode"), Plural.count(stats.series.shows, "show")])
            posters("Recent series", items: stats.series.recent.map { ($0, "") })
            Divider()
            footprintRow(.game, count: stats.game.completedPlaythroughs, facts: ["\(stats.game.statuses.playing) playing now", "\(MosaicDuration.playtime(stats.game.recordedPlaytimeMinutes)) recorded playtime"])
            posters("Completed games", items: stats.game.completed.map { ($0, "Completed") })
            Divider()
            footprintRow(.book, count: stats.book.finished, facts: ["\(stats.book.statuses.reading) reading now", "\(stats.book.statuses.dnf) did not finish"])
            posters("Finished books", items: stats.book.finishedTitles.map { ($0, "Finished") })
        }
    }

    private func footprintRow(_ medium: CatalogMediaType, count: Int, facts: [String]) -> some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
            Text(StatsCopy.mediumTitle(medium)).font(.headline).foregroundStyle(medium.accent)
            if stats.period.kind == .year && (medium == .game || medium == .book) { note("Current status") }
            Text("\(count.formatted()) \(StatsCopy.unit(count, medium: medium))").font(.title3.weight(.semibold)).monospacedDigit()
            ForEach(facts, id: \.self) { note($0) }
        }
    }

    private var ratings: some View {
        StatsSection("How you rate") {
            if stats.ratings.count == 0 {
                note(stats.period.kind == .year ? "None of the films or series you logged \(StatsCopy.periodLabel(stats.period)) are rated yet." : "Rate a story from its page and your rating pattern will appear here.")
            } else {
                if let average = StatsCopy.average(stats.ratings.average) { Text(average).font(MosaicType.title).foregroundStyle(MosaicColor.rating) }
                note("\(StatsCopy.average(stats.ratings.average) == nil ? "" : "average across ")\(Plural.count(stats.ratings.count, "rating")) · \(StatsCopy.populationNote(stats.ratings.population, period: stats.period))")
                Chart {
                    ForEach(UserRating.options, id: \.self) { value in
                        let count = stats.ratings.distribution.first { $0.value == value }?.count ?? 0
                        BarMark(x: .value("Stars", value), y: .value("Ratings", count), width: .ratio(0.8))
                            .foregroundStyle(MosaicColor.rating)
                    }
                }
                .chartXScale(domain: 0.25...5.25)
                .chartXAxis { AxisMarks(values: [1.0, 2.0, 3.0, 4.0, 5.0]) }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rating distribution. " + UserRating.options.map { value in
                    "\(StatsCopy.average(value) ?? ""): \(stats.ratings.distribution.first { $0.value == value }?.count ?? 0) ratings"
                }.joined(separator: "; "))
                ratingRow(.movie, stats.ratings.byMedium.movie)
                ratingRow(.tv, stats.ratings.byMedium.series)
                ratingRow(.game, stats.ratings.byMedium.game)
                ratingRow(.book, stats.ratings.byMedium.book)
                if stats.ratings.count < 3 { note("A few more ratings will make this pattern meaningful.") }
            }
            posters("Highest rated titles", items: stats.ratings.top.prefix(6).map { ($0.media, StatsCopy.average($0.value) ?? "") })
        }
    }

    @ViewBuilder private func ratingRow(_ medium: CatalogMediaType, _ rating: ProfileStats.RatingCount) -> some View {
        if rating.count > 0 {
            LabeledContent {
                Text([StatsCopy.average(rating.average), Plural.count(rating.count, "rating")].compactMap { $0 }.joined(separator: " · ")).monospacedDigit()
            } label: { Text(StatsCopy.mediumTitle(medium)).foregroundStyle(medium.accent) }
            .font(.subheadline)
        }
    }

    private var genres: some View {
        StatsSection("What you gravitate to") {
            genre(.movie, stats.genres.movie)
            genre(.tv, stats.genres.series)
            genre(.game, stats.genres.game)
            genre(.book, stats.genres.book)
        }
    }

    @ViewBuilder private func genre(_ medium: CatalogMediaType, _ summary: ProfileStats.Genre) -> some View {
        if summary.titles > 0 {
            Text(StatsCopy.mediumTitle(medium)).font(.headline).foregroundStyle(medium.accent)
            if summary.top.isEmpty { note("None of these \(StatsCopy.mediumTitle(medium).lowercased()) include genre information yet.") }
            ForEach(summary.top, id: \.name) { item in
                LabeledContent(item.name, value: Plural.count(item.count, "title")).font(.subheadline)
            }
            let scope = medium == .movie || medium == .tv ? (stats.period.kind == .year ? " logged \(StatsCopy.periodLabel(stats.period))" : " you have logged") : " you track"
            note("Counted once per title\(scope); \(summary.withGenres) of \(Plural.count(summary.titles, "title")) include genre data from the catalog.")
        }
    }

    private var details: some View {
        StatsSection("The details") {
            let s = stats.series.status
            statusRows(.tv, caption: "Right now · \(Plural.count(s.watching + s.paused + s.completed + s.dropped + s.watchlist, "show"))", values: [(.watching, s.watching), (.paused, s.paused), (.completed, s.completed), (.dropped, s.dropped), (.watchlist, s.watchlist)])
            posters("Most logged \(StatsCopy.periodLabel(stats.period))", items: stats.series.mostLogged.prefix(6).map { ($0.media, Plural.count($0.count, "episode log")) })
            Divider()
            let g = stats.game.statuses
            statusRows(.game, caption: "Playthroughs by status · current", values: [(.playing, g.playing), (.paused, g.paused), (.completed, g.completed), (.dropped, g.dropped), (.backlog, g.backlog)])
            if stats.game.recordedPlaytimeMinutes > 0 { note("\(MosaicDuration.playtime(stats.game.recordedPlaytimeMinutes)) playtime you have recorded, all time") }
            Divider()
            let b = stats.book.statuses
            statusRows(.book, caption: "Reading records by status · current", values: [(.reading, b.reading), (.paused, b.paused), (.finished, b.finished), (.dnf, b.dnf), (.wantToRead, b.wantToRead)])
            if !stats.book.authors.isEmpty {
                Text("Most read authors").font(.headline)
                ForEach(stats.book.authors, id: \.name) { author in
                    LabeledContent(author.name, value: Plural.count(author.count, "book")).font(.subheadline)
                }
            }
            if let film = stats.movie.mostRewatched {
                posters("Most revisited film", items: [(film.media, "\(Plural.count(film.count, "rewatch", "rewatches")) logged \(StatsCopy.periodLabel(stats.period))")])
            }
        }
    }

    private func statusRows(_ medium: CatalogMediaType, caption: String, values: [(LibraryStatus, Int)]) -> some View {
        VStack(alignment: .leading, spacing: MosaicSpace.small) {
            Text(StatsCopy.mediumTitle(medium)).font(.headline).foregroundStyle(medium.accent)
            note(caption)
            if values.allSatisfy({ $0.1 == 0 }) { note("No \(StatsCopy.mediumTitle(medium).lowercased()) tracked yet.") }
            ForEach(values.filter { $0.1 > 0 }, id: \.0) { status, count in
                LabeledContent(status.label, value: count.formatted()).font(.subheadline)
            }
        }
    }

    @ViewBuilder private func posters(_ title: String, items: [(CatalogMedia, String)]) -> some View {
        if !items.isEmpty {
            Text(title).font(.subheadline.weight(.semibold))
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: MosaicSpace.medium) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        NavigationLink(value: MosaicRoute.media(item.0)) {
                            MosaicPosterCard(summary: MosaicMediaSummary(title: item.0.title, mediaType: item.0.mediaType, posterURL: item.0.posterURL, backdropURL: item.0.backdropURL, subtitle: item.1.isEmpty ? nil : item.1))
                        }.buttonStyle(.plain)
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }

    private func note(_ text: String) -> some View { Text(text).font(.footnote).foregroundStyle(MosaicColor.secondaryText).fixedSize(horizontal: false, vertical: true) }
}

private struct StatsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.medium) {
            Text(title).font(MosaicType.section).accessibilityAddTraits(.isHeader)
            content
        }
    }
}

private struct StatsActivity: View {
    let series: ActivitySeries
    let period: StatsPeriod
    let medium: CatalogMediaType

    var body: some View {
        StatsSection(medium == .movie ? "When you watched · Films" : "When you watched · Episodes") {
            if series.total == 0 {
                Text(StatsCopy.quiet(unit: series.unit, period: period)).font(.footnote).foregroundStyle(MosaicColor.secondaryText)
            } else {
                Chart(series.buckets, id: \.key) { bucket in
                    BarMark(x: .value("Period", bucket.key), y: .value(series.unit, bucket.count))
                        .foregroundStyle(bucket.key == series.peak?.key ? medium.accent : medium.accent.opacity(0.45))
                }
                .chartXAxis {
                    AxisMarks(values: series.buckets.enumerated().filter { $0.offset % max(1, Int(ceil(Double(series.buckets.count) / 6))) == 0 }.map { $0.element.key }) { value in
                        AxisValueLabel {
                            if let key = value.as(String.self), let bucket = series.buckets.first(where: { $0.key == key }) { Text(bucket.label) }
                        }
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(series.unit) by \(series.granularity.rawValue), \(StatsCopy.periodLabel(period)). " + series.buckets.map { "\($0.label): \($0.count)" }.joined(separator: "; "))
                if let peak = series.peak {
                    Text("Busiest \(series.granularity.rawValue): \(peak.label) · \(peak.count) \(StatsCopy.unit(peak.count, medium: medium))").font(.footnote)
                }
                weekdayChart
            }
        }
    }

    private var weekdayChart: some View {
        let days = StatsCopy.weekdays(series.weekdays)
        let total = days.reduce(0) { $0 + $1.count }
        let peak = days.max { $0.count < $1.count }?.count ?? 0
        return VStack(alignment: .leading, spacing: MosaicSpace.small) {
            Text("By weekday · UTC").font(.subheadline.weight(.semibold))
            Chart(days, id: \.label) { day in
                BarMark(x: .value("Weekday", day.label), y: .value(series.unit, day.count))
                    .foregroundStyle(day.count == peak ? medium.accent : medium.accent.opacity(0.45))
            }
            .chartXAxis { AxisMarks { value in AxisValueLabel { if let day = value.as(String.self) { Text(String(day.prefix(3))) } } } }
            .frame(height: 140)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Weekday counts in UTC. " + days.map { "\($0.label): \($0.count)" }.joined(separator: "; "))
            if total >= 5, let busiest = days.first(where: { $0.count == peak }) {
                Text("Most active day: \(busiest.label) · \(Int((Double(peak) / Double(total) * 100).rounded()))% of \(series.unit)").font(.footnote)
            }
        }
    }
}

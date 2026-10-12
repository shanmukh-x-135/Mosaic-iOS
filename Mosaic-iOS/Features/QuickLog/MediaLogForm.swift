import SwiftUI

/// The medium-specific logging form shared by detail screens and Quick Log.
/// Games and books edit the user's existing playthrough/reading (the most
/// recently updated one) and start from its saved values, so an update never
/// creates a duplicate record or silently clears playtime or a rating.
struct MediaLogForm: View {
    let media: CatalogMedia
    var onSaved: () -> Void = {}
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var records = Loadable<MosaicStateSnapshot>.idle
    @State private var seriesState: SeriesPersonalState?
    @State private var draft = Draft()
    @State private var isSaving = false
    @State private var failure: String?

    static func actionTitle(for mediaType: CatalogMediaType) -> String {
        switch mediaType {
        case .movie: "Log a watch"
        case .tv: "Log an episode"
        case .game: "Update playthrough"
        case .book: "Update reading"
        }
    }

    struct Draft: Equatable {
        var date = Date.now
        var isRewatch = false
        var rating: Double?
        var review = ""
        var status = ""
        var platform = ""
        var playtimeHours = ""
        var percent = ""
        var currentPage = ""
        var totalPages = ""
        var season = 1
        var episode = 1
        var playthroughID: String?
        var readingID: String?
    }

    var body: some View {
        Form {
            Section {
                MosaicMediaRow(summary: MosaicMediaSummary(media), lines: [media.resultMetadata].filter { !$0.isEmpty }, thumbnailWidth: 44)
                    .listRowBackground(MosaicColor.elevated)
            }
            if needsRecords, records.isLoading {
                Section { HStack { ProgressView(); Text("Loading your saved progress…").foregroundStyle(MosaicColor.secondaryText) } }
            } else {
                fields
            }
            if let message = validationMessage { Section { MosaicNotice(text: message, tone: .failure) } }
            if let failure { Section { MosaicNotice(text: failure, tone: .failure) } }
        }
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle(Self.actionTitle(for: media.mediaType))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save", action: save).disabled(!canSave)
            }
        }
        .task { await prepare() }
        .presentationDetents([.large])
    }

    private var canSave: Bool {
        if isSaving || validationMessage != nil { return false }
        if needsRecords, records.value == nil { return false }
        return true
    }

    private var needsRecords: Bool { media.mediaType == .game || media.mediaType == .book }

    @ViewBuilder private var fields: some View {
        switch media.mediaType {
        case .movie:
            Section("When") {
                DatePicker("Watched on", selection: $draft.date, in: ...Date.now, displayedComponents: .date)
                Toggle("Rewatch", isOn: $draft.isRewatch)
            }
            ratingSection
            Section("Review") { TextField("Optional", text: $draft.review, axis: .vertical).lineLimit(3...6) }
        case .tv:
            Section("Episode") {
                Picker("Season", selection: $draft.season) { ForEach(seasons, id: \.self) { Text("Season \($0)").tag($0) } }
                Picker("Episode", selection: $draft.episode) {
                    ForEach(1...max(episodeCount(for: draft.season), 1), id: \.self) { number in
                        Text(episodeLabel(season: draft.season, episode: number)).tag(number)
                    }
                }
                DatePicker("Watched on", selection: $draft.date, in: ...Date.now, displayedComponents: [.date])
            }
            .onChange(of: draft.season) { _, season in draft.episode = min(draft.episode, max(episodeCount(for: season), 1)) }
            ratingSection
        case .game:
            Section {
                statusPicker
                TextField("Platform (optional)", text: $draft.platform)
                LabeledContent("Hours played") { TextField("0", text: $draft.playtimeHours).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Completion %") { TextField("Not recorded", text: $draft.percent).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            } header: { Text("Playthrough") } footer: { Text(draft.playthroughID == nil ? "Saving starts your first playthrough of this game." : "Updates your current playthrough.") }
            ratingSection
        case .book:
            Section {
                statusPicker
                LabeledContent("Current page") { TextField("—", text: $draft.currentPage).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                LabeledContent("Total pages") { TextField("Unknown", text: $draft.totalPages).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                if Int(draft.totalPages) == nil {
                    LabeledContent("Progress %") { TextField("Not recorded", text: $draft.percent).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
            } header: { Text("Reading") } footer: { Text(draft.readingID == nil ? "Saving starts your first reading of this book." : "Updates your current reading. A finished book is recorded as 100%.") }
            ratingSection
        }
    }

    private var statusPicker: some View {
        Picker("Status", selection: $draft.status) {
            ForEach(LibraryStatus.statuses(for: media.mediaType), id: \.self) { Text($0.label).tag($0.rawValue) }
        }
    }

    private var ratingSection: some View {
        Section("Your rating") {
            Picker("Rating", selection: $draft.rating) {
                Text("No rating").tag(Double?.none)
                ForEach(UserRating.options.reversed(), id: \.self) { Text("\(UserRating.format($0)) ★").tag(Optional($0)) }
            }
        }
    }

    // MARK: Series helpers

    private var seasons: [Int] {
        let declared = (media.seasonNumbers ?? Array(1...max(media.seasonCount ?? 1, 1))).filter { $0 > 0 }.sorted()
        return declared.isEmpty ? [1] : declared
    }
    private func episodeCount(for season: Int) -> Int {
        (media.eligibleEpisodeCounts ?? media.seasonEpisodeCounts)?[String(season)] ?? (seasons.count == 1 ? media.episodeCount ?? 1 : 1)
    }
    private func episodeLabel(season: Int, episode: Int) -> String {
        let watched = seriesState?.watchedCoordinates.contains("\(season):\(episode)") == true
        return "Episode \(episode)\(watched ? " · watched" : "")"
    }

    // MARK: Validation and saving

    var validationMessage: String? { Self.validate(draft, mediaType: media.mediaType) }

    static func validate(_ draft: Draft, mediaType: CatalogMediaType) -> String? {
        func number(_ text: String) -> Double? { Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
        let trimmedPercent = draft.percent.trimmingCharacters(in: .whitespaces)
        if !trimmedPercent.isEmpty { guard let value = number(trimmedPercent), (0...100).contains(value) else { return "Completion must be between 0 and 100%." } }
        switch mediaType {
        case .game:
            let hours = draft.playtimeHours.trimmingCharacters(in: .whitespaces)
            if !hours.isEmpty, (number(hours) ?? -1) < 0 { return "Hours played must be zero or more." }
        case .book:
            let current = draft.currentPage.trimmingCharacters(in: .whitespaces), total = draft.totalPages.trimmingCharacters(in: .whitespaces)
            if !current.isEmpty, (Int(current) ?? -1) < 0 { return "Current page must be a whole number." }
            if !total.isEmpty, (Int(total) ?? 0) <= 0 { return "Total pages must be a positive whole number." }
            if let page = Int(current), let pages = Int(total), page > pages { return "Current page cannot exceed total pages." }
        case .movie, .tv:
            break
        }
        return nil
    }

    static func mutation(for draft: Draft, media: CatalogMedia) -> DetailMutation {
        func number(_ text: String) -> Double? { Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
        switch media.mediaType {
        case .movie:
            let review = draft.review.trimmingCharacters(in: .whitespacesAndNewlines)
            return .movieLog(media, watchedAt: draft.date, isRewatch: draft.isRewatch, rating: draft.rating, review: review.isEmpty ? nil : review)
        case .tv:
            return .episodeLog(media, season: draft.season, episode: draft.episode, watchedAt: draft.date, rating: draft.rating)
        case .game:
            let minutes = number(draft.playtimeHours).map { Int(($0 * 60).rounded()) } ?? 0
            let platform = draft.platform.trimmingCharacters(in: .whitespaces)
            return .game(media, playthroughID: draft.playthroughID, status: draft.status, platform: platform.isEmpty ? nil : platform, playtimeMinutes: minutes, percent: number(draft.percent), rating: draft.rating)
        case .book:
            let total = Int(draft.totalPages)
            return .book(media, readingID: draft.readingID, status: draft.status, currentPage: Int(draft.currentPage), totalPages: total, percent: total == nil ? number(draft.percent) : nil, rating: draft.rating)
        }
    }

    /// The starting draft: an existing record's values, or the medium's defaults.
    static func initialDraft(media: CatalogMedia, snapshot: MosaicStateSnapshot?, libraryStatus: String?, seriesState: SeriesPersonalState?) -> Draft {
        var draft = Draft()
        func text(_ value: Double?) -> String { value.map { $0.formatted(.number.precision(.fractionLength(0...1)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))) } ?? "" }
        switch media.mediaType {
        case .movie:
            draft.isRewatch = libraryStatus == LibraryStatus.watched.rawValue
        case .tv:
            if let next = SeriesProgress.nextEpisode(media: media, watched: seriesState?.watchedCoordinates ?? []) { draft.season = next.season; draft.episode = next.episode }
        case .game:
            if let record = snapshot?.playthrough(for: media) {
                draft.playthroughID = record.id; draft.status = record.status; draft.platform = record.platform ?? ""
                // Two decimals of an hour (≤ 0.3 min) always round back to the stored minute.
                draft.playtimeHours = record.playtimeMinutes > 0 ? (Double(record.playtimeMinutes) / 60).formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))) : ""
                draft.percent = text(record.progressPercent); draft.rating = record.rating
            } else {
                draft.status = libraryStatus.flatMap { LibraryStatus(rawValue: $0)?.applies(to: .game) == true ? $0 : nil } ?? LibraryStatus.playing.rawValue
            }
        case .book:
            if let record = snapshot?.reading(for: media) {
                draft.readingID = record.id; draft.status = record.status
                draft.currentPage = record.currentPage.map(String.init) ?? ""
                draft.totalPages = (record.totalPages ?? media.pageCount).map(String.init) ?? ""
                draft.percent = text(record.progressPercent); draft.rating = record.rating
            } else {
                draft.status = libraryStatus.flatMap { LibraryStatus(rawValue: $0)?.applies(to: .book) == true ? $0 : nil } ?? LibraryStatus.reading.rawValue
                draft.totalPages = media.pageCount.map(String.init) ?? ""
            }
        }
        return draft
    }

    private func prepare() async {
        guard case .idle = records else { return }
        let libraryStatus = (try? await services.library())?.first { $0.mediaKey == media.mediaKey }?.status
        if media.mediaType == .tv { seriesState = try? await services.seriesState(media.route) }
        if needsRecords {
            records = .loading
            do { records = .loaded(try await services.stateSnapshot()) }
            catch { records = .failed(error); failure = "Your saved progress couldn’t be loaded, so saving now would start a new record. Close and try again." }
        } else {
            records = .loaded(MosaicStateSnapshot())
        }
        draft = Self.initialDraft(media: media, snapshot: records.value, libraryStatus: libraryStatus, seriesState: seriesState)
    }

    private func save() {
        // Never fall back to creating a new record when the existing one couldn't be read.
        if needsRecords, case .failed = records { return }
        isSaving = true; failure = nil
        Task {
            do {
                try await services.mutate(Self.mutation(for: draft, media: media))
                onSaved()
                dismiss()
            } catch {
                failure = "Mosaic couldn’t save that. Your previous progress is unchanged. Try again."
            }
            isSaving = false
        }
    }
}

/// Next unwatched aired episode from the catalog's eligible counts.
enum SeriesProgress {
    static func nextEpisode(media: CatalogMedia, watched: Set<String>) -> (season: Int, episode: Int)? {
        let counts = media.eligibleEpisodeCounts ?? media.seasonEpisodeCounts ?? [:]
        let seasons = (media.seasonNumbers ?? counts.keys.compactMap(Int.init)).filter { $0 > 0 }.sorted()
        for season in seasons {
            let count = counts[String(season)] ?? 0
            guard count > 0 else { continue }
            for episode in 1...count where !watched.contains("\(season):\(episode)") { return (season, episode) }
        }
        return nil
    }
}

import SwiftUI

/// Shared by movie detail and the activity diary. Owns its sheet navigation.
struct MovieWatchEditor: View {
    let watch: MosaicStateSnapshot.MovieWatch
    let onSaved: () -> Void
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MovieWatchDraft
    @State private var isSaving = false
    @State private var failure: String?

    init(watch: MosaicStateSnapshot.MovieWatch, onSaved: @escaping () -> Void) {
        self.watch = watch
        self.onSaved = onSaved
        _draft = State(initialValue: MovieWatchDraft(watch: watch))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Watched") {
                    DatePicker("Watched date", selection: $draft.date, displayedComponents: .date)
                        .environment(\.timeZone, MovieWatchDay.utc)
                        .environment(\.calendar, MovieWatchDay.calendar)
                    Toggle("Rewatch", isOn: $draft.isRewatch)
                }
                Section("Viewing") {
                    Picker("Viewing context", selection: $draft.viewingContext) {
                        Text("Not specified").tag(MovieViewingContext?.none)
                        ForEach(MovieViewingContext.allCases, id: \.rawValue) { context in
                            Text(context.label).tag(Optional(context))
                        }
                    }
                    if draft.viewingContext == .streaming {
                        TextField("Streaming service (optional)", text: $draft.streamingService)
                    }
                }
                Section("Your rating") {
                    Picker("Rating", selection: $draft.rating) {
                        Text("No rating").tag(Double?.none)
                        ForEach(UserRating.options.reversed(), id: \.self) {
                            Text("\(UserRating.format($0)) ★").tag(Optional($0))
                        }
                    }
                }
                Section("Review") {
                    TextField("Review (optional)", text: $draft.review, axis: .vertical).lineLimit(3...6)
                }
                if let message = draft.validationMessage {
                    Section { MosaicNotice(text: message, tone: .failure) }
                }
                if let failure { Section { MosaicNotice(text: failure, tone: .failure) } }
            }
            .disabled(isSaving)
            .scrollContentBackground(.hidden)
            .background(MosaicColor.background)
            .navigationTitle("Edit watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save", action: save)
                        .disabled(isSaving || draft.validationMessage != nil)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .presentationDetents([.large])
    }

    private func save() {
        guard !isSaving, draft.validationMessage == nil else { return }
        isSaving = true
        failure = nil
        let mutation = draft.mutation(for: watch)
        Task {
            do {
                try await services.mutate(mutation)
                onSaved()
                dismiss()
            } catch {
                failure = "Mosaic couldn’t save this watch. Try again."
            }
            isSaving = false
        }
    }
}

struct MovieWatchDraft {
    var date: Date
    var isRewatch: Bool
    var rating: Double?
    var review: String
    var viewingContext: MovieViewingContext?
    var streamingService: String

    init(watch: MosaicStateSnapshot.MovieWatch) {
        date = MovieWatchDay.parse(watch.watchedAt) ?? .now
        isRewatch = watch.isRewatch
        rating = watch.rating
        review = watch.review ?? ""
        viewingContext = watch.viewingContext.flatMap(MovieViewingContext.init(rawValue:))
        streamingService = watch.streamingService ?? ""
    }

    var validationMessage: String? {
        if review.count > 10_000 { return "Reviews must be 10,000 characters or fewer." }
        if viewingContext == .streaming, streamingService.count > 120 {
            return "Streaming service must be 120 characters or fewer."
        }
        return nil
    }

    func mutation(for watch: MosaicStateSnapshot.MovieWatch) -> DetailMutation {
        .movieUpdate(watchID: watch.id, media: watch.media,
                     watchedAt: MovieWatchDay.mutationDate(date), isRewatch: isRewatch,
                     rating: rating, review: review == (watch.review ?? "") ? watch.review : review,
                     viewingContext: viewingContext,
                     streamingService: viewingContext == .streaming ? streamingService : nil)
    }
}

/// Date-only values are parsed, displayed, and picked in Gregorian UTC.
nonisolated enum MovieWatchDay {
    static let utc = TimeZone(secondsFromGMT: 0)!
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar
    }

    static func parse(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = utc
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func display(_ value: String, locale: Locale = .current) -> String {
        guard let date = parse(value) else { return value }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = utc
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// DetailMutation's day encoder uses local time. Rebuild the UTC civil day
    /// at local noon before handing it off, rather than sending UTC midnight.
    static func mutationDate(_ date: Date, timeZone: TimeZone = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 12
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        return local.date(from: components) ?? date
    }
}

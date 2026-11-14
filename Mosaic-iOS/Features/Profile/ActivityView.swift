import SwiftUI

/// Full personal history, projected from the shared domain state.
struct ActivityView: View {
    @Environment(\.mosaicServices) private var services
    @Environment(PersonalStateStore.self) private var store
    @SceneStorage("activity.medium") private var selectedMedium = ActivityProjection.Medium.all.rawValue
    @State private var isDiary: Bool
    @State private var editingEvent: ProfileActivity?
    @State private var deletingWatch: MosaicStateSnapshot.MovieWatch?
    @State private var isDeleting = false
    @State private var failure: String?

    init(startsInDiary: Bool = false) {
        _isDiary = State(initialValue: startsInDiary)
    }

    private var medium: ActivityProjection.Medium { .init(rawValue: selectedMedium) ?? .all }

    var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading your activity").frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(error):
                MosaicStateMessage(title: MosaicErrorCopy.title(for: error, subject: "your activity"), message: MosaicErrorCopy.message(for: error), systemImage: "exclamationmark.triangle", actionTitle: "Try again") { store.refresh(services) }
                    .frame(maxHeight: .infinity)
            case let .loaded(snapshot):
                history(snapshot)
            }
        }
        .background(MosaicColor.background)
        .navigationTitle(isDiary ? "Movie diary" : "Activity")
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(isDiary ? "View all activity" : "Open movie diary", systemImage: isDiary ? "clock" : "book.closed") { isDiary.toggle() }
                } label: { Label("History options", systemImage: "ellipsis.circle") }
            }
        }
        .task { store.load(services) }
        .refreshable { store.refresh(services) }
        .sheet(item: $editingEvent) { event in
            if let watch = watch(for: event) {
                MovieWatchEditor(watch: watch) { store.refresh(services) }
            }
        }
        .confirmationDialog("Delete this watch of \(deletingWatch?.media.title ?? "this movie")?", isPresented: Binding(get: { deletingWatch != nil }, set: { if !$0 { deletingWatch = nil } }), titleVisibility: .visible) {
            if let watch = deletingWatch {
                Button("Delete watch", role: .destructive) { delete(watch) }
            }
            Button("Cancel", role: .cancel) { deletingWatch = nil }
        } message: { Text("This removes the watch, rating, and review from your diary.") }
        .alert("Couldn’t delete watch", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { failure = nil }
        } message: { Text(failure ?? "") }
    }

    private func history(_ snapshot: MosaicStateSnapshot) -> some View {
        let events = ActivityProjection.filtered(ActivityProjection.project(snapshot), medium: medium, diary: isDiary)
        let watches = Dictionary(snapshot.movieWatches.map { ("movie-watch:\($0.id)", $0) }, uniquingKeysWith: { first, _ in first })
        return List {
            Section {
                Text(isDiary ? "Every movie watch, rewatch, rating, and review in one chronological record." : "A chronological record of the stories you have watched, played, and read.")
                    .font(.subheadline).foregroundStyle(MosaicColor.mutedText)
                Button(isDiary ? "View all activity →" : "Open movie diary →") { isDiary.toggle() }
                if !isDiary {
                    Picker("Activity media type", selection: $selectedMedium) {
                        ForEach(ActivityProjection.Medium.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Activity media type")
                }
            }
            .listRowBackground(Color.clear)
            if events.isEmpty {
                MosaicStateMessage(title: emptyTitle, message: "Use Quick Log to add the next moment to your Mosaic history.", systemImage: "clock")
                    .listRowBackground(Color.clear)
            }
            ForEach(groups(events), id: \.day) { group in
                Section(group.day.formatted(date: .complete, time: .omitted)) {
                    ForEach(group.events) { event in
                        if isDiary, let watch = watches[event.eventID] {
                            diaryRow(event, watch: watch)
                        } else {
                            NavigationLink(value: MosaicRoute.media(event.media)) { ActivityEventRow(event: event, showsDate: false) }
                                .listRowBackground(MosaicColor.elevated)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var emptyTitle: String {
        if isDiary { return "No movie watches yet" }
        return medium == .all ? "No activity yet" : "No \(medium.title.lowercased()) activity yet"
    }

    private func diaryRow(_ event: ProfileActivity, watch: MosaicStateSnapshot.MovieWatch) -> some View {
        NavigationLink(value: MosaicRoute.media(event.media)) {
            VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
                Text(MovieWatchDay.display(watch.watchedAt)).font(.caption).foregroundStyle(MosaicColor.mutedText)
                ActivityEventRow(event: event, showsDate: false)
                if let review = watch.review, !review.isEmpty {
                    Text(review).font(.subheadline).foregroundStyle(MosaicColor.mutedText).lineLimit(3)
                }
            }
        }
        .listRowBackground(MosaicColor.elevated)
        .contextMenu { watchActions(event, watch: watch) }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { watchActions(event, watch: watch) }
        .accessibilityAction(named: "Edit watch") { editingEvent = event }
        .accessibilityAction(named: "Delete watch") { deletingWatch = watch }
    }

    @ViewBuilder
    private func watchActions(_ event: ProfileActivity, watch: MosaicStateSnapshot.MovieWatch) -> some View {
        Button("Edit", systemImage: "pencil") { editingEvent = event }.disabled(isDeleting)
        Button("Delete", systemImage: "trash", role: .destructive) { deletingWatch = watch }.disabled(isDeleting)
    }

    private func watch(for event: ProfileActivity) -> MosaicStateSnapshot.MovieWatch? {
        store.snapshot?.movieWatches.first { "movie-watch:\($0.id)" == event.eventID }
    }

    private func delete(_ watch: MosaicStateSnapshot.MovieWatch) {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await services.mutate(.movieDelete(watchID: watch.id))
                store.refresh(services)
            } catch { failure = "Mosaic couldn’t delete this watch. Try again." }
        }
    }

    private func groups(_ items: [ProfileActivity]) -> [(day: Date, events: [ProfileActivity])] {
        var order: [Date] = [], buckets: [Date: [ProfileActivity]] = [:]
        for event in items {
            // Movie dates are civil days in UTC, including west of Greenwich.
            let calendar = Calendar.current
            let displayDate: Date
            if event.eventType == "movie_watch" {
                let civilDay = MovieWatchDay.calendar.dateComponents([.year, .month, .day], from: event.occurredAt)
                displayDate = calendar.date(from: civilDay) ?? event.occurredAt
            } else {
                displayDate = event.occurredAt
            }
            let day = calendar.startOfDay(for: displayDate)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(event)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}

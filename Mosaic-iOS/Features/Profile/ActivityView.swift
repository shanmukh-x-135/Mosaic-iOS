import SwiftUI

/// The newest 100 diary events, grouped by day. Events are server projections
/// of real logs; nothing is inferred from progress timestamps.
struct ActivityView: View {
    @Environment(\.mosaicServices) private var services
    @State private var events = Loadable<[ProfileActivity]>.idle

    var body: some View {
        Group {
            switch events {
            case .idle, .loading:
                ProgressView("Loading your activity").frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(error):
                MosaicStateMessage(title: MosaicErrorCopy.title(for: error, subject: "your activity"), message: MosaicErrorCopy.message(for: error), systemImage: "exclamationmark.triangle", actionTitle: "Try again") { Task { await load() } }
                    .frame(maxHeight: .infinity)
            case let .loaded(items) where items.isEmpty:
                MosaicStateMessage(title: "No activity yet", message: "Logged watches, episodes, playthroughs and reading updates appear here, newest first.", systemImage: "clock")
                    .frame(maxHeight: .infinity)
            case let .loaded(items):
                List {
                    ForEach(groups(items), id: \.day) { group in
                        Section(group.day.formatted(date: .complete, time: .omitted)) {
                            ForEach(group.events) { event in
                                NavigationLink(value: MosaicRoute.media(event.media)) { ActivityEventRow(event: event, showsDate: false) }
                                    .listRowBackground(MosaicColor.elevated)
                            }
                        }
                    }
                    if items.count >= 100 {
                        Text("Showing your newest 100 events.").font(.footnote).foregroundStyle(MosaicColor.mutedText).listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(MosaicColor.background)
        .navigationTitle("Activity")
        .toolbar(.hidden, for: .tabBar)
        .task { if case .idle = events { await load() } }
        .refreshable { await load() }
    }

    private func groups(_ items: [ProfileActivity]) -> [(day: Date, events: [ProfileActivity])] {
        let calendar = Calendar.current
        var order: [Date] = [], buckets: [Date: [ProfileActivity]] = [:]
        for event in items {
            let day = calendar.startOfDay(for: event.occurredAt)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(event)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    private func load() async {
        if events.value == nil { events = .loading }
        do { events = .loaded(try await services.activity(100)) } catch is CancellationError {} catch { if events.value == nil { events = .failed(error) } }
    }
}

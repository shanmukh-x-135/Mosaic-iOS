import SwiftUI

struct MovieHistorySection: View {
    static let isAvailable = true
    let media: CatalogMedia
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @State private var editing: EditingWatch?
    @State private var deleting: MosaicStateSnapshot.MovieWatch?
    @State private var isDeleting = false
    @State private var notice: (String, MosaicNotice.Tone)?

    private struct EditingWatch: Identifiable {
        let watch: MosaicStateSnapshot.MovieWatch
        var id: String { watch.id }
    }

    var body: some View {
        let watches = store.snapshot?.movieWatches(for: media) ?? []
        Group {
            if !watches.isEmpty || notice != nil {
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    if !watches.isEmpty {
                        MosaicSectionHeader("Watches", eyebrow: "Your history")
                        ForEach(watches, id: \.id) { watch in
                            HStack(alignment: .top, spacing: MosaicSpace.small) {
                                VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                                    Text(Self.dateText(watch)).font(MosaicType.cardTitle).foregroundStyle(MosaicColor.primaryText)
                                    Text(Self.detailsText(watch)).font(MosaicType.metadata).foregroundStyle(MosaicColor.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Self.accessibilityLabel(watch))
                                Menu {
                                    Button("Edit", systemImage: "pencil") { editing = EditingWatch(watch: watch) }
                                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = watch }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .frame(minWidth: MosaicLayout.minimumTouchTarget, minHeight: MosaicLayout.minimumTouchTarget)
                                }
                                .foregroundStyle(MosaicColor.accent)
                                .accessibilityLabel("Actions for \(Self.dateText(watch))")
                                .disabled(isDeleting)
                            }
                            .padding(MosaicSpace.medium)
                            .background(MosaicColor.surface, in: RoundedRectangle(cornerRadius: MosaicRadius.card))
                            .padding(.horizontal, MosaicLayout.pageHorizontal)
                        }
                    }
                    if let notice {
                        MosaicNotice(text: notice.0, tone: notice.1).padding(.horizontal, MosaicLayout.pageHorizontal)
                    }
                }
            }
        }
        .onAppear { store.load(services) }
        .sheet(item: $editing) { item in
            MovieWatchEditor(watch: item.watch) { notice = ("Watch updated.", .success) }
        }
        .confirmationDialog("Delete this watch?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            if let watch = deleting {
                Button("Delete watch", role: .destructive) { delete(watch) }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Your rating and review on this watch are removed. Other watches stay.")
        }
    }

    static func dateText(_ watch: MosaicStateSnapshot.MovieWatch, locale: Locale = .current) -> String {
        "Watched \(MovieWatchDay.display(watch.watchedAt, locale: locale))"
    }

    static func detailsText(_ watch: MosaicStateSnapshot.MovieWatch) -> String {
        let context = watch.viewingContext.map { MovieViewingContext(rawValue: $0)?.label ?? $0 }
        return [watch.isRewatch ? "Rewatch" : "First watch", context, watch.streamingService,
                watch.rating.map { "★ \(UserRating.format($0))" }]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func accessibilityLabel(_ watch: MosaicStateSnapshot.MovieWatch, locale: Locale = .current) -> String {
        [dateText(watch, locale: locale), watch.isRewatch ? "Rewatch" : "First watch",
         watch.rating.map { "Your rating \(UserRating.format($0)) out of 5" }]
            .compactMap { $0 }.joined(separator: ", ")
    }

    static func deleteMutation(for watch: MosaicStateSnapshot.MovieWatch) -> DetailMutation {
        .movieDelete(watchID: watch.id)
    }

    private func delete(_ watch: MosaicStateSnapshot.MovieWatch) {
        guard !isDeleting else { return }
        isDeleting = true
        notice = nil
        Task {
            do {
                try await services.mutate(Self.deleteMutation(for: watch))
                notice = ("Watch deleted.", .success)
            } catch {
                notice = ("Mosaic couldn’t delete this watch. Try again.", .failure)
            }
            isDeleting = false
        }
    }
}

import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(\.mosaicServices) private var services
    @State private var model = LibraryViewModel()
    @State private var inProgress: [ContinueStory] = []
    @AppStorage("mosaic.library.layout") private var layout = LibraryLayout.grid
    @State private var pendingRemoval: LibraryItemDTO?
    @State private var actionFailure: String?

    var body: some View {
        content
            .navigationTitle("Library")
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: model.mediaFilter == .all ? "Search your Library" : "Search \(model.mediaFilter.title.lowercased())")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $model.sort) { ForEach(LibrarySort.allCases) { Text($0.title).tag($0) } }
                        Picker("Layout", selection: $layout) { ForEach(LibraryLayout.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) } }
                    } label: { Label("Sort and layout", systemImage: "arrow.up.arrow.down") }
                }
                QuickLogToolbarItem()
            }
            .task { await loadInProgress() }
            .refreshable { library.refresh(services); await loadInProgress() }
            .onReceive(NotificationCenter.default.publisher(for: .mosaicStateDidChange)) { _ in Task { await loadInProgress() } }
            .confirmationDialog("Remove from Library?", isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }), titleVisibility: .visible, presenting: pendingRemoval) { item in
                Button("Remove \(item.title)", role: .destructive) { apply(.removeLibrary(media(for: item)), title: item.title) }
            } message: { _ in
                Text("Your logs, ratings and history stay in your diary.")
            }
            .alert("Couldn’t update your Library", isPresented: Binding(get: { actionFailure != nil }, set: { if !$0 { actionFailure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(actionFailure ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch library.state {
        case .idle, .loading:
            LibrarySkeleton()
        case let .failed(error):
            MosaicStateMessage(title: "Your Library couldn’t load", message: MosaicErrorCopy.message(for: error), systemImage: "books.vertical", actionTitle: "Try again") { library.refresh(services) }
        case let .loaded(items) where items.isEmpty:
            LibraryEmptyCollection()
        case let .loaded(items):
            loaded(items)
        }
    }

    private func loaded(_ items: [LibraryItemDTO]) -> some View {
        let visible = model.visibleItems(from: items)
        return MosaicScreen {
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                if let summary = LibraryViewModel.summary(of: items) {
                    Text(summary).font(.subheadline).foregroundStyle(MosaicColor.secondaryText).padding(.horizontal, MosaicLayout.pageHorizontal)
                }
                MosaicChipRow(items: LibraryMediaFilter.allCases, selection: $model.mediaFilter, title: \.title, count: { model.count(of: $0, in: items) }, tint: { $0.mediaType?.accent })
                    .accessibilityLabel("Media type")
                if !model.availableStatuses.isEmpty {
                    MosaicChipRow(items: [nil] + model.availableStatuses.map(Optional.some), selection: $model.statusFilter, title: { $0?.label ?? "Any status" }, count: { $0.map { model.count(of: $0, in: items) } })
                        .accessibilityLabel("\(model.mediaFilter.title) status")
                }
            }
            let progress = inProgress.filter { model.mediaFilter.mediaType == nil || $0.catalogMediaType == model.mediaFilter.mediaType }
            if model.statusFilter == nil && model.normalizedQuery.isEmpty && !progress.isEmpty {
                VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                    MosaicSectionHeader("In progress", eyebrow: "Keep going")
                    MosaicRail {
                        ForEach(progress) { story in
                            NavigationLink(value: MosaicRoute.media(story)) { LibraryProgressCard(story: story) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: MosaicSpace.medium) {
                MosaicSectionHeader(model.collectionTitle, eyebrow: "Collection") {
                    Text(countText(visible.count)).font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                }
                if visible.isEmpty {
                    MosaicStateMessage(title: "No matches", message: model.normalizedQuery.isEmpty ? "Nothing in your Library has this status yet." : "Nothing in this view matches “\(model.normalizedQuery)”.", systemImage: "magnifyingglass", actionTitle: "Clear filters", action: model.clearFilters)
                } else if layout == .grid {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 180), spacing: MosaicSpace.medium, alignment: .top)], spacing: MosaicSpace.large) {
                        ForEach(visible) { item in tile(item) }
                    }
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
                } else {
                    LazyVStack(spacing: MosaicSpace.medium) {
                        ForEach(visible) { item in row(item) }
                    }
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
                }
            }
        }
    }

    private func countText(_ count: Int) -> String {
        let base = "\(count) \(count == 1 ? "title" : "titles")"
        return model.normalizedQuery.isEmpty ? base : "\(base) matching “\(model.normalizedQuery)”"
    }

    private func tile(_ item: LibraryItemDTO) -> some View {
        NavigationLink(value: MosaicRoute.media(item)) {
            LibraryTile(item: item, showsMedium: model.mediaFilter == .all)
        }
        .buttonStyle(.plain)
        .contextMenu { statusMenu(item) }
    }

    private func row(_ item: LibraryItemDTO) -> some View {
        NavigationLink(value: MosaicRoute.media(item)) {
            MosaicMediaRow(summary: MosaicMediaSummary(item), lines: [[item.statusLabel, item.ratingText].compactMap { $0 }.joined(separator: " · "), item.progressLine?.text].compactMap { $0 }, showsMedium: model.mediaFilter == .all) {
                if item.isFavorite { Image(systemName: "heart.fill").foregroundStyle(MosaicColor.danger).accessibilityLabel("Favourite") }
            }
        }
        .buttonStyle(.plain)
        .contextMenu { statusMenu(item) }
    }

    /// Status changes never send `isFavorite`, so the favourite is preserved.
    @ViewBuilder private func statusMenu(_ item: LibraryItemDTO) -> some View {
        Section("Status") {
            ForEach(LibraryStatus.statuses(for: item.mediaType), id: \.self) { status in
                Button { apply(.library(media(for: item), status: status.rawValue), title: item.title) } label: {
                    Label(status.label, systemImage: item.status == status.rawValue ? "checkmark" : status.systemImage)
                }
                .disabled(item.status == status.rawValue)
            }
        }
        Button("Remove from Library", systemImage: "trash", role: .destructive) { pendingRemoval = item }
    }

    /// The minimal catalog identity a Library mutation needs. The server keys
    /// the entry on provider identity and keeps its stored snapshot.
    private func media(for item: LibraryItemDTO) -> CatalogMedia {
        CatalogMedia(identity: item)
    }

    private func apply(_ mutation: DetailMutation, title: String) {
        Task {
            do { try await services.mutate(mutation) }
            catch { actionFailure = mutation.type == "library.remove" ? "Couldn’t remove \(title). Try again." : "Couldn’t update \(title). Try again." }
        }
    }

    private func loadInProgress() async {
        if let stories = try? await services.continueItems() { inProgress = stories }
    }
}

private struct LibraryTile: View {
    let item: LibraryItemDTO
    let showsMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
            MosaicArtwork(url: item.posterURL, fallbackURL: item.backdropURL, mediaType: item.mediaType, title: item.title)
                .aspectRatio(MosaicArtworkRatio.poster, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).strokeBorder(MosaicColor.border) }
                .overlay(alignment: .topTrailing) {
                    if item.isFavorite {
                        Image(systemName: "heart.fill").font(.caption2.weight(.bold)).foregroundStyle(MosaicColor.danger)
                            .padding(5).background(.black.opacity(0.55), in: Circle()).padding(6)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let fraction = item.progressLine?.fraction { MosaicProgressBar(fraction: fraction, tint: item.mediaType.accent).padding(8) }
                }
            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
            if showsMedium { MosaicMediaLabel(mediaType: item.mediaType) }
            HStack(spacing: MosaicSpace.xSmall) {
                Text(item.statusLabel).foregroundStyle(MosaicColor.secondaryText)
                if let rating = item.ratingText { Text(rating).foregroundStyle(MosaicColor.rating) }
            }
            .font(.caption.weight(.medium))
            .lineLimit(1)
            if let progress = item.progressLine?.text {
                Text(progress).font(.caption).foregroundStyle(MosaicColor.mutedText).lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([item.title, item.mediaType.displayName, item.statusLabel, item.userRating.map { "your rating \(UserRating.format($0)) out of 5" }, item.progressLine?.text, item.isFavorite ? "favourite" : nil].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint("Opens details. Touch and hold to change status.")
        .accessibilityAddTraits(.isButton)
    }
}

private struct LibraryProgressCard: View {
    let story: ContinueStory
    var body: some View {
        HStack(spacing: MosaicSpace.small) {
            MosaicArtwork(url: story.fallbackArtworkURL, fallbackURL: story.artworkURL, mediaType: story.catalogMediaType)
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                MosaicMediaLabel(mediaType: story.catalogMediaType)
                Text(story.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                if let line = story.progress.detailLines.first { Text(line).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1) }
                if let fraction = story.progress.progressFraction { MosaicProgressBar(fraction: fraction, tint: story.catalogMediaType.accent) }
            }
        }
        .padding(MosaicSpace.small)
        .frame(width: 250, alignment: .leading)
        .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).strokeBorder(MosaicColor.border) }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens story details")
    }
}

private struct LibrarySkeleton: View {
    var body: some View {
        MosaicScreen {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 180), spacing: MosaicSpace.medium)], spacing: MosaicSpace.large) {
                ForEach(0..<6, id: \.self) { _ in MosaicSkeleton(aspectRatio: MosaicArtworkRatio.poster) }
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your Library")
    }
}

private struct LibraryEmptyCollection: View {
    @Environment(MosaicRouter.self) private var router
    var body: some View {
        MosaicStateMessage(title: "Nothing in your Library yet", message: "Log or save a movie, series, game or book and it will live here.", systemImage: "books.vertical", actionTitle: "Discover stories") { router.select(.discover) }
            .frame(maxHeight: .infinity)
            .background(MosaicColor.background)
    }
}

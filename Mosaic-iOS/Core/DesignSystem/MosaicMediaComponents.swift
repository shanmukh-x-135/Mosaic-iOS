import SwiftUI

/// The fields a poster or row needs, from any of the API's media shapes.
struct MosaicMediaSummary: Hashable {
    let title: String
    let mediaType: CatalogMediaType
    let posterURL: URL?
    let backdropURL: URL?
    let subtitle: String?

    init(title: String, mediaType: CatalogMediaType, posterURL: URL?, backdropURL: URL?, subtitle: String?) {
        self.title = title; self.mediaType = mediaType; self.posterURL = posterURL; self.backdropURL = backdropURL; self.subtitle = subtitle
    }
    init(_ media: CatalogMedia) {
        self.init(title: media.title, mediaType: media.mediaType, posterURL: media.posterURL, backdropURL: media.backdropURL, subtitle: media.resultMetadata.isEmpty ? nil : media.resultMetadata)
    }
    init(_ item: LibraryItemDTO, subtitle: String? = nil) {
        self.init(title: item.title, mediaType: item.mediaType, posterURL: item.posterURL, backdropURL: item.backdropURL, subtitle: subtitle)
    }
}

/// A 2:3 poster with title and one metadata line. Poster size is a design
/// token so every shelf in the app lines up.
struct MosaicPosterCard: View {
    let summary: MosaicMediaSummary
    var width: CGFloat = MosaicLayout.posterWidth
    var showsMedium = false
    var badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
            MosaicArtwork(url: summary.posterURL, fallbackURL: summary.backdropURL, mediaType: summary.mediaType, title: summary.title)
                .frame(width: width, height: width / MosaicArtworkRatio.poster)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).strokeBorder(MosaicColor.border) }
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Image(systemName: badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MosaicColor.primaryText)
                            .padding(6)
                            .background(.black.opacity(0.55), in: Circle())
                            .padding(6)
                    }
                }
            Text(summary.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MosaicColor.primaryText)
                .lineLimit(2, reservesSpace: true)
            if showsMedium { MosaicMediaLabel(mediaType: summary.mediaType) }
            if let subtitle = summary.subtitle {
                Text(subtitle).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([summary.title, summary.mediaType.displayName, summary.subtitle].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}

/// A list row: thumbnail, title, medium and supporting lines.
struct MosaicMediaRow<Trailing: View>: View {
    let summary: MosaicMediaSummary
    var lines: [String] = []
    var showsMedium = true
    var thumbnailWidth: CGFloat = 52
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: MosaicSpace.medium) {
            MosaicArtwork(url: summary.posterURL, fallbackURL: summary.backdropURL, mediaType: summary.mediaType)
                .frame(width: thumbnailWidth, height: thumbnailWidth / MosaicArtworkRatio.poster)
                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                if showsMedium { MosaicMediaLabel(mediaType: summary.mediaType) }
                Text(summary.title).font(MosaicType.cardTitle).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
                ForEach(lines, id: \.self) { line in
                    Text(line).font(.caption).foregroundStyle(MosaicColor.secondaryText).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .contentShape(Rectangle())
    }
}

extension MosaicMediaRow where Trailing == EmptyView {
    init(summary: MosaicMediaSummary, lines: [String] = [], showsMedium: Bool = true, thumbnailWidth: CGFloat = 52) {
        self.init(summary: summary, lines: lines, showsMedium: showsMedium, thumbnailWidth: thumbnailWidth) { EmptyView() }
    }
}

/// A horizontally scrolling poster shelf that opens details.
struct MosaicPosterShelf: View {
    let items: [CatalogMedia]
    var showsMedium = false

    var body: some View {
        MosaicRail {
            ForEach(items) { media in
                NavigationLink(value: MosaicRoute.media(media)) {
                    MosaicPosterCard(summary: MosaicMediaSummary(media), showsMedium: showsMedium)
                }
                .buttonStyle(.plain)
                .saveForLaterContextMenu(media)
            }
        }
    }
}

/// "Save for later" — inserts the medium's planned status only when the title
/// is untracked; a tracked title shows its existing status instead.
struct SaveForLaterButton: View {
    let media: CatalogMedia
    var style: Style = .bordered
    enum Style { case bordered, prominentOnArtwork }
    @Environment(LibraryStore.self) private var library
    @Environment(\.mosaicServices) private var services
    @State private var failure: String?

    var body: some View {
        let entry = library.entry(for: media)
        let saving = library.savingKeys.contains(media.mediaKey)
        VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
            Button { save() } label: {
                if let entry {
                    Label(entry.statusLabel, systemImage: entry.libraryStatus?.systemImage ?? "checkmark")
                } else if saving {
                    Label("Saving…", systemImage: "bookmark")
                } else {
                    Label("Save for later", systemImage: "bookmark")
                }
            }
            .font(.subheadline.weight(.semibold))
            .modifier(SaveButtonStyle(style: style, saved: entry != nil))
            .disabled(entry != nil || saving || !library.hasLoaded)
            .accessibilityHint(entry == nil ? "Adds \(media.title) to your \(LibraryStatus.saveForLater(for: media.mediaType).label)" : "Already in your Library")
            if let failure { MosaicNotice(text: failure, tone: .failure) }
        }
    }

    private func save() {
        failure = nil
        Task {
            do { _ = try await library.saveForLater(media, using: services) }
            catch { failure = "Couldn’t save \(media.title). Try again." }
        }
    }
}

private struct SaveButtonStyle: ViewModifier {
    let style: SaveForLaterButton.Style
    let saved: Bool
    func body(content: Content) -> some View {
        switch style {
        case .bordered: content.buttonStyle(.bordered).tint(saved ? MosaicColor.success : MosaicColor.accent)
        case .prominentOnArtwork: content.buttonStyle(.borderedProminent).tint(saved ? MosaicColor.surfaceHover : MosaicColor.primaryText).foregroundStyle(saved ? MosaicColor.primaryText : MosaicColor.onLight)
        }
    }
}

private struct SaveForLaterMenu: ViewModifier {
    let media: CatalogMedia
    @Environment(LibraryStore.self) private var library
    @Environment(\.mosaicServices) private var services
    func body(content: Content) -> some View {
        content.contextMenu {
            if let entry = library.entry(for: media) {
                Label("In your Library · \(entry.statusLabel)", systemImage: "checkmark")
            } else {
                Button { Task { _ = try? await library.saveForLater(media, using: services) } } label: {
                    Label("Save to \(LibraryStatus.saveForLater(for: media.mediaType).label)", systemImage: "bookmark")
                }
                .disabled(!library.hasLoaded)
            }
        }
    }
}

extension View {
    func saveForLaterContextMenu(_ media: CatalogMedia) -> some View { modifier(SaveForLaterMenu(media: media)) }
}

/// Opens the global Quick Log sheet from a root screen's toolbar.
struct QuickLogToolbarItem: ToolbarContent {
    @Environment(MosaicRouter.self) private var router
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { router.presentQuickLog() } label: { Label("Log", systemImage: "plus") }
                .accessibilityLabel("Log something")
                .accessibilityHint("Search for a movie, series, game, or book to log")
        }
    }
}

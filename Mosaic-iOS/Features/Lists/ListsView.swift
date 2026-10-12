import SwiftUI

/// Read-only list browsing (`GET /api/me/lists`). Creating, editing and
/// sharing lists remain on the web in this phase.
struct ListsView: View {
    @Environment(\.mosaicServices) private var services
    @State private var lists = Loadable<[UserList]>.idle

    var body: some View {
        Group {
            switch lists {
            case .idle, .loading:
                ProgressView("Loading your lists").frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(error):
                MosaicStateMessage(title: MosaicErrorCopy.title(for: error, subject: "your lists"), message: MosaicErrorCopy.message(for: error), systemImage: "exclamationmark.triangle", actionTitle: "Try again") { Task { await load() } }
                    .frame(maxHeight: .infinity)
            case let .loaded(items) where items.isEmpty:
                MosaicStateMessage(title: "No lists yet", message: "Lists you create on Mosaic for the web appear here, in the same order.", systemImage: "list.bullet.rectangle")
                    .frame(maxHeight: .infinity)
            case let .loaded(items):
                MosaicScreen {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: MosaicSpace.medium, alignment: .top)], spacing: MosaicSpace.large) {
                        ForEach(items.sorted { $0.updatedAt > $1.updatedAt }) { list in
                            NavigationLink(value: MosaicRoute.list(list)) { ListCoverCard(list: list, width: nil) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, MosaicLayout.pageHorizontal)
                }
            }
        }
        .background(MosaicColor.background)
        .navigationTitle("Lists")
        .toolbar(.hidden, for: .tabBar)
        .task { if case .idle = lists { await load() } }
        .refreshable { await load() }
    }

    private func load() async {
        if lists.value == nil { lists = .loading }
        do { lists = .loaded(try await services.lists()) } catch is CancellationError {} catch { if lists.value == nil { lists = .failed(error) } }
    }
}

/// A list's cover: its first posters, fanned, with title, count and visibility.
struct ListCoverCard: View {
    let list: UserList
    var width: CGFloat? = 168

    var body: some View {
        VStack(alignment: .leading, spacing: MosaicSpace.xSmall) {
            Color.clear
                .aspectRatio(1.35, contentMode: .fit)
                .overlay {
                    HStack(spacing: -28) {
                        ForEach(Array(list.orderedItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                            MosaicArtwork(url: item.media.posterURL, fallbackURL: item.media.backdropURL, mediaType: item.media.mediaType, title: item.media.title)
                                .aspectRatio(MosaicArtworkRatio.poster, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: MosaicRadius.small, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: MosaicRadius.small, style: .continuous).strokeBorder(MosaicColor.highlight) }
                                .shadow(color: .black.opacity(0.45), radius: 6, x: 2)
                                .zIndex(Double(3 - index))
                        }
                        if list.items.isEmpty { Image(systemName: "list.bullet.rectangle").font(.title).foregroundStyle(MosaicColor.mutedText) }
                    }
                    .padding(MosaicSpace.small)
                }
                .background(MosaicColor.elevated, in: RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: MosaicRadius.media, style: .continuous).strokeBorder(MosaicColor.border) }
            Text(list.title).font(.subheadline.weight(.semibold)).foregroundStyle(MosaicColor.primaryText).lineLimit(2)
            HStack(spacing: MosaicSpace.xSmall) {
                Image(systemName: list.visibility.systemImage).accessibilityHidden(true)
                Text("\(list.items.count) \(list.items.count == 1 ? "title" : "titles") · \(list.visibility.label)")
            }
            .font(.caption).foregroundStyle(MosaicColor.secondaryText)
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(list.title), \(list.items.count) titles, \(list.visibility.label)")
        .accessibilityAddTraits(.isButton)
    }
}

struct ListDetailView: View {
    let list: UserList

    var body: some View {
        MosaicScreen {
            VStack(alignment: .leading, spacing: MosaicSpace.small) {
                Label(list.visibility.label, systemImage: list.visibility.systemImage).font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText)
                Text(list.title).font(MosaicType.display).foregroundStyle(MosaicColor.primaryText).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                if !list.description.isEmpty { Text(list.description).font(.body).foregroundStyle(MosaicColor.secondaryText).fixedSize(horizontal: false, vertical: true) }
                HStack(spacing: MosaicSpace.small) {
                    Text("\(list.items.count) \(list.items.count == 1 ? "title" : "titles")")
                    ForEach(list.mediaTypes, id: \.self) { MosaicMediaLabel(mediaType: $0) }
                }
                .font(.footnote).foregroundStyle(MosaicColor.mutedText)
            }
            .padding(.horizontal, MosaicLayout.pageHorizontal)

            if list.items.isEmpty {
                MosaicStateMessage(title: "This list is empty", message: "Add titles to it on Mosaic for the web.", systemImage: "list.bullet.rectangle")
            } else {
                LazyVStack(spacing: MosaicSpace.medium) {
                    ForEach(Array(list.orderedItems.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: MosaicRoute.media(item.media)) {
                            HStack(alignment: .top, spacing: MosaicSpace.small) {
                                Text("\(index + 1)").font(.footnote.weight(.bold)).foregroundStyle(MosaicColor.mutedText).monospacedDigit().frame(minWidth: 22, alignment: .trailing).padding(.top, 2)
                                MosaicMediaRow(summary: MosaicMediaSummary(item.media), lines: [item.media.resultMetadata, item.note].compactMap { $0?.isEmpty == false ? $0 : nil })
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Number \(index + 1), \(item.media.title)\(item.note.map { ", note: \($0)" } ?? "")")
                    }
                }
                .padding(.horizontal, MosaicLayout.pageHorizontal)
            }
        }
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

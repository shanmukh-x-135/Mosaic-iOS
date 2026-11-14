import SwiftUI

struct ListsView: View {
    @Environment(\.mosaicServices) private var services
    @Environment(PersonalStateStore.self) private var store
    @Environment(MosaicRouter.self) private var router
    @State private var creating = false

    var body: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                ProgressView("Loading your lists").frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(error):
                MosaicStateMessage(title: MosaicErrorCopy.title(for: error, subject: "your lists"), message: MosaicErrorCopy.message(for: error), systemImage: "exclamationmark.triangle", actionTitle: "Try again") { store.refresh(services) }
                    .frame(maxHeight: .infinity)
            case let .loaded(snapshot):
                MosaicScreen {
                    if snapshot.lists.isEmpty {
                        MosaicStateMessage(title: "No lists yet", message: "Create a cross-media collection for the stories you want to keep together.", systemImage: "list.bullet.rectangle", actionTitle: "Create your first list") { creating = true }
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: MosaicSpace.medium, alignment: .top)], spacing: MosaicSpace.large) {
                            ForEach(snapshot.lists.sorted { $0.updatedAt > $1.updatedAt }) { list in
                                NavigationLink(value: MosaicRoute.list(list)) { ListCoverCard(list: list, width: nil) }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, MosaicLayout.pageHorizontal)
                    }
                }
            }
        }
        .background(MosaicColor.background)
        .navigationTitle("Lists")
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            Button { creating = true } label: { Label("New List", systemImage: "plus") }
                .disabled(store.snapshot == nil)
        }
        .task { store.load(services) }
        .refreshable { store.refresh(services) }
        .sheet(isPresented: $creating) {
            NavigationStack {
                ListCreateView { created in router.open(.list(created)) }
            }
        }
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
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @State private var editingDetails = false
    @State private var addingTitles = false
    @State private var editingNote: UserList.Item?
    @State private var saving = false
    @State private var notice: (String, MosaicNotice.Tone)?

    private var liveList: UserList { store.snapshot?.list(id: list.id) ?? list }
    private var isOwner: Bool { store.snapshot?.list(id: list.id) != nil }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: MosaicSpace.small) {
                    Label(liveList.visibility.label, systemImage: liveList.visibility.systemImage)
                        .font(.caption.weight(.semibold)).foregroundStyle(MosaicColor.secondaryText)
                    Text(liveList.title).font(MosaicType.display).foregroundStyle(MosaicColor.primaryText)
                        .accessibilityAddTraits(.isHeader)
                    if !liveList.description.isEmpty { Text(liveList.description).foregroundStyle(MosaicColor.secondaryText) }
                    Text("\(liveList.items.count) \(liveList.items.count == 1 ? "title" : "titles")")
                        .font(.footnote).foregroundStyle(MosaicColor.mutedText)
                }
                if saving { ProgressView("Saving…") }
                if let notice { MosaicNotice(text: notice.0, tone: notice.1) }
            }
            .listRowBackground(MosaicColor.background)

            if liveList.items.isEmpty {
                Text("This list is empty. Search across every medium to add its first story.")
                    .foregroundStyle(MosaicColor.secondaryText)
                    .listRowBackground(MosaicColor.background)
            } else {
                Section {
                    ForEach(Array(liveList.orderedItems.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: MosaicSpace.small) {
                            NavigationLink(value: MosaicRoute.media(item.media)) {
                                HStack(alignment: .top, spacing: MosaicSpace.small) {
                                    Text("\(index + 1)").font(.footnote.weight(.bold))
                                        .foregroundStyle(MosaicColor.mutedText).monospacedDigit().frame(minWidth: 22)
                                    MosaicMediaRow(summary: MosaicMediaSummary(item.media), lines: [item.media.resultMetadata, item.note].compactMap { $0?.isEmpty == false ? $0 : nil })
                                }
                            }
                            .accessibilityLabel("Number \(index + 1), \(item.media.title)\(item.note.map { ", note: \($0)" } ?? "")")
                            if isOwner {
                                Button { editingNote = item } label: { Image(systemName: "note.text").frame(minWidth: 44, minHeight: 44) }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Edit note for \(item.media.title)")
                            }
                        }
                        .disabled(saving)
                        .moveDisabled(!isOwner || saving)
                        .deleteDisabled(!isOwner || saving)
                        .listRowBackground(MosaicColor.background)
                    }
                    .onMove { source, destination in
                        perform(.listReorder(listID: list.id, itemIDs: ListEditor.reorderedIDs(liveList.orderedItems, from: source, to: destination)))
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { liveList.orderedItems[$0].id }
                        guard isOwner, !saving else { return }
                        saving = true
                        notice = nil
                        Task {
                            defer { saving = false }
                            do {
                                for id in ids { try await services.mutate(.listItemRemove(listID: list.id, itemID: id)) }
                            } catch { notice = (MosaicErrorCopy.message(for: error), .failure) }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle(liveList.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isOwner { EditButton().disabled(saving) }
            Menu {
                if isOwner {
                    Button("Edit details", systemImage: "pencil") { editingDetails = true }
                    Button("Add titles", systemImage: "plus") { addingTitles = true }
                }
                if let url = ListEditor.shareURL(for: liveList, base: AppConfiguration.current.apiBaseURL) {
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                } else {
                    Button("Share — Private lists can’t be shared", systemImage: "lock") {}.disabled(true)
                }
            } label: { Label("List actions", systemImage: "ellipsis.circle") }
            .disabled(saving)
        }
        .task { store.load(services) }
        .refreshable { if !saving { store.refresh(services) } }
        .sheet(isPresented: $editingDetails) {
            NavigationStack {
                ListDetailsEditor(list: liveList, saving: $saving) { _ in notice = ("List details saved.", .success) }
            }
        }
        .sheet(isPresented: $addingTitles) {
            NavigationStack { ListTitleSearchView(listID: list.id, saving: $saving) }
        }
        .sheet(item: $editingNote) { item in
            NavigationStack {
                ListNoteEditor(listID: list.id, item: item, saving: $saving) {
                    notice = ("Saved note for \(item.media.title).", .success)
                }
            }
        }
    }

    private func perform(_ mutation: DetailMutation) {
        guard isOwner, !saving else { return }
        saving = true
        notice = nil
        Task {
            defer { saving = false }
            do { try await services.mutate(mutation) }
            catch { notice = (MosaicErrorCopy.message(for: error), .failure) }
        }
    }
}

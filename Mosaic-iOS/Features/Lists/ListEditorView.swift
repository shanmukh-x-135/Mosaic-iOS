import SwiftUI

/// Shared, pure rules for list editing and the web mutation contract.
nonisolated enum ListEditor {
    static func newListID(before: [UserList], after: [UserList]) -> String? {
        let previous = Set(before.map(\.id))
        return after.first { !previous.contains($0.id) }?.id
    }

    static func reorderedIDs(_ items: [UserList.Item], from source: IndexSet, to destination: Int) -> [String] {
        var ids = items.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        return ids
    }

    static func isAlreadyAdded(_ media: CatalogMedia, in list: UserList) -> Bool {
        list.items.contains { $0.media.mediaKey == media.mediaKey }
    }

    static func validateCreate(title: String, description: String) -> String? {
        validateTitle(title) ?? (description.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count > 1000
            ? "Keep the description to 1,000 characters or fewer." : nil)
    }

    static func validateUpdate(title: String, description: String) -> String? {
        validateTitle(title) ?? (description.utf16.count > 2000
            ? "Keep the description to 2,000 characters or fewer." : nil)
    }

    static func validateNote(_ note: String) -> String? {
        note.utf16.count > 2000 ? "Keep the note to 2,000 characters or fewer." : nil
    }

    private static func validateTitle(_ title: String) -> String? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "Enter a title." }
        return title.utf16.count > 120 ? "Keep the title to 120 characters or fewer." : nil
    }

    static func shareURL(for list: UserList, base: URL) -> URL? {
        guard list.visibility != .private else { return nil }
        return base.appendingPathComponent("lists").appendingPathComponent(list.id)
    }
}

struct ListCreateView: View {
    var onCreated: (UserList) -> Void
    @State private var saving = false

    var body: some View {
        ListDetailsEditor(list: nil, saving: $saving) { list in
            if let list { onCreated(list) }
        }
    }
}

struct ListDetailsEditor: View {
    let list: UserList?
    @Binding var saving: Bool
    var onSaved: (UserList?) -> Void
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var visibility: UserList.Visibility
    @State private var createdFrom: [UserList]?
    @State private var failure: String?

    init(list: UserList?, saving: Binding<Bool>, onSaved: @escaping (UserList?) -> Void) {
        self.list = list
        _saving = saving
        self.onSaved = onSaved
        _title = State(initialValue: list?.title ?? "")
        _description = State(initialValue: list?.description ?? "")
        _visibility = State(initialValue: list?.visibility ?? .private)
    }

    private var validation: String? {
        list == nil ? ListEditor.validateCreate(title: title, description: description)
            : ListEditor.validateUpdate(title: title, description: description)
    }

    var body: some View {
        Form {
            Section("List details") {
                TextField("Title", text: $title)
                TextField("Description", text: $description, axis: .vertical).lineLimit(3...8)
                Picker("Visibility", selection: $visibility) {
                    ForEach([UserList.Visibility.private, .public, .unlisted], id: \.self) { value in
                        Label(value.label, systemImage: value.systemImage).tag(value)
                    }
                }
            }
            .disabled(saving || createdFrom != nil)
            .listRowBackground(MosaicColor.elevated)
            Section {
                Text("Public lists are visible to everyone. Unlisted lists are available to anyone with the link. Private lists are only visible to you.")
                    .font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                if let validation { MosaicNotice(text: validation) }
                if let failure { MosaicNotice(text: failure, tone: .failure) }
                if saving { ProgressView("Saving…") }
            }
            .listRowBackground(MosaicColor.background)
        }
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle(list == nil ? "New List" : "Edit details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) {
                Button(createdFrom != nil ? "Open list" : list == nil ? "Create" : "Save", action: save).disabled(saving || validation != nil || store.snapshot == nil)
            }
        }
        .interactiveDismissDisabled(saving)
    }

    private func save() {
        guard !saving, validation == nil, let snapshot = store.snapshot else { return }
        let before = snapshot.lists
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let mutation: DetailMutation
        if let list {
            mutation = .listUpdate(listID: list.id, title: title, description: description, visibility: visibility)
        } else {
            mutation = .listCreate(title: title, description: description.trimmingCharacters(in: .whitespacesAndNewlines), visibility: visibility)
        }
        saving = true
        failure = nil
        Task {
            defer { saving = false }
            do {
                // A successful create is never submitted again if opening it needs a retry.
                if createdFrom == nil {
                    try await services.mutate(mutation)
                    if list == nil { createdFrom = before }
                }
                // Mutation notifications apply the authoritative response to the store.
                await Task.yield()
                if let before = createdFrom {
                    if ListEditor.newListID(before: before, after: store.snapshot?.lists ?? []) == nil {
                        store.apply(try await services.stateSnapshot())
                    }
                    guard let id = ListEditor.newListID(before: before, after: store.snapshot?.lists ?? []),
                          let saved = store.snapshot?.list(id: id) else {
                        failure = "Your list was created. Tap Open list to try loading it again."
                        return
                    }
                    onSaved(saved)
                } else {
                    onSaved(store.snapshot?.list(id: list?.id ?? ""))
                }
                dismiss()
            } catch {
                failure = createdFrom == nil ? MosaicErrorCopy.message(for: error)
                    : "Your list was created, but couldn’t be loaded. Tap Open list to try again."
            }
        }
    }
}

struct ListNoteEditor: View {
    let listID: String
    let item: UserList.Item
    @Binding var saving: Bool
    var onSaved: () -> Void
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var note: String
    @State private var failure: String?

    init(listID: String, item: UserList.Item, saving: Binding<Bool>, onSaved: @escaping () -> Void) {
        self.listID = listID
        self.item = item
        _saving = saving
        self.onSaved = onSaved
        _note = State(initialValue: item.note ?? "")
    }

    var body: some View {
        Form {
            Section(item.media.title) {
                TextField("Note", text: $note, axis: .vertical).lineLimit(4...10)
                    .accessibilityLabel("Note for \(item.media.title)")
                    .disabled(saving)
                Text("Leave empty to clear the note.").font(.footnote).foregroundStyle(MosaicColor.secondaryText)
                if let validation = ListEditor.validateNote(note) { MosaicNotice(text: validation) }
                if let failure { MosaicNotice(text: failure, tone: .failure) }
                if saving { ProgressView("Saving…") }
            }
            .listRowBackground(MosaicColor.elevated)
        }
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle("Edit note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard !saving, ListEditor.validateNote(note) == nil else { return }
                    saving = true
                    failure = nil
                    Task {
                        defer { saving = false }
                        do {
                            try await services.mutate(.listItemUpdate(listID: listID, itemID: item.id, note: note))
                            onSaved()
                            dismiss()
                        } catch { failure = MosaicErrorCopy.message(for: error) }
                    }
                }
                .disabled(saving || ListEditor.validateNote(note) != nil)
            }
        }
        .interactiveDismissDisabled(saving)
        .presentationDetents([.medium, .large])
    }
}

struct ListTitleSearchView: View {
    let listID: String
    @Binding var saving: Bool
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [CatalogMedia] = []
    @State private var searching = false
    @State private var searchFailure: String?
    @State private var notice: (String, MosaicNotice.Tone)?

    private var searchQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        List {
            if saving { ProgressView("Adding…") }
            if let notice { MosaicNotice(text: notice.0, tone: notice.1) }
            if let searchFailure { MosaicNotice(text: searchFailure, tone: .failure) }
            if searching { ProgressView("Searching…") }
            if searchQuery.count < 2 {
                Text("Enter at least 2 characters to search movies, series, games, and books.")
                    .foregroundStyle(MosaicColor.secondaryText)
            } else if !searching && results.isEmpty && searchFailure == nil {
                Text("No titles found. Try another search.").foregroundStyle(MosaicColor.secondaryText)
            }
            ForEach(results, id: \.mediaKey) { media in
                let added = store.snapshot?.list(id: listID).map { ListEditor.isAlreadyAdded(media, in: $0) } ?? false
                Button {
                    add(media)
                } label: {
                    HStack {
                        MosaicMediaRow(summary: MosaicMediaSummary(media), lines: [media.resultMetadata])
                        Spacer(minLength: MosaicSpace.small)
                        if added { Text("Added").font(.caption) }
                        else { Image(systemName: "plus") }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(media.title), \(added ? "Added" : "Add to list")")
                .disabled(added || saving || store.snapshot?.list(id: listID) == nil)
                .listRowBackground(MosaicColor.background)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle("Add titles")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search every medium")
        .task(id: searchQuery) { await search() }
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(saving) } }
        .interactiveDismissDisabled(saving)
    }

    private func search() async {
        let q = searchQuery
        results = []
        searchFailure = nil
        searching = q.count >= 2
        guard searching else { return }
        do {
            try await Task.sleep(for: .milliseconds(250))
            let response = try await services.search(q, .all)
            try Task.checkCancellation()
            guard q == searchQuery else { return }
            results = Array(response.items.prefix(8))
            if !response.failures.isEmpty { searchFailure = "Some sources are unavailable. Showing the titles we found." }
            searching = false
        } catch {
            guard !Task.isCancelled, q == searchQuery else { return }
            searchFailure = MosaicErrorCopy.message(for: error)
            searching = false
        }
    }

    private func add(_ media: CatalogMedia) {
        guard !saving, let list = store.snapshot?.list(id: listID), !ListEditor.isAlreadyAdded(media, in: list) else { return }
        saving = true
        notice = nil
        Task {
            defer { saving = false }
            do {
                try await services.mutate(.listAdd(listID: listID, media: media))
                notice = ("Added \(media.title).", .success)
            } catch { notice = (MosaicErrorCopy.message(for: error), .failure) }
        }
    }
}

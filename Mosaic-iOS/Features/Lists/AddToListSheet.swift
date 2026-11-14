import SwiftUI

struct AddToListSheet: View {
    let media: CatalogMedia
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var showsNewList = false
    @State private var title = ""
    @State private var visibility: UserList.Visibility = .private
    @State private var isSaving = false
    @State private var failure: String?
    @State private var success: String?
    @State private var createdList: UserList?

    private var lists: [UserList] { Self.orderedLists(store.snapshot?.lists ?? []) }
    private var isBusy: Bool { isSaving || success != nil }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(media.title)
                        .font(MosaicType.cardTitle)
                        .foregroundStyle(MosaicColor.primaryText)
                } header: {
                    Text("Title to add")
                }
                .listRowBackground(MosaicColor.elevated)

                if let failure {
                    Section {
                        MosaicNotice(text: failure, tone: .failure)
                        if let createdList {
                            Button("Retry adding title") { add(to: createdList) }
                                .disabled(isBusy)
                        }
                    }
                    .listRowBackground(MosaicColor.elevated)
                }

                Section("Your lists") {
                    if lists.isEmpty {
                        Text("No lists yet. Create one below to add this title.")
                            .font(MosaicType.body)
                            .foregroundStyle(MosaicColor.secondaryText)
                    }
                    ForEach(lists) { list in listRow(list) }
                    Button {
                        showsNewList.toggle()
                        failure = nil
                    } label: {
                        Label("New list…", systemImage: "plus")
                    }
                    .disabled(isBusy || createdList != nil)
                }
                .listRowBackground(MosaicColor.elevated)

                if showsNewList {
                    Section {
                        TextField("List title", text: $title)
                            .accessibilityLabel("List title")
                        Picker("Visibility", selection: $visibility) {
                            ForEach([UserList.Visibility.private, .unlisted, .public], id: \.self) { value in
                                Label(value.label, systemImage: value.systemImage).tag(value)
                            }
                        }
                        if !title.isEmpty, let validation = Self.validateTitle(title) {
                            MosaicNotice(text: validation, tone: .failure)
                        }
                        Button("Create list and add title", action: createAndAdd)
                            .disabled(Self.validateTitle(title) != nil || store.snapshot == nil)
                    } header: {
                        Text("New list")
                    } footer: {
                        Text("Use 1–120 characters for the list title.")
                    }
                    .disabled(isBusy || createdList != nil)
                    .listRowBackground(MosaicColor.elevated)
                }
                if isSaving {
                    Section { ProgressView("Saving…") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MosaicColor.background)
            .tint(MosaicColor.accent)
            .safeAreaInset(edge: .bottom) {
                if let success {
                    MosaicNotice(text: success, tone: .success)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(MosaicSpace.medium)
                        .background(MosaicColor.elevated)
                }
            }
            .navigationTitle("Add to list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isBusy)
                }
            }
            .interactiveDismissDisabled(isBusy)
        }
    }

    private func listRow(_ list: UserList) -> some View {
        let contains = Self.containsMedia(list, media)
        return Button { add(to: list) } label: {
            HStack(spacing: MosaicSpace.small) {
                VStack(alignment: .leading, spacing: MosaicSpace.xxSmall) {
                    Text(list.title)
                        .font(MosaicType.cardTitle)
                        .foregroundStyle(MosaicColor.primaryText)
                    Label("\(list.items.count) \(list.items.count == 1 ? "title" : "titles") · \(list.visibility.label)", systemImage: list.visibility.systemImage)
                        .font(MosaicType.caption)
                        .foregroundStyle(MosaicColor.secondaryText)
                }
                Spacer()
                if contains {
                    Label("Added", systemImage: "checkmark")
                        .font(MosaicType.caption)
                        .foregroundStyle(MosaicColor.success)
                }
            }
        }
        .disabled(contains || isBusy || store.snapshot == nil)
        .accessibilityLabel(contains ? "Already in \(list.title)" : "Add to \(list.title)")
        .accessibilityValue("\(list.items.count) titles, \(list.visibility.label)")
    }

    nonisolated static func containsMedia(_ list: UserList, _ media: CatalogMedia) -> Bool {
        list.items.contains { $0.media.mediaKey == media.mediaKey }
    }

    nonisolated static func newListID(before: [UserList], after: [UserList]) -> String? {
        let previousIDs = Set(before.map(\.id))
        return orderedLists(after).first { !previousIDs.contains($0.id) }?.id
    }

    nonisolated static func validateTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter a list title." }
        if trimmed.utf16.count > 120 { return "Keep the list title to 120 characters or fewer." }
        return nil
    }

    nonisolated static func orderedLists(_ lists: [UserList]) -> [UserList] {
        lists.sorted { $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt }
    }

    private func createAndAdd() {
        guard !isBusy, Self.validateTitle(title) == nil, let snapshot = store.snapshot else { return }
        let before = snapshot.lists
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        failure = nil
        Task {
            defer { isSaving = false }
            do {
                try await services.mutate(.listCreate(title: trimmedTitle, description: "", visibility: visibility))
            } catch {
                failure = "Mosaic couldn’t create your list. Try again."
                return
            }
            showsNewList = false
            title = ""
            let after = store.snapshot?.lists ?? []
            guard let id = Self.newListID(before: before, after: after),
                  let list = after.first(where: { $0.id == id }) else {
                failure = "Your list was created, but Mosaic couldn’t find it. Reopen Add to list to try again."
                return
            }
            createdList = list
            await performAdd(to: list)
        }
    }

    private func add(to list: UserList) {
        guard !isBusy, !Self.containsMedia(list, media) else { return }
        isSaving = true
        failure = nil
        Task {
            defer { isSaving = false }
            await performAdd(to: list)
        }
    }

    private func performAdd(to list: UserList) async {
        do {
            try await services.mutate(.listAdd(listID: list.id, media: media, note: nil))
            success = "Added to \(list.title)."
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            failure = createdList?.id == list.id
                ? "Your list was created, but Mosaic couldn’t add this title. Try again."
                : "Mosaic couldn’t add this title to \(list.title). Try again."
        }
    }
}

import SwiftUI

struct ReviewEditorView: View {
    let media: CatalogMedia
    let existing: MosaicStateSnapshot.Review?
    @Environment(LibraryStore.self) private var library
    @Environment(\.mosaicServices) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var reviewBody: String
    @State private var containsSpoilers: Bool
    @State private var isSaving = false
    @State private var confirmsDeletion = false
    @State private var failure: String?

    init(media: CatalogMedia, existing: MosaicStateSnapshot.Review? = nil) {
        self.media = media
        self.existing = existing
        _reviewBody = State(initialValue: existing?.body ?? "")
        _containsSpoilers = State(initialValue: existing?.containsSpoilers ?? false)
    }

    // JavaScript's string length (used by the web validator) counts UTF-16 units.
    private var characterCount: Int { reviewBody.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count }

    var body: some View {
        Form {
            Section("Your review") {
                TextField("What stayed with you?", text: $reviewBody, axis: .vertical)
                    .lineLimit(6...12)
                    .accessibilityLabel("Your review")
                if characterCount >= 9_000 {
                    Text("\(characterCount.formatted()) / 10,000 characters")
                        .font(MosaicType.caption)
                        .foregroundStyle(characterCount > 10_000 ? MosaicColor.danger : MosaicColor.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Toggle("Contains spoilers", isOn: $containsSpoilers)
            }
            .disabled(isSaving)
            .listRowBackground(MosaicColor.elevated)

            if let failure {
                Section { MosaicNotice(text: failure, tone: .failure) }
            }
            if existing != nil {
                Section {
                    Button("Delete review", role: .destructive) { confirmsDeletion = true }
                        .disabled(isSaving)
                }
                .listRowBackground(MosaicColor.elevated)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MosaicColor.background)
        .navigationTitle(existing == nil ? "Write review" : "Edit review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save", action: save)
                    .disabled(isSaving || Self.validate(reviewBody) != nil)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .confirmationDialog("Delete your review?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            if let existing {
                Button("Delete review", role: .destructive) { perform(.reviewDelete(id: existing.id)) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    nonisolated static func validate(_ body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Write a review before saving." }
        if trimmed.utf16.count > 10_000 { return "Keep your review to 10,000 characters or fewer." }
        return nil
    }

    nonisolated static func makeSaveMutation(existing: MosaicStateSnapshot.Review?, media: CatalogMedia, body: String, spoilers: Bool, rating: Double?) -> DetailMutation {
        .reviewSave(id: existing?.id, media: media, body: body.trimmingCharacters(in: .whitespacesAndNewlines), containsSpoilers: spoilers, rating: rating)
    }

    private func save() {
        guard Self.validate(reviewBody) == nil else { return }
        perform(Self.makeSaveMutation(existing: existing, media: media, body: reviewBody, spoilers: containsSpoilers, rating: library.entry(for: media)?.userRating))
    }

    private func perform(_ mutation: DetailMutation) {
        guard !isSaving else { return }
        isSaving = true
        failure = nil
        Task {
            defer { isSaving = false }
            do {
                try await services.mutate(mutation)
                dismiss()
            } catch {
                failure = mutation.type == "review.delete"
                    ? "Mosaic couldn’t delete your review. Try again."
                    : "Mosaic couldn’t save your review. Try again."
            }
        }
    }
}

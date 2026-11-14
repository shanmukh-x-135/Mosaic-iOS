import SwiftUI

struct ReviewButton: View {
    static let isAvailable = true
    let media: CatalogMedia
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @State private var presentsEditor = false

    private var review: MosaicStateSnapshot.Review? { store.snapshot?.reviews(for: media) }

    var body: some View {
        Button { presentsEditor = true } label: {
            Label(review == nil ? "Review" : "Edit review", systemImage: "text.bubble")
        }
        .buttonStyle(.bordered)
        .disabled(store.snapshot == nil)
        .onAppear { store.load(services) }
        .sheet(isPresented: $presentsEditor) {
            NavigationStack { ReviewEditorView(media: media, existing: review) }
        }
    }
}

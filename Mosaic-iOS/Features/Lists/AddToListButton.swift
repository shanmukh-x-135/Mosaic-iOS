import SwiftUI

struct AddToListButton: View {
    static let isAvailable = true
    let media: CatalogMedia
    @Environment(PersonalStateStore.self) private var store
    @Environment(\.mosaicServices) private var services
    @State private var presentsSheet = false

    var body: some View {
        Button { presentsSheet = true } label: {
            Label("Add to list", systemImage: "text.badge.plus")
        }
        .buttonStyle(.bordered)
        .disabled(store.snapshot == nil)
        .onAppear { store.load(services) }
        .sheet(isPresented: $presentsSheet) { AddToListSheet(media: media) }
    }
}

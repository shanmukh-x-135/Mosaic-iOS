import SwiftUI

/// Implemented by T3.2.
struct AddToListButton: View {
    static let isAvailable = false
    let media: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

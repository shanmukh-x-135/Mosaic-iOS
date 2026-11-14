import SwiftUI

/// Implemented by T2.2.
struct MovieHistorySection: View {
    static let isAvailable = false
    let media: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

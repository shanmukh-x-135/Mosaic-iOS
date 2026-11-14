import SwiftUI

/// Implemented by T1.2.
struct WatchProvidersSection: View {
    static let isAvailable = false
    let media: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

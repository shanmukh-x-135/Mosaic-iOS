import SwiftUI

/// Implemented by T2.3.
struct ReviewSection: View {
    static let isAvailable = false
    let media: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

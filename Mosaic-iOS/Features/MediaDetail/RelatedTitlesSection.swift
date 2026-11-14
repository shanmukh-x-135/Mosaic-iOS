import SwiftUI

/// Implemented by T1.1.
struct RelatedTitlesSection: View {
    static let isAvailable = false
    let media: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

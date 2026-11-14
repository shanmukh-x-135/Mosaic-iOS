import SwiftUI

/// Implemented by T1.4.
struct FranchiseLink: View {
    static let isAvailable = false
    let media: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

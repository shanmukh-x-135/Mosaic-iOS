import SwiftUI

/// Implemented by T8.1.
struct AskAboutButton: View {
    static let isAvailable = false
    let media: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

import SwiftUI

/// Implemented by T1.3.
struct EpisodeRatingsSection: View {
    static let isAvailable = false
    let series: CatalogMedia

    var body: some View {
        if !Self.isAvailable { EmptyView() }
    }
}

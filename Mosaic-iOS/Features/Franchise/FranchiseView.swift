import SwiftUI

/// Implemented by T1.4.
struct FranchiseView: View {
    static let isAvailable = false
    let slug: String

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Franchise stories will appear here.", systemImage: "square.stack")
    }
}

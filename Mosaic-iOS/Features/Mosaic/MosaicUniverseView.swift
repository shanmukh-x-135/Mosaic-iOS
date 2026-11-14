import SwiftUI

/// Implemented by T5.1.
struct MosaicUniverseView: View {
    static let isAvailable = false
    let period: String?

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Your Mosaic will appear here.", systemImage: "square.grid.2x2")
    }
}

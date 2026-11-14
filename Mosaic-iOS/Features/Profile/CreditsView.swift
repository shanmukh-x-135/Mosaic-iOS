import SwiftUI

/// Implemented by T1.4.
struct CreditsView: View {
    static let isAvailable = false

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Mosaic credits and attributions will appear here.", systemImage: "info.circle")
    }
}

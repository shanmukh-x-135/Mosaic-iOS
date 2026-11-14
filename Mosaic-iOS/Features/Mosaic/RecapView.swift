import SwiftUI

/// Implemented by T5.2.
struct RecapView: View {
    static let isAvailable = false
    let period: String

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Your story recap will appear here.", systemImage: "calendar")
    }
}

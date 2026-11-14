import SwiftUI

/// Implemented by T8.1.
struct AskView: View {
    static let isAvailable = false
    let about: String?

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Ask Mosaic will be available here.", systemImage: "bubble.left.and.bubble.right")
    }
}

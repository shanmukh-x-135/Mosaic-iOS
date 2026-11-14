import SwiftUI

/// Implemented by T6.3.
struct ImportFlowView: View {
    static let isAvailable = false

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Import your stories here.", systemImage: "square.and.arrow.down")
    }
}

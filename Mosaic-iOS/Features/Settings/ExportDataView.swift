import SwiftUI

/// Implemented by T6.2.
struct ExportDataView: View {
    static let isAvailable = false

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Export your Mosaic data here.", systemImage: "square.and.arrow.up")
    }
}

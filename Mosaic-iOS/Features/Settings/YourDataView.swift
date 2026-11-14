import SwiftUI

/// Implemented by T6.3.
struct YourDataView: View {
    static let isAvailable = false

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Tools for your Mosaic data will appear here.", systemImage: "externaldrive")
    }
}

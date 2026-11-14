import SwiftUI

/// Implemented by T4.3.
struct StatsView: View {
    static let isAvailable = false

    var body: some View {
        MosaicStateMessage(title: "Coming soon", message: "Your story statistics will appear here.", systemImage: "chart.bar")
    }
}

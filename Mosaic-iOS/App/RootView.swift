import SwiftUI

struct RootView: View {
    @Bindable var session: SessionStore

    var body: some View {
        rootContent
            .environment(session)
            .preferredColorScheme(.dark)
            .tint(MosaicColor.accent)
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-mosaic-visual-fixtures") {
            MosaicVisualFixtureGallery()
        } else {
            signedInContent
        }
        #else
        signedInContent
        #endif
    }

    @ViewBuilder
    private var signedInContent: some View {
        Group {
            switch session.state {
            case .launching: LaunchView()
            case .signedOut, .error: AuthView(session: session)
            case .signedIn: AppShell(session: session)
            }
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            MosaicColor.background.ignoresSafeArea()
            VStack(spacing: MosaicSpace.medium) {
                Image("MosaicEmblem")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .accessibilityLabel("Mosaic")
                ProgressView().tint(MosaicColor.accent).accessibilityLabel("Restoring session")
            }
        }
    }
}

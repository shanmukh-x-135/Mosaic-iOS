import SwiftUI

struct RootView: View {
    @Bindable var session: SessionStore

    var body: some View {
        Group {
            switch session.state {
            case .launching: LaunchView()
            case .signedOut, .error: AuthView(session: session)
            case .signedIn: AppShell(session: session)
            }
        }
        .preferredColorScheme(.dark)
        .tint(MosaicColor.accent)
        .onOpenURL { url in Task { await session.handleOpenURL(url) } }
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

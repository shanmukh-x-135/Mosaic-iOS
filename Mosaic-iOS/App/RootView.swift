import SwiftUI

struct RootView: View {
    @Bindable var session: SessionStore

    var body: some View {
        rootContent
            .environment(session)
            .preferredColorScheme(.dark)
            .tint(MosaicColor.accent)
            .background(MosaicColor.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if let fixture = MosaicVisualFixtures.launchConfiguration {
            MosaicFixtureRoot(configuration: fixture)
        } else {
            sessionContent
        }
        #else
        sessionContent
        #endif
    }

    @ViewBuilder
    private var sessionContent: some View {
        switch session.state {
        case .launching: LaunchView()
        case .signedOut, .error: AuthView(session: session)
        case .signedIn: AppShell(services: liveServices)
        }
    }

    private var liveServices: MosaicServices { .live(session: session) }
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

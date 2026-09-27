import SwiftUI

struct AuthView: View {
    @Bindable var session: SessionStore
    var body: some View {
        ZStack {
            MosaicColor.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: MosaicSpace.large) {
                Spacer()
                Image("MosaicWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 190, maxHeight: 40, alignment: .leading)
                    .accessibilityLabel("Mosaic")
                Text("A home for every story you follow.").font(.system(.largeTitle, design: .serif, weight: .semibold)).foregroundStyle(MosaicColor.primaryText)
                Text("Track the movies, series, games, and books that stay with you.").font(MosaicType.body).foregroundStyle(MosaicColor.secondaryText)
                if case let .error(message) = session.state { Text(message).font(.footnote).foregroundStyle(.orange) }
                Button { Task { await session.signInWithGoogle() } } label: {
                    Label("Continue with Google", systemImage: "g.circle.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(MosaicColor.accent).accessibilityHint("Opens Google sign-in")
                Spacer().frame(height: MosaicSpace.large)
            }.padding(MosaicSpace.large)
        }
    }
}

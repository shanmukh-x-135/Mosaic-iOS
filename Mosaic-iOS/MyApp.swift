import SwiftUI

@main
struct MyApp: App {
    @State private var session = SessionStore(configuration: .current)

    var body: some Scene {
        WindowGroup {
            RootView(session: session)
                .task { await session.restoreSession() }
        }
    }
}

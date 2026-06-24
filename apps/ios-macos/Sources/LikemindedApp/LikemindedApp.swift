import SwiftUI

@main
struct LikemindedApp: App {
    @StateObject private var appState = PrototypeAppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(PrototypeAppState())
}

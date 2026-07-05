import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct LikemindedApp: App {
    @StateObject private var appState = PrototypeAppState()

    init() {
        Task { @MainActor in
            GoogleSignInSupport.configureIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                    if let callback = WalletSignInSupport.parseCallbackURL(url) {
                        Task {
                            let response = AppleAuthResponse(
                                user: APIUser(id: callback.userId, email: nil, fullName: callback.fullName),
                                sessionToken: callback.sessionToken,
                                expiresIn: 60 * 60 * 24 * 30
                            )
                            await appState.completeWalletSignIn(response)
                        }
                    }
                }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(PrototypeAppState())
}

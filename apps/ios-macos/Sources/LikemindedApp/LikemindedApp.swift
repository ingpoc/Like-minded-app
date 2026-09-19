import AuthenticationServices
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct LikemindedApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await appState.validateStoredAppleCredentialIfNeeded() }
                }
                .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
                    appState.handleAppleCredentialRevoked()
                }
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

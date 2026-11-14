import AppKit
import AuthenticationServices
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct LikemindedMacApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = MacAppState()

    init() {
        Task { @MainActor in
            GoogleSignInSupport.configureIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environmentObject(appState)
                .frame(
                    minWidth: MacWindowMetrics.minWidth,
                    minHeight: MacWindowMetrics.minHeight
                )
                .preferredColorScheme(.light)
                .background(MacWindowChromeHider())
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
        .defaultSize(
            width: MacWindowMetrics.defaultWidth,
            height: MacWindowMetrics.defaultHeight
        )
        .commands {
            CommandMenu("Prototype") {
                Button("Meet") {
                    NotificationCenter.default.post(name: .macPrototypeSelectMeet, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Circles") {
                    NotificationCenter.default.post(name: .macPrototypeSelectCircles, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Communities") {
                    NotificationCenter.default.post(name: .macPrototypeSelectCommunities, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Soulmate") {
                    NotificationCenter.default.post(name: .macPrototypeSelectSoulmate, object: nil)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Profile") {
                    NotificationCenter.default.post(name: .macPrototypeSelectProfile, object: nil)
                }
                .keyboardShortcut("5", modifiers: .command)
            }
        }
    }
}

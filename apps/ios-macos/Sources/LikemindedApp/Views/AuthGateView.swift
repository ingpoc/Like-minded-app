import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var appleSignInController = AppleSignInController()

    var body: some View {
        ZStack(alignment: .topLeading) {
            ConvergenceFieldView(background: PrototypePalette.background)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Likeminded")
                        .font(.system(size: 25, weight: .semibold, design: .serif))
                        .foregroundStyle(PrototypePalette.accent)

                    Text("When you meet,\nit matters.")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .lineSpacing(1)
                        .foregroundStyle(PrototypePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("AI helps you meet the right people in the right rooms.")
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 20) {
                    AuthPromiseRow(
                        icon: "waveform",
                        title: "Voice profile",
                        detail: "Speak naturally. We understand you.",
                        accessibilityLabel: "Voice profile"
                    )
                    AuthPromiseRow(
                        icon: "shield.lefthalf.filled",
                        title: "Private by design",
                        detail: "Your data is yours. Always.",
                        accessibilityLabel: "Private by design"
                    )
                    AuthPromiseRow(
                        icon: "person.3",
                        title: "Circle placement",
                        detail: "We place you where you'll belong.",
                        accessibilityLabel: "Circle placement"
                    )
                }

                Spacer(minLength: 48)

                AuthAppleSignInButton(
                    style: .accentGreen,
                    isAuthenticating: appState.isAuthenticating,
                    accent: PrototypePalette.accent
                ) {
                    Task { await signInWithApple() }
                }

                SocialAuthButtonsView(
                    isAuthenticating: appState.isAuthenticating,
                    titleColor: PrototypePalette.ink,
                    borderColor: Color.black.opacity(0.08),
                    onGoogleSignIn: { Task { await appState.signInWithGoogle() } },
                    onMetaMaskSignIn: { Task { await appState.signInWithWallet(.metamask, controller: WalletSignInController()) } },
                    onSolflareSignIn: { Task { await appState.signInWithWallet(.solflare, controller: WalletSignInController()) } }
                )

                AuthTermsFooter(
                    accent: PrototypePalette.accent,
                    muted: PrototypePalette.subink
                )

                if appState.isAuthenticating {
                    ProgressView("Signing in")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }

                if let authError = appState.authError {
                    Text(authError)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor
    private func signInWithApple() async {
        let result = await appleSignInController.signIn()
        switch result {
        case .success(let payload):
            await appState.signIn(with: payload)
        case .failure(let error):
            appState.authError = AppleSignInSupport.userFacingMessage(for: error)
        }
    }
}

private struct AuthPromiseRow: View {
    let icon: String
    let title: String
    let detail: String
    let accessibilityLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(PrototypePalette.ink)
                .frame(width: 52, height: 52)
                .background(Color(red: 0.938, green: 0.890, blue: 0.780))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text(detail)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.ink.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}

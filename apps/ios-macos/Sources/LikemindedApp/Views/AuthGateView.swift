import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var appleSignInController = AppleSignInController()

    var body: some View {
        ZStack {
            PrototypePalette.background.ignoresSafeArea()

            LinenShape()
                .fill(Color.white.opacity(0.34))
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Likeminded")
                        .font(PrototypeTypography.hero)
                        .foregroundStyle(PrototypePalette.ink)

                    Text("Meet the right people.\nIn the right room.")
                        .font(PrototypeTypography.heroBody)
                        .foregroundStyle(PrototypePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 24) {
                    AuthPromiseRow(
                        icon: "waveform",
                        title: "Voice profile",
                        detail: "AI voice interview that understands you deeply.",
                        accessibilityLabel: "Voice profile"
                    )
                    AuthPromiseRow(
                        icon: "lock.fill",
                        title: "Private by design",
                        detail: "Your profile is private and under your control.",
                        accessibilityLabel: "Private by design"
                    )
                    AuthPromiseRow(
                        icon: "person.3",
                        title: "Circle placement",
                        detail: "We place you in the right circle and communities.",
                        accessibilityLabel: "Circle placement"
                    )
                }

                Spacer(minLength: 90)

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

                AuthPrivacyFooter(muted: PrototypePalette.subink)

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
            .frame(maxWidth: 520, alignment: .leading)
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
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(PrototypePalette.ink)
                .frame(width: 58, height: 58)
                .background(Color(red: 0.938, green: 0.890, blue: 0.780))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
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

private struct LinenShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX * 0.42, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * 0.62),
            control1: CGPoint(x: rect.maxX * 0.86, y: rect.maxY * 0.05),
            control2: CGPoint(x: rect.maxX * 0.66, y: rect.maxY * 0.42)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.42, y: rect.minY),
            control1: CGPoint(x: rect.maxX * 0.24, y: rect.maxY * 0.70),
            control2: CGPoint(x: rect.maxX * 0.16, y: rect.maxY * 0.18)
        )
        return path
    }
}

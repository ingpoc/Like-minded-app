import SwiftUI

struct SocialAuthButtonsView: View {
    let isAuthenticating: Bool
    let onGoogleSignIn: () -> Void
    let onMetaMaskSignIn: () -> Void
    let onSolflareSignIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            AuthProviderButton(
                title: "Continue with Google",
                icon: "g.circle.fill",
                foreground: .primary,
                background: Color.white,
                border: Color.black.opacity(0.08),
                isAuthenticating: isAuthenticating,
                action: onGoogleSignIn
            )

            AuthProviderButton(
                title: "Continue with MetaMask",
                icon: "wallet.pass.fill",
                foreground: .white,
                background: Color(red: 0.95, green: 0.55, blue: 0.17),
                border: .clear,
                isAuthenticating: isAuthenticating,
                action: onMetaMaskSignIn
            )

            AuthProviderButton(
                title: "Continue with Solflare",
                icon: "sun.max.fill",
                foreground: .white,
                background: Color(red: 0.98, green: 0.45, blue: 0.09),
                border: .clear,
                isAuthenticating: isAuthenticating,
                action: onSolflareSignIn
            )
        }
    }
}

private struct AuthProviderButton: View {
    let title: String
    let icon: String
    let foreground: Color
    let background: Color
    let border: Color
    let isAuthenticating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(border, lineWidth: border == .clear ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
        .accessibilityLabel(title)
    }
}

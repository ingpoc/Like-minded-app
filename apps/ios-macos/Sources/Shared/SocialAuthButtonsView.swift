import SwiftUI

struct SocialAuthButtonsView: View {
    let isAuthenticating: Bool
    var titleColor: Color = Color(red: 0.063, green: 0.165, blue: 0.145)
    var borderColor: Color = Color.black.opacity(0.08)
    let onGoogleSignIn: () -> Void
    let onMetaMaskSignIn: () -> Void
    let onSolflareSignIn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            AuthProviderButton(
                title: "Continue with Google",
                brand: .google,
                titleColor: titleColor,
                borderColor: borderColor,
                isAuthenticating: isAuthenticating,
                action: onGoogleSignIn
            )

            AuthProviderButton(
                title: "Continue with MetaMask",
                brand: .metamask,
                titleColor: titleColor,
                borderColor: borderColor,
                isAuthenticating: isAuthenticating,
                action: onMetaMaskSignIn
            )

            AuthProviderButton(
                title: "Continue with Solflare",
                brand: .solflare,
                titleColor: titleColor,
                borderColor: borderColor,
                isAuthenticating: isAuthenticating,
                action: onSolflareSignIn
            )
        }
    }
}

private struct AuthProviderButton: View {
    let title: String
    let brand: AuthBrandMark
    let titleColor: Color
    let borderColor: Color
    let isAuthenticating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                brand.view
                    .frame(width: 22, height: 22)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(titleColor)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
        .accessibilityLabel(title)
    }
}

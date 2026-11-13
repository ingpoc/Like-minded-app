import SwiftUI

struct SocialAuthButtonsView: View {
    let isAuthenticating: Bool
    var titleColor: Color = Color(red: 0.063, green: 0.165, blue: 0.145)
    var borderColor: Color = Color.black.opacity(0.08)
    /// When false, wallet providers stay behind disclosure (invite/MVP primary path).
    var showWalletProvidersByDefault: Bool = false
    let onGoogleSignIn: () -> Void
    let onMetaMaskSignIn: () -> Void
    let onSolflareSignIn: () -> Void

    @State private var showWalletProviders = false

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

            if showWalletProvidersByDefault || showWalletProviders {
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
            } else {
                Button {
                    showWalletProviders = true
                } label: {
                    Text("More sign-in options")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(titleColor.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More sign-in options")
                .accessibilityHint("Shows MetaMask and Solflare wallet sign-in")
                .accessibilityIdentifier("auth-more-sign-in-options")
            }
        }
        .onAppear {
            if showWalletProvidersByDefault {
                showWalletProviders = true
            }
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

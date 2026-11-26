import SwiftUI

struct AuthAppleSignInButton: View {
    let isAuthenticating: Bool
    var isActiveProvider: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "applelogo")
                    .font(.title3)
                Text(isActiveProvider ? "Signing in" : "Sign in with Apple")
                    .font(LikemindedTypography.button)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(LikemindedPalette.appleSignInBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(LikemindedPalette.appleSignInForeground)
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
        .accessibilityLabel(isActiveProvider ? "Signing in with Apple" : "Sign in with Apple")
    }
}

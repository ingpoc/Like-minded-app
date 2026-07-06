import SwiftUI

struct AuthAppleSignInButton: View {
    enum Style {
        case accentGreen
        case black
    }

    let style: Style
    let isAuthenticating: Bool
    var accent: Color = Color(red: 0.059, green: 0.290, blue: 0.239)
    let action: () -> Void

    private var background: Color {
        switch style {
        case .accentGreen: accent
        case .black: .black
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "applelogo")
                    .font(.title3)
                Text(isAuthenticating ? "Signing in" : "Sign in with Apple")
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background, in: RoundedRectangle(cornerRadius: style == .accentGreen ? 18 : 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isAuthenticating)
        .accessibilityLabel("Sign in with Apple")
    }
}

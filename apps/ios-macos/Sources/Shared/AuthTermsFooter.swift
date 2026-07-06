import SwiftUI

struct AuthTermsFooter: View {
    var accent: Color
    var muted: Color
    var onPrivacyTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "lock")
                    .font(.system(size: 11, weight: .semibold))
                Text("By continuing, you agree to our")
            }
            Button("Terms & Privacy Policy") {
                onPrivacyTap?()
            }
            .buttonStyle(.plain)
            .underline()
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .tint(accent)
    }
}

struct AuthPrivacyFooter: View {
    var muted: Color

    var body: some View {
        Label("Your data is private and never shared.", systemImage: "lock")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(muted)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

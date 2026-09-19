import SwiftUI

struct AuthTermsFooter: View {
    var accent: Color
    var muted: Color
    var onPrivacyTap: (() -> Void)?

    @State private var showPrivacySheet = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "lock")
                    .font(.system(size: 11, weight: .semibold))
                Text("By continuing, you agree to our")
            }
            Button("Terms & Privacy Policy") {
                showPrivacySheet = true
                onPrivacyTap?()
            }
            .buttonStyle(.plain)
            .underline()
            .accessibilityLabel("Terms & Privacy Policy")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("auth-privacy-link")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .tint(accent)
        .sheet(isPresented: $showPrivacySheet) {
            NavigationStack {
                AuthPrivacyPolicySheet()
                    .navigationTitle(LikemindedPrivacyPolicy.title)
            }
            .frame(minWidth: 520, minHeight: 420)
        }
    }
}

struct AuthPrivacyPolicySheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(LikemindedPrivacyPolicy.title)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .accessibilityAddTraits(.isHeader)

                Text(LikemindedPrivacyPolicy.intro)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(LikemindedPrivacyPolicy.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title.uppercased())
                            .font(.caption.weight(.semibold))
                        Divider()
                        ForEach(section.items, id: \.self) { item in
                            Text("•  \(item)")
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text(LikemindedPrivacyPolicy.footer)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                Link("Open public privacy policy", destination: LikemindedPrivacyPolicy.publicURL)
                    .font(.body.weight(.semibold))
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 420)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LikemindedPrivacyPolicy.title)
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

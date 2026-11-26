import SwiftUI

struct AuthTermsFooter: View {
    var accent: Color
    var muted: Color
    var onPrivacyTap: (() -> Void)?

    @State private var showPrivacySheet = false

    var body: some View {
        // Single wrapping line so macOS welcome never clips “By continuing…” at the
        // window edge (legal must stay fully readable under Private by design).
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "lock")
                .font(LikemindedTypography.caption.weight(.semibold))
            Text("By continuing, you agree to our")
                .fixedSize(horizontal: false, vertical: true)
            Button("Terms & Privacy Policy") {
                showPrivacySheet = true
                onPrivacyTap?()
            }
            .buttonStyle(.plain)
            .underline()
            .accessibilityLabel("Terms & Privacy Policy")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("auth-privacy-link")
            .fixedSize(horizontal: true, vertical: true)
        }
        .font(LikemindedTypography.caption.weight(.medium))
        .foregroundStyle(muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
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
                    .font(LikemindedTypography.pageTitle)
                    .accessibilityAddTraits(.isHeader)

                Text(LikemindedPrivacyPolicy.intro)
                    .font(LikemindedTypography.body)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(LikemindedPrivacyPolicy.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title.uppercased())
                            .font(LikemindedTypography.caption.weight(.semibold))
                        Divider()
                        ForEach(section.items, id: \.self) { item in
                            Text("•  \(item)")
                                .font(LikemindedTypography.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text(LikemindedPrivacyPolicy.footer)
                    .font(LikemindedTypography.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                Link("Open public privacy policy", destination: LikemindedPrivacyPolicy.publicURL)
                    .font(LikemindedTypography.body.weight(.semibold))
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
            .font(LikemindedTypography.caption.weight(.medium))
            .foregroundStyle(muted)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

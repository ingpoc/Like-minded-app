import AuthenticationServices
import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        ZStack {
            PrototypePalette.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Likeminded")
                        .font(PrototypeTypography.hero)
                        .foregroundStyle(PrototypePalette.ink)

                    Text("Start with a private AI voice profile. Your placement is created only after you sign in.")
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.subink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Voice profile", systemImage: "waveform.circle")
                    Label("Private profile review", systemImage: "person.text.rectangle")
                    Label("Circle placement", systemImage: "person.3.fill")
                }
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                            appState.authError = "Apple sign-in returned an unsupported credential."
                            return
                        }
                        Task { await appState.signIn(with: credential) }
                    case .failure(let error):
                        appState.authError = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .disabled(appState.isAuthenticating)

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
}

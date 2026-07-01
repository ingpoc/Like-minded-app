import AuthenticationServices
import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var appState: PrototypeAppState

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
                        detail: "AI voice interview that understands you deeply."
                    )
                    AuthPromiseRow(
                        icon: "person.crop.rectangle",
                        title: "Private by design",
                        detail: "Your profile is private and under your control."
                    )
                    AuthPromiseRow(
                        icon: "person.3",
                        title: "Circle placement",
                        detail: "We place you in the right circle and communities."
                    )
                }

                Spacer(minLength: 90)

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
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(appState.isAuthenticating)

                Label("Your data is private and never shared.", systemImage: "lock")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
                    .frame(maxWidth: .infinity, alignment: .center)

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

private struct AuthPromiseRow: View {
    let icon: String
    let title: String
    let detail: String

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

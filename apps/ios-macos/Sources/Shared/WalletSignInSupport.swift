import AuthenticationServices
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum WalletProvider: String, CaseIterable {
    case metamask
    case solflare

    var title: String {
        switch self {
        case .metamask: "MetaMask"
        case .solflare: "Solflare"
        }
    }

    var chain: String {
        switch self {
        case .metamask: "ethereum"
        case .solflare: "solana"
        }
    }
}

struct WalletChallengeResponse: Decodable {
    let challengeId: String
    let wallet: String
    let chain: String
    let message: String
    let expiresAt: String
}

struct WalletAuthCallback: Equatable {
    let sessionToken: String
    let userId: String
    let fullName: String?
}

enum WalletSignInSupport {
    static var callbackScheme: String {
        Bundle.main.bundleIdentifier ?? "com.likeminded.app"
    }

    static func redirectScheme(for bundle: Bundle = .main) -> String {
        "\(callbackScheme)://auth/wallet"
    }

    static func parseCallbackURL(_ url: URL) -> WalletAuthCallback? {
        guard url.host == "auth" else { return nil }
        guard url.path == "/wallet" || url.path == "wallet" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let sessionToken = components.queryItems?.first(where: { $0.name == "sessionToken" })?.value,
              let userId = components.queryItems?.first(where: { $0.name == "userId" })?.value else {
            return nil
        }
        let fullName = components.queryItems?.first(where: { $0.name == "fullName" })?.value
        return WalletAuthCallback(sessionToken: sessionToken, userId: userId, fullName: fullName)
    }
}

@MainActor
final class WalletSignInController: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func signIn(baseURL: URL, wallet: WalletProvider) async throws -> WalletAuthCallback {
        let challengeURL = baseURL.appendingPathComponent("/v1/auth/wallet/challenge")
        var challengeRequest = URLRequest(url: challengeURL)
        challengeRequest.httpMethod = "POST"
        challengeRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        challengeRequest.httpBody = try JSONEncoder().encode(["wallet": wallet.rawValue, "chain": wallet.chain])

        let (challengeData, challengeResponse) = try await URLSession.shared.data(for: challengeRequest)
        guard let httpChallenge = challengeResponse as? HTTPURLResponse, 200..<300 ~= httpChallenge.statusCode else {
            let message = String(data: challengeData, encoding: .utf8) ?? "Wallet challenge failed"
            throw URLError(.userAuthenticationRequired, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let challenge = try JSONDecoder().decode(WalletChallengeResponse.self, from: challengeData)

        var signURLComponents = URLComponents(url: baseURL.appendingPathComponent("/v1/auth/wallet/sign"), resolvingAgainstBaseURL: false)
        signURLComponents?.queryItems = [
            URLQueryItem(name: "wallet", value: wallet.rawValue),
            URLQueryItem(name: "challengeId", value: challenge.challengeId),
            URLQueryItem(name: "redirect", value: WalletSignInSupport.redirectScheme())
        ]
        guard let signURL = signURLComponents?.url else {
            throw URLError(.badURL)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(
                url: signURL,
                callbackURLScheme: WalletSignInSupport.callbackScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL, let callback = WalletSignInSupport.parseCallbackURL(callbackURL) else {
                    continuation.resume(throwing: URLError(.userAuthenticationRequired, userInfo: [
                        NSLocalizedDescriptionKey: "Wallet sign-in did not return a valid callback."
                    ]))
                    return
                }
                continuation.resume(returning: callback)
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.session = authSession
            if !authSession.start() {
                continuation.resume(throwing: URLError(.userAuthenticationRequired, userInfo: [
                    NSLocalizedDescriptionKey: "Wallet sign-in could not be started."
                ]))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        #else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
        #endif
    }
}

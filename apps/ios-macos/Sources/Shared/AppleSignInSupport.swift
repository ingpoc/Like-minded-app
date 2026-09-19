import AuthenticationServices
import CryptoKit
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AppleSignInCredentialPayload {
    let identityToken: String
    let authorizationCode: String?
    let fullName: String?
    let userIdentifier: String
    let rawNonce: String
}

enum AppleCredentialStateResult: Equatable {
    case authorized
    case revoked
    case notFound
    case transferred
    case unavailable
}

enum AppleSignInSupport {
    static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    static func fullName(from credential: ASAuthorizationAppleIDCredential) -> String? {
        guard let components = credential.fullName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    static func payload(from credential: ASAuthorizationAppleIDCredential, rawNonce: String) throws -> AppleSignInCredentialPayload {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AppleSignInError.missingIdentityToken
        }

        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        return AppleSignInCredentialPayload(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: fullName(from: credential),
            userIdentifier: credential.user,
            rawNonce: rawNonce
        )
    }

    static func userFacingMessage(for error: Error) -> String {
        if let signInError = error as? AppleSignInError {
            return signInError.localizedDescription
        }

        if let authError = error as? ASAuthorizationError {
            if authError.code == .canceled {
                return "Sign in was canceled."
            }
            return authError.localizedDescription
        }

        return error.localizedDescription
    }

    static func credentialState(for userIdentifier: String) async -> AppleCredentialStateResult {
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userIdentifier)
            switch state {
            case .authorized:
                return .authorized
            case .revoked:
                return .revoked
            case .notFound:
                return .notFound
            case .transferred:
                return .transferred
            @unknown default:
                return .unavailable
            }
        } catch {
            return .unavailable
        }
    }
}

enum AppleSignInError: LocalizedError {
    case missingIdentityToken
    case unsupportedCredential

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple did not return an identity token."
        case .unsupportedCredential:
            return "Apple sign-in returned an unsupported credential."
        }
    }
}

@MainActor
final class AppleSignInController: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var rawNonce = ""
    private var continuation: CheckedContinuation<Result<AppleSignInCredentialPayload, Error>, Never>?

    func signIn(requestedScopes: [ASAuthorization.Scope] = [.fullName, .email]) async -> Result<AppleSignInCredentialPayload, Error> {
        rawNonce = AppleSignInSupport.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = requestedScopes
        request.nonce = AppleSignInSupport.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first { $0.isKeyWindow } ?? NSWindow()
        #else
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
        #endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(with: .failure(AppleSignInError.unsupportedCredential))
            return
        }

        do {
            let payload = try AppleSignInSupport.payload(from: credential, rawNonce: rawNonce)
            finish(with: .success(payload))
        } catch {
            finish(with: .failure(error))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(with: .failure(error))
    }

    private func finish(with result: Result<AppleSignInCredentialPayload, Error>) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

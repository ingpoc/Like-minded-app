import Foundation
#if os(macOS)
import AppKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if os(iOS)
import UIKit
#endif

enum GoogleSignInSupport {
    static var isConfigured: Bool {
        clientID != nil
    }

    static var clientID: String? {
        #if os(macOS)
        if let env = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID_MAC"], !env.isEmpty {
            return env
        }
        #endif
        if let env = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID_IOS"], !env.isEmpty {
            return env
        }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, !configured.isEmpty {
            return configured
        }
        return nil
    }

    @MainActor
    static func configureIfNeeded() {
        #if canImport(GoogleSignIn)
        guard let clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        #endif
    }

    @MainActor
    static func signIn() async throws -> String {
        #if canImport(GoogleSignIn)
        configureIfNeeded()
        guard GIDSignIn.sharedInstance.configuration != nil else {
            throw GoogleSignInError.notConfigured
        }

        let result: GIDSignInResult
        #if os(macOS)
        guard let presentingWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            throw GoogleSignInError.noPresentationAnchor
        }
        result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow)
        #else
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController else {
            throw GoogleSignInError.noPresentationAnchor
        }
        result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        #endif

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.missingIDToken
        }
        return idToken
        #else
        throw GoogleSignInError.notConfigured
        #endif
    }
}

enum GoogleSignInError: LocalizedError {
    case notConfigured
    case missingIDToken
    case noPresentationAnchor

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google sign-in is not configured for this build."
        case .missingIDToken:
            return "Google did not return an identity token."
        case .noPresentationAnchor:
            return "Google sign-in could not be presented."
        }
    }
}

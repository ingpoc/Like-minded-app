import Foundation

struct ProfileCircleMatchRequest: Encodable {
    let interviewTranscript: String?
    let reflectionAnswers: [String]?
}

struct ProfileCircleMatchResult: Decodable {
    let profileId: String
    let signals: ProfileSignals
    let placement: CirclePlacement
    let allCircleFits: [CircleFitScore]?
    let placementId: String?
}

struct CircleFitScore: Decodable, Identifiable {
    let circleId: String
    let name: String
    let score: Double

    var id: String { circleId }
}

struct LikemindedAPIClient {
    var baseURL = LikemindedAPIClient.defaultBaseURL()
    var authToken: String?

    private let deviceId = DeviceIdentity.current

    static func defaultBaseURL() -> URL {
        if let override = ProcessInfo.processInfo.environment["LIKEMINDED_API_BASE_URL"],
           let url = URL(string: override),
           !override.isEmpty {
            return url
        }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "LIKEMINDED_API_BASE_URL") as? String,
           let url = URL(string: configured),
           !configured.isEmpty {
            return url
        }
        #if DEBUG
        return URL(string: "http://127.0.0.1:8787")!
        #else
        return URL(string: "https://likeminded-api.onrender.com")!
        #endif
    }

    private func applyCommonHeaders(_ request: inout URLRequest, isJSON: Bool = true) {
        if isJSON {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }

    func authenticateWithApple(identityToken: String, authorizationCode: String?, fullName: String?) async throws -> AppleAuthResponse {
        let url = baseURL.appendingPathComponent("/v1/auth/apple")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(
            AppleAuthRequest(identityToken: identityToken, authorizationCode: authorizationCode, fullName: fullName)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let errorText = String(data: data, encoding: .utf8) ?? "Authentication failed"
            throw URLError(.userAuthenticationRequired, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
        return try JSONDecoder().decode(AppleAuthResponse.self, from: data)
    }

    func createRealtimeSession(safetyIdentifier: String) async throws -> RealtimeSessionEnvelope {
        let url = baseURL.appendingPathComponent("/v1/realtime/session")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(
            RealtimeSessionRequest(safetyIdentifier: safetyIdentifier)
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(RealtimeSessionEnvelope.self, from: data)
    }

    /// WebRTC SDP exchange — sends local SDP offer, receives remote SDP answer
    func exchangeSDP(_ sdpOffer: String) async throws -> String {
        let url = baseURL.appendingPathComponent("/v1/realtime/calls")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "content-type")
        applyCommonHeaders(&request, isJSON: false)
        request.httpBody = sdpOffer.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: errorText])
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    func fetchReflectPlaceConnect(reflectionAnswers: [String]) async throws -> ReflectPlaceConnectSlice {
        let url = baseURL.appendingPathComponent("/v1/mvp/reflect-place-connect")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(
            ReflectPlaceConnectRequest(reflectionAnswers: reflectionAnswers)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ReflectPlaceConnectSlice.self, from: data)
    }

    func createProfileFromInterview(interviewTranscript: String?, reflectionAnswers: [String]?) async throws -> ProfileCircleMatchResult {
        let url = baseURL.appendingPathComponent("/v1/discover")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(
            ProfileCircleMatchRequest(
                interviewTranscript: interviewTranscript,
                reflectionAnswers: reflectionAnswers
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ProfileCircleMatchResult.self, from: data)
    }

    func fetchMyPlacement() async throws -> ProfileCircleMatchResult {
        let url = baseURL.appendingPathComponent("/v1/me/placement")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.resourceUnavailable)
        }
        return try JSONDecoder().decode(ProfileCircleMatchResult.self, from: data)
    }

    func updateProfile(reflectionSummary: String?, signals: ProfileSignals?) async throws {
        let url = baseURL.appendingPathComponent("/v1/me/profile")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(ProfileUpdateRequest(reflectionSummary: reflectionSummary, signals: signals))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func updatePlacement(action: String) async throws -> ProfileCircleMatchResult {
        let url = baseURL.appendingPathComponent("/v1/me/placement/actions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(PlacementActionRequest(action: action))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ProfileCircleMatchResult.self, from: data)
    }

    func submitFeedback(profileId: String?, placementId: String?, rating: Int, message: String, appVersion: String) async throws {
        let url = baseURL.appendingPathComponent("/v1/feedback")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(
            FeedbackRequest(profileId: profileId, placementId: placementId, rating: rating, message: message, appVersion: appVersion)
        )
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }
}

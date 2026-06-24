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
}

struct CircleFitScore: Decodable, Identifiable {
    let circleId: String
    let name: String
    let score: Double

    var id: String { circleId }
}

struct LikemindedAPIClient {
    var baseURL = URL(string: "http://127.0.0.1:8787")!

    private let deviceId = DeviceIdentity.current

    func createRealtimeSession(safetyIdentifier: String) async throws -> RealtimeSessionEnvelope {
        let url = baseURL.appendingPathComponent("/v1/realtime/session")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
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
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
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
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
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
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
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
}

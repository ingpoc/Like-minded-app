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
    let profileSummary: String?
    let basicInfo: BasicInfo?
    let interests: [Interest]?
    let hiddenSignals: HiddenSignals?
}

struct CircleFitScore: Decodable, Identifiable {
    let circleId: String
    let name: String
    let score: Double

    var id: String { circleId }
}

struct CommunitiesResponse: Decodable {
    let communities: [Community]
}

struct CommunityResponse: Decodable {
    let community: Community
}

struct CirclesResponse: Decodable {
    let circles: [PlacementCircle]
}

struct MeetingRSVPRequest: Encodable {
    let kind: String
    let available: Bool
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

    func registerCircleConcern() async throws {
        let url = baseURL.appendingPathComponent("/v1/me/circles/concern")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func fetchCircles() async throws -> [PlacementCircle] {
        let url = baseURL.appendingPathComponent("/v1/circles")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CirclesResponse.self, from: data).circles
    }

    func fetchMyCircles() async throws -> [PlacementCircle] {
        let url = baseURL.appendingPathComponent("/v1/me/circles")
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CirclesResponse.self, from: data).circles
    }

    func fetchCommunities() async throws -> [Community] {
        let url = baseURL.appendingPathComponent("/v1/communities")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CommunitiesResponse.self, from: data).communities
    }

    func fetchMyCommunities() async throws -> [Community] {
        let url = baseURL.appendingPathComponent("/v1/me/communities")
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CommunitiesResponse.self, from: data).communities
    }

    func joinCommunity(id: String) async throws {
        try await updateCommunityMembership(id: id, action: "join")
    }

    func leaveCommunity(id: String) async throws {
        try await updateCommunityMembership(id: id, action: "leave")
    }

    func updateMeetingRSVP(kind: String, available: Bool) async throws {
        let url = baseURL.appendingPathComponent("/v1/meetings/rsvp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(MeetingRSVPRequest(kind: kind, available: available))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func fetchMeetings() async throws -> MeetingsResponse {
        let url = baseURL.appendingPathComponent("/v1/meetings/upcoming")
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MeetingsResponse.self, from: data)
    }

    func saveMeetingRecapNote(meetingId: String, note: String) async throws {
        let url = baseURL
            .appendingPathComponent("/v1/meetings")
            .appendingPathComponent(meetingId)
            .appendingPathComponent("recap-note")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(MeetingRecapNoteRequest(note: note))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func joinMeeting(id: String) async throws -> LiveKitJoinToken {
        let url = baseURL
            .appendingPathComponent("/v1/meetings")
            .appendingPathComponent(id)
            .appendingPathComponent("join")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LiveKitJoinToken.self, from: data)
    }

    func fetchSoulmateStatus() async throws -> SoulmateStatus {
        let url = baseURL
            .appendingPathComponent("/v1/me/soulmate/status")
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SoulmateStatus.self, from: data)
    }

    func setSoulmateEnabled(_ enabled: Bool) async throws {
        let url = baseURL.appendingPathComponent("/v1/me/soulmate/enable")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(SoulmateEnableRequest(enabled: enabled))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func submitSoulmateSelection(meetingId: String, selectedUserIds: [String]) async throws {
        let url = baseURL.appendingPathComponent("/v1/me/soulmate/select")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(SoulmateSelectionRequest(meetingId: meetingId, selectedUserIds: selectedUserIds))
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }

    func fetchSoulmateMatches() async throws -> [SoulmateMatch] {
        let url = baseURL.appendingPathComponent("/v1/me/soulmate/matches")
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([SoulmateMatch].self, from: data)
    }

    func fetchSoulmateMatchDetail(id: String) async throws -> SoulmateMatchDetail {
        let url = baseURL
            .appendingPathComponent("/v1/me/soulmate/matches")
            .appendingPathComponent(id)
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SoulmateMatchDetail.self, from: data)
    }

    func fetchMessages(matchId: String) async throws -> [ChatMessage] {
        let url = baseURL
            .appendingPathComponent("/v1/me/soulmate/matches")
            .appendingPathComponent(matchId)
            .appendingPathComponent("messages")
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ChatMessagesResponse.self, from: data).messages
    }

    func sendMessage(matchId: String, text: String) async throws -> ChatMessage {
        let url = baseURL
            .appendingPathComponent("/v1/me/soulmate/matches")
            .appendingPathComponent(matchId)
            .appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        request.httpBody = try JSONEncoder().encode(ChatMessageRequest(text: text))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SentChatMessageResponse.self, from: data).message
    }

    private func updateCommunityMembership(id: String, action: String) async throws {
        let url = baseURL
            .appendingPathComponent("/v1/communities")
            .appendingPathComponent(id)
            .appendingPathComponent(action)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyCommonHeaders(&request)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
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

    func fetchNotifications() async throws -> NotificationsResponse {
        let url = baseURL.appendingPathComponent("/v1/me/notifications")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(NotificationsResponse.self, from: data)
    }

    func fetchCommunityMembers(id: String) async throws -> [CommunityMember] {
        let url = baseURL.appendingPathComponent("/v1/communities/\(id)/members")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CommunityMembersResponse.self, from: data).members
    }
}

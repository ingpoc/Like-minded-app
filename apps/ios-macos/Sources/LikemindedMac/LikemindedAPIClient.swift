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

struct CircleResponse: Decodable {
    let circle: PlacementCircle
}

struct MeetingRSVPRequest: Encodable {
    let kind: String
    let available: Bool
}

struct LikemindedAPIClient {
    var baseURL = LikemindedAPIClient.defaultBaseURL()
    var authToken: String?

    static func defaultBaseURL() -> URL {
        URL(string: MacBackendConfig.baseURLString)!
    }

    private func applyCommonHeaders(_ request: inout URLRequest, isJSON: Bool = true) {
        if isJSON {
            request.setValue("application/json", forHTTPHeaderField: "content-type")
        }
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

    func fetchMyProfile() async throws -> UserProfile {
        let url = baseURL.appendingPathComponent("/v1/me/profile")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(&request, isJSON: false)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.resourceUnavailable)
        }
        return try JSONDecoder().decode(UserProfileResponse.self, from: data).profile
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

    func fetchCircleDetail(id: String) async throws -> PlacementCircle {
        let url = baseURL
            .appendingPathComponent("/v1/circles")
            .appendingPathComponent(id)
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CircleResponse.self, from: data).circle
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

    func fetchCommunityMembers(id: String) async throws -> [CommunityMember] {
        let url = baseURL.appendingPathComponent("/v1/communities/\(id)/members")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(CommunityMembersResponse.self, from: data).members
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

    func fetchNotifications() async throws -> MacNotificationsResponse {
        let url = baseURL.appendingPathComponent("/v1/me/notifications")
        var request = URLRequest(url: url)
        applyCommonHeaders(&request, isJSON: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MacNotificationsResponse.self, from: data)
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
}

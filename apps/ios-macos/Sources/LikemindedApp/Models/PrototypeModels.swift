import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case meet = "Meet"
    case circles = "Circles"
    case communities = "Communities"
    case soulmate = "Soulmate"
    case profile = "Profile"

    var id: String { rawValue }

    static func visible(soulmateEnabled: Bool) -> [AppTab] {
        allCases.filter { $0 != .soulmate || soulmateEnabled }
    }

    var systemImage: String {
        switch self {
        case .meet:
            return "person.2.video"
        case .circles:
            return "door.left.hand.open"
        case .communities:
            return "person.2.badge.gearshape"
        case .profile:
            return "person.crop.circle"
        case .soulmate:
            return "heart.circle"
        }
    }
}

struct ReflectionPrompt: Identifiable {
    let id = UUID()
    let prompt: String
    let note: String
}

struct Community: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String
    let themes: [String]
    let meetingFormat: String
    let membersCount: Int
}

struct Meeting: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let kind: String
    let targetId: String
    let title: String
    let scheduledAt: String
    let hostUserId: String
    let hostName: String
    let groupSize: Int
    let status: String
    let compositionSummary: String
    var recapNote: String?

    var scheduledAtDate: Date {
        LikemindedDate.parse(scheduledAt) ?? Date()
    }
}

enum LikemindedDate {
    private static let fractionalISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plainISO8601 = ISO8601DateFormatter()

    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return fractionalISO8601.date(from: value) ?? plainISO8601.date(from: value)
    }

    static func short(_ value: String?) -> String {
        guard let date = parse(value) else { return value.map { String($0.prefix(10)) } ?? "Now" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func full(_ value: String) -> String {
        guard let date = parse(value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct MeetingRsvps: Codable, Equatable {
    let circle: Bool
    let community: Bool
}

struct MeetingRecapNoteRequest: Encodable {
    let note: String
}

struct MeetingsResponse: Decodable {
    let rsvps: MeetingRsvps
    let upcoming: [Meeting]
    let past: [Meeting]
}

struct LiveKitJoinToken: Decodable {
    let token: String
    let url: String
}

struct NotificationItem: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
    let createdAt: String?
    let kind: String
}

struct NotificationsResponse: Decodable {
    let notifications: [NotificationItem]
    let activity: [NotificationItem]
}

struct CommunityMember: Codable, Identifiable, Equatable {
    let userId: String
    let name: String
    let gender: String?

    var id: String { userId }
}

struct CommunityMembersResponse: Decodable {
    let members: [CommunityMember]
}

struct SoulmateStatus: Decodable {
    let enabled: Bool
    let pendingSelections: [SoulmatePendingSelection]
}

struct SoulmatePendingSelection: Decodable, Identifiable {
    let meetingId: String
    let potentialMatches: [String]
    let potentialMatchDetails: [SoulmatePotentialMatch]?

    var id: String { meetingId }
}

struct SoulmatePotentialMatch: Decodable, Identifiable, Equatable {
    let userId: String
    let name: String

    var id: String { userId }
}

struct SoulmateMatch: Decodable, Identifiable, Equatable {
    let matchId: String
    let userId: String
    let name: String
    let meetingId: String
    let meetingDate: String?
    let createdAt: String

    var id: String { matchId }
}

struct SoulmateMatchDetail: Decodable, Equatable {
    struct BasicInfo: Decodable, Equatable {
        let name: String?
        let gender: String?
    }

    let matchId: String
    let userId: String
    let name: String
    let meetingId: String
    let meetingDate: String?
    let createdAt: String
    let basicInfo: BasicInfo
    let interests: [Interest]
}

struct ChatMessage: Decodable, Identifiable, Equatable {
    let id: String
    let matchId: String
    let senderId: String
    let text: String
    let createdAt: String
}

struct SoulmateEnableRequest: Encodable {
    let enabled: Bool
}

struct SoulmateSelectionRequest: Encodable {
    let meetingId: String
    let selectedUserIds: [String]
}

struct ChatMessageRequest: Encodable {
    let text: String
}

struct ChatMessagesResponse: Decodable {
    let messages: [ChatMessage]
}

struct SentChatMessageResponse: Decodable {
    let message: ChatMessage
}

struct MatchRecommendation: Identifiable {
    let id: String
    let name: String
    let compatibility: Int
    let headline: String
    let explanation: String
    let nextStep: String
}

struct ChatPreview: Identifiable {
    let id: String
    let name: String
    let status: String
    let lastMessage: String
    let timestamp: String
}

struct PrivacyControl: Identifiable {
    let id: String
    let title: String
    let detail: String
    var isEnabled: Bool
}

struct ReflectPlaceConnectRequest: Encodable {
    let reflectionAnswers: [String]
}

struct RealtimeSessionRequest: Encodable {
    let safetyIdentifier: String
}

struct AppleAuthRequest: Encodable {
    let identityToken: String
    let authorizationCode: String?
    let fullName: String?
}

struct AppleAuthResponse: Decodable {
    let user: APIUser
    let sessionToken: String
    let expiresIn: Int
}

struct APIUser: Decodable {
    let id: String
    let email: String?
    let fullName: String?
}

struct ProfileUpdateRequest: Encodable {
    let reflectionSummary: String?
    let signals: ProfileSignals?
}

struct BasicInfo: Codable, Equatable {
    let name: String
    let gender: Gender
    let dateOfBirth: String
    let city: String
    let pincode: String
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male
    case female
    case nonBinary
    case preferNotToSay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .nonBinary:
            return "Non-binary"
        case .preferNotToSay:
            return "Prefer not to say"
        }
    }
}

struct Interest: Codable, Equatable, Identifiable {
    var id: String { "\(area)-\(label)" }
    let area: String
    let label: String
    let depth: InterestDepth
}

enum InterestDepth: String, Codable, Equatable {
    case casual
    case active
    case deep
}

struct HiddenSignals: Codable, Equatable {
    let shyness: Double?
    let languageComfort: String?
    let warmth: Double?
    let vulnerabilityOpenness: Double?
    let dominanceTendency: Double?
    let energyTrajectory: String?
}

struct PlacementActionRequest: Encodable {
    let action: String
}

struct FeedbackRequest: Encodable {
    let profileId: String?
    let placementId: String?
    let rating: Int
    let message: String
    let appVersion: String
}

struct ProfileSignals: Codable, Equatable {
    struct BigFive: Codable, Equatable {
        var openness: Double = 0.5
        var conscientiousness: Double = 0.5
        var extraversion: Double = 0.5
        var agreeableness: Double = 0.5
        var neuroticism: Double = 0.5
    }

    var bigFive: BigFive = BigFive()
    var attachment: String? = nil
    var socialEnergy: String? = nil
    var communicationStyle: CommunicationStyle? = nil
    var trustPattern: String? = nil
    var humorStyle: String? = nil
    var conflictStyle: String? = nil

    struct CommunicationStyle: Codable, Equatable {
        var primary: String? = nil
        var pace: Double = 0.5
    }
}

struct SynthesizedProfileResult: Codable {
    let profileId: String
    let signals: ProfileSignals
    let synthesizedAt: String
}

struct PlacementActionGroup: Codable {
    let primaryAction: String
    let swapAction: String
    let deferAction: String
}

struct RealtimeSessionEnvelope: Decodable {
    let transport: String
    let model: String
    let voice: String
    let clientSecret: RealtimeClientSecret

    var isReady: Bool {
        clientSecret.value != nil
    }
}

struct RealtimeClientSecret: Decodable {
    let value: String?
    let error: String?
    let message: String?
}

struct ReflectPlaceConnectSlice: Codable {
    let journey: [MVPJourneyStep]
    var profile: SynthesizedProfile
    var placement: CirclePlacement
    let connectionPath: ConnectionPath
    var signals: ProfileSignals?
    var hiddenSignals: HiddenSignals?
}

struct MVPJourneyStep: Codable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}

struct SynthesizedProfile: Codable {
    let profileId: String
    let displayName: String
    let basicInfo: BasicInfo?
    let values: [String]
    let communicationStyle: String
    let emotionalRhythm: String
    let relationshipIntent: String
    let interests: [Interest]
    let privacy: ProfilePrivacy
    let reflection: ProfileReflection
}

struct ProfilePrivacy: Codable {
    let aiReflectionVisibleToUser: Bool
    let matchExplanationVisibleToMatches: Bool
}

struct ProfileReflection: Codable {
    let summary: String
    let strengths: [String]
    let nextQuestion: String
}

enum PlacementState: String, Codable, Equatable {
    case proposed
    case accepted
    case swapped
    case deferred
}

struct CirclePlacement: Codable {
    let rule: String
    let confidenceLabel: String
    let fitReasons: [String]
    let sourceReflectionSignals: [String]
    var primaryCircle: PlacementCircle
    var secondaryCircles: [PlacementCircle]
    var userState: PlacementState
    let actions: PlacementActionGroup
    var isNewCircle: Bool = false
}

struct PlacementCircle: Codable, Identifiable {
    let id: String
    let name: String
    let emotionalPace: String
    let interactionIntent: String
    let socialFormat: String
    let riskLevel: String
    let privacyLevel: String
    let shortPromise: String
    let roomEnergy: String
    let easiestFirstAction: String
    let fitLabel: String
    let placementReason: String
    let membersOnline: Int
    let themes: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case emotionalPace
        case interactionIntent
        case socialFormat
        case riskLevel
        case privacyLevel
        case shortPromise
        case roomEnergy
        case easiestFirstAction
        case fitLabel
        case placementReason
        case membersOnline
        case membersCount
        case themes
    }

    init(
        id: String,
        name: String,
        emotionalPace: String,
        interactionIntent: String,
        socialFormat: String,
        riskLevel: String,
        privacyLevel: String,
        shortPromise: String,
        roomEnergy: String,
        easiestFirstAction: String,
        fitLabel: String,
        placementReason: String,
        membersOnline: Int,
        themes: [String]
    ) {
        self.id = id
        self.name = name
        self.emotionalPace = emotionalPace
        self.interactionIntent = interactionIntent
        self.socialFormat = socialFormat
        self.riskLevel = riskLevel
        self.privacyLevel = privacyLevel
        self.shortPromise = shortPromise
        self.roomEnergy = roomEnergy
        self.easiestFirstAction = easiestFirstAction
        self.fitLabel = fitLabel
        self.placementReason = placementReason
        self.membersOnline = membersOnline
        self.themes = themes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let description = try container.decodeIfPresent(String.self, forKey: .description)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emotionalPace = try container.decodeIfPresent(String.self, forKey: .emotionalPace) ?? "Steady"
        interactionIntent = try container.decodeIfPresent(String.self, forKey: .interactionIntent) ?? "Circle placement"
        socialFormat = try container.decodeIfPresent(String.self, forKey: .socialFormat) ?? "Small circle"
        riskLevel = try container.decodeIfPresent(String.self, forKey: .riskLevel) ?? "Low"
        privacyLevel = try container.decodeIfPresent(String.self, forKey: .privacyLevel) ?? "Private"
        shortPromise = try container.decodeIfPresent(String.self, forKey: .shortPromise) ?? description ?? name
        roomEnergy = try container.decodeIfPresent(String.self, forKey: .roomEnergy) ?? "Warm and thoughtful."
        easiestFirstAction = try container.decodeIfPresent(String.self, forKey: .easiestFirstAction) ?? "Review placement."
        fitLabel = try container.decodeIfPresent(String.self, forKey: .fitLabel) ?? "Fit"
        placementReason = try container.decodeIfPresent(String.self, forKey: .placementReason) ?? description ?? "Matched from your profile signals."
        membersOnline = try container.decodeIfPresent(Int.self, forKey: .membersOnline)
            ?? container.decodeIfPresent(Int.self, forKey: .membersCount)
            ?? 0
        themes = try container.decodeIfPresent([String].self, forKey: .themes) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(emotionalPace, forKey: .emotionalPace)
        try container.encode(interactionIntent, forKey: .interactionIntent)
        try container.encode(socialFormat, forKey: .socialFormat)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encode(privacyLevel, forKey: .privacyLevel)
        try container.encode(shortPromise, forKey: .shortPromise)
        try container.encode(roomEnergy, forKey: .roomEnergy)
        try container.encode(easiestFirstAction, forKey: .easiestFirstAction)
        try container.encode(fitLabel, forKey: .fitLabel)
        try container.encode(placementReason, forKey: .placementReason)
        try container.encode(membersOnline, forKey: .membersOnline)
        try container.encode(themes, forKey: .themes)
    }
}

struct ConnectionPath: Codable, Identifiable {
    let matchId: String
    let displayName: String
    let compatibility: Int
    let explanation: String
    let nextStep: String
    let consentState: String

    var id: String { matchId }
}

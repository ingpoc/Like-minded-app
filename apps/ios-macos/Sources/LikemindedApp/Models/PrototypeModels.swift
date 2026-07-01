import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case meet = "Meet"
    case circles = "Circles"
    case communities = "Communities"
    case profile = "Profile"
    case soulmate = "Soulmate"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .meet:
            return "house.fill"
        case .circles:
            return "door.left.hand.open"
        case .communities:
            return "person.2.badge.gearshape"
        case .profile:
            return "person.crop.circle"
        case .soulmate:
            return "heart"
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

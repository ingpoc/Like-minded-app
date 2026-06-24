import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case place = "Place"
    case reflect = "Talk"
    case connect = "Connect"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .place:
            return "location.circle"
        case .reflect:
            return "waveform.circle"
        case .connect:
            return "person.2.wave.2"
        }
    }
}

struct ReflectionPrompt: Identifiable {
    let id = UUID()
    let prompt: String
    let note: String
}

struct CommunityRecommendation: Identifiable {
    let id: String
    let name: String
    let summary: String
    let fitLabel: String
    let membersOnline: Int
    let themes: [String]
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
    let values: [String]
    let communicationStyle: String
    let emotionalRhythm: String
    let relationshipIntent: String
    let interests: [String]
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

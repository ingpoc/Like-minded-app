import Foundation

enum MacTab: String, CaseIterable, Identifiable {
    case meet = "Meet"
    case circles = "Circles"
    case communities = "Communities"
    case profile = "Profile"
    case soulmate = "Soulmate"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .meet: "house"
        case .circles: "person.2"
        case .communities: "rectangle.3.group"
        case .profile: "person"
        case .soulmate: "heart"
        }
    }

    var primaryScreen: MacPrototypeScreen {
        switch self {
        case .meet: .meetOverview
        case .circles: .circlesRoom
        case .communities: .communitiesBrowse
        case .profile: .myProfile
        case .soulmate: .soulmateOverview
        }
    }
}

enum MacPrototypeScreen: String, CaseIterable, Identifiable {
    case welcome
    case meetOverview
    case circlesRoom
    case profileEdit
    case chat
    case communitiesBrowse
    case communityDetail
    case meetRecap
    case myProfile
    case soulmateOverview
    case soulmateDiscover
    case soulmateDetail
    case communityMembers
    case createEvent
    case messages
    case notifications
    case profileOnboarding
    case profileSignals
    case circleDetail
    case settingsSoulmate

    var id: String { rawValue }

    var number: Int {
        MacPrototypeScreen.allCases.firstIndex(of: self)! + 1
    }

    var tab: MacTab {
        switch self {
        case .welcome, .meetOverview, .meetRecap, .notifications: .meet
        case .circlesRoom, .circleDetail: .circles
        case .communitiesBrowse, .communityDetail, .communityMembers, .createEvent: .communities
        case .profileEdit, .myProfile, .profileOnboarding, .profileSignals: .profile
        case .chat, .soulmateOverview, .soulmateDiscover, .soulmateDetail, .messages, .settingsSoulmate: .soulmate
        }
    }

    var title: String {
        switch self {
        case .welcome: "When you meet, matters."
        case .meetOverview: "When you meet."
        case .circlesRoom: "Your room."
        case .profileEdit: "Who you are."
        case .chat: "Chats"
        case .communitiesBrowse: "Explore communities that inspire you."
        case .communityDetail, .circleDetail: "Jazz & Music Community"
        case .meetRecap: "Great meeting!"
        case .myProfile: "Priya"
        case .soulmateOverview: "Meaningful connections, made with intention."
        case .soulmateDiscover: "Discover"
        case .soulmateDetail: "Meera, 27"
        case .communityMembers: "Jazz & Music Community"
        case .createEvent: "Create a new event"
        case .messages: "Messages"
        case .notifications: "Notifications"
        case .profileOnboarding: "Let us get to know you better"
        case .profileSignals: "Your personality signals"
        case .settingsSoulmate: "Settings"
        }
    }

    var eyebrow: String {
        switch tab {
        case .meet: "Meet"
        case .circles: "Circles"
        case .communities: "Communities"
        case .profile: "Profile"
        case .soulmate: "Soulmate"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: "AI helps you meet the right people in the right rooms."
        case .meetOverview: "Good evening, Priya. Your next room is ready."
        case .circlesRoom: "A space of people who get you."
        case .profileEdit: "Private signals, editable interests, and your living profile."
        case .chat: "Stay close to the people you met."
        case .communitiesBrowse: "Find rooms around music, design, slow living, writing, and thoughtful ideas."
        case .communityDetail: "Listen, share, explore."
        case .meetRecap: "You attended Jazz & Music Community on Sat, Jul 5."
        case .myProfile: "Bangalore, India - voice profile active."
        case .soulmateOverview: "Our AI helps discover people who resonate with your vibe."
        case .soulmateDiscover: "Curated for you."
        case .soulmateDetail: "Writer - Bangalore - 5 km away."
        case .communityMembers: "18 members - private."
        case .createEvent: "Bring people together around what you love."
        case .messages: "Your conversations and community threads."
        case .notifications: "Activity from circles, communities, and matches."
        case .profileOnboarding: "A few thoughtful details help us understand your vibe."
        case .profileSignals: "From your voice, activity, and choices."
        case .circleDetail: "Analytical - Calm - Curious."
        case .settingsSoulmate: "Manage your discovery preferences and comfort."
        }
    }
}

struct MacBackendConfig {
    static var baseURLString: String {
        if let env = ProcessInfo.processInfo.environment["LIKEMINDED_API_BASE_URL"], !env.isEmpty {
            return env
        }
        if let configured = Bundle.main.object(forInfoDictionaryKey: "LIKEMINDED_API_BASE_URL") as? String, !configured.isEmpty {
            return configured
        }
        #if DEBUG
        return "http://127.0.0.1:8787"
        #else
        return "https://likeminded-api.onrender.com"
        #endif
    }
}

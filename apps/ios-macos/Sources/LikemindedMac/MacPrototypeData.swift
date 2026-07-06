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
        case .soulmate: .soulmateDiscover
        }
    }

    static func visible(soulmateEnabled: Bool) -> [MacTab] {
        if soulmateEnabled {
            return allCases
        } else {
            return allCases.filter { $0 != .soulmate }
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
    case meetVideoCall
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
    case createCommunity

    var id: String { rawValue }

    static var initial: MacPrototypeScreen {
        let env = ProcessInfo.processInfo.environment["LIKEMINDED_MAC_SCREEN"]
        let args = ProcessInfo.processInfo.arguments
        let arg = args.firstIndex(of: "--mac-screen").flatMap { index in
            args.indices.contains(index + 1) ? args[index + 1] : nil
        }
        return [arg, env]
            .compactMap { $0 }
            .compactMap(MacPrototypeScreen.init(rawValue:))
            .first ?? .welcome
    }

    var number: Int {
        MacPrototypeScreen.allCases.firstIndex(of: self)! + 1
    }

    var tab: MacTab {
        switch self {
        case .welcome, .meetOverview, .meetRecap, .meetVideoCall, .notifications: .meet
        case .circlesRoom, .circleDetail: .circles
        case .communitiesBrowse, .communityDetail, .communityMembers, .createEvent, .createCommunity: .communities
        case .profileEdit, .myProfile, .profileOnboarding, .profileSignals, .settingsSoulmate: .profile
        case .chat, .soulmateOverview, .soulmateDiscover, .soulmateDetail, .messages: .soulmate
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
        case .meetVideoCall: "Meet"
        case .myProfile: "Your profile"
        case .soulmateOverview: "Meaningful connections, made with intention."
        case .soulmateDiscover: "Discover"
        case .soulmateDetail: "Meera, 27"
        case .communityMembers: "Jazz & Music Community"
        case .createEvent: "Create event"
        case .createCommunity: "Create a community"
        case .messages: "Messages"
        case .notifications: "Notifications"
        case .profileOnboarding: "Let's get to know you better"
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
        case .meetVideoCall: "Today - 7:00 PM - 8:00 PM"
        case .myProfile: "Profile and placement from your voice interview."
        case .soulmateOverview: "Our AI helps discover people who resonate with your vibe."
        case .soulmateDiscover: "Curated for you."
        case .soulmateDetail: "Writer - Bangalore - 5 km away."
        case .communityMembers: "18 members - private."
        case .createEvent: "Bring people together around what you love."
        case .createCommunity: "Start a focused room for people who share your interests."
        case .messages: "Your conversations and community threads."
        case .notifications: "Activity from circles, communities, and matches."
        case .profileOnboarding: "A few thoughtful details help us understand your vibe and find your people."
        case .profileSignals: "From your voice, activity, and choices."
        case .circleDetail: "Analytical - Calm - Curious."
        case .settingsSoulmate: "Manage your experience and preferences."
        }
    }

    /// Child screens reachable from a `--mac-screen` entry without leaving validation scope.
    func allowsValidationDrillDown(to destination: MacPrototypeScreen) -> Bool {
        switch self {
        case .circlesRoom:
            return destination == .circleDetail
        case .communitiesBrowse:
            return destination == .communityDetail || destination == .createCommunity
        case .communityDetail:
            return destination == .communityMembers || destination == .createEvent
        case .meetOverview:
            return destination == .meetRecap || destination == .meetVideoCall
        case .soulmateDiscover:
            return destination == .soulmateDetail || destination == .chat || destination == .messages
        case .myProfile:
            return destination == .profileEdit || destination == .profileSignals
                || destination == .profileOnboarding || destination == .settingsSoulmate
        default:
            return false
        }
    }
}

// Mockup plate 05 chat roster + jazz thread for macOS validation deep-links.
enum MacChatFixtures {
    private static let now = Date()
    private static func iso(minutesAgo: Int) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(TimeInterval(-minutesAgo * 60)))
    }

    static var isActive: Bool {
        #if DEBUG
        MacPrototypeScreen.initial == .chat
            && ProcessInfo.processInfo.arguments.contains("--mac-screen")
        #else
        false
        #endif
    }

    static let matches: [SoulmateMatch] = [
        SoulmateMatch(matchId: "fixture-arjun", userId: "fixture-arjun", name: "Gurusharan Gupta", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 2880), createdAt: iso(minutesAgo: 2880)),
        SoulmateMatch(matchId: "fixture-meera", userId: "fixture-meera", name: "Meera Iyer", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 3600), createdAt: iso(minutesAgo: 3600)),
        SoulmateMatch(matchId: "fixture-rohan", userId: "fixture-rohan", name: "Rohan Mehta", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 4320), createdAt: iso(minutesAgo: 4320)),
        SoulmateMatch(matchId: "fixture-ananya", userId: "fixture-ananya", name: "Ananya Rao", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 7200), createdAt: iso(minutesAgo: 7200)),
        SoulmateMatch(matchId: "fixture-vikram", userId: "fixture-vikram", name: "Vivek Kumar", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 10080), createdAt: iso(minutesAgo: 10080)),
    ]

    static let previews: [String: ChatMessage] = [
        "fixture-arjun": ChatMessage(id: "fixture-preview-arjun", matchId: "fixture-arjun", senderId: "fixture-arjun", text: "That Coltrane track was insane live! 🔥", createdAt: iso(minutesAgo: 2)),
        "fixture-meera": ChatMessage(id: "fixture-preview-meera", matchId: "fixture-meera", senderId: "fixture-meera", text: "Yes! That sounds perfect.", createdAt: iso(minutesAgo: 60)),
        "fixture-rohan": ChatMessage(id: "fixture-preview-rohan", matchId: "fixture-rohan", senderId: "fixture-rohan", text: "Looking forward to our next circle check-in.", createdAt: iso(minutesAgo: 1440)),
        "fixture-ananya": ChatMessage(id: "fixture-preview-ananya", matchId: "fixture-ananya", senderId: "fixture-ananya", text: "The essay you recommended was brilliant.", createdAt: iso(minutesAgo: 4320)),
        "fixture-vikram": ChatMessage(id: "fixture-preview-vikram", matchId: "fixture-vikram", senderId: "fixture-vikram", text: "Let's catch up soon!", createdAt: iso(minutesAgo: 10080)),
    ]

    static func messages(for matchId: String, currentUserId: String?) -> [ChatMessage] {
        guard matchId == "fixture-arjun" else { return [] }
        let mine = currentUserId ?? "validation-self"
        return [
            ChatMessage(id: "fixture-msg-1", matchId: matchId, senderId: "fixture-arjun", text: "That Coltrane track you mentioned in the meetup was 🔥", createdAt: iso(minutesAgo: 39)),
            ChatMessage(id: "fixture-msg-2", matchId: matchId, senderId: mine, text: "Glad you noticed! What's your go-to these days?", createdAt: iso(minutesAgo: 37)),
            ChatMessage(id: "fixture-msg-3", matchId: matchId, senderId: "fixture-arjun", text: "Lately, it's been Ballads. Soothing on slow Sundays.", createdAt: iso(minutesAgo: 36)),
            ChatMessage(id: "fixture-msg-4", matchId: matchId, senderId: mine, text: "Same here. Anything beyond jazz you've been enjoying?", createdAt: iso(minutesAgo: 35)),
            ChatMessage(id: "fixture-msg-5", matchId: matchId, senderId: "fixture-arjun", text: "I've been reading a lot of essays. Really into long-form thinking.", createdAt: iso(minutesAgo: 33)),
            ChatMessage(id: "fixture-msg-6", matchId: matchId, senderId: mine, text: "Nice! Any recommendations?", createdAt: iso(minutesAgo: 32)),
        ]
    }
}

// Mockup plate 15 messages roster + Ananya jazz thread for macOS validation deep-links.
enum MacMessagesFixtures {
    private static let now = Date()
    private static func iso(minutesAgo: Int) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(TimeInterval(-minutesAgo * 60)))
    }

    static var isActive: Bool {
        #if DEBUG
        MacPrototypeScreen.initial == .messages
            && ProcessInfo.processInfo.arguments.contains("--mac-screen")
        #else
        false
        #endif
    }

    static let matches: [SoulmateMatch] = [
        SoulmateMatch(matchId: "fixture-ananya", userId: "fixture-ananya", name: "Ananya Rao", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 5), createdAt: iso(minutesAgo: 5)),
        SoulmateMatch(matchId: "fixture-jazz-group", userId: "fixture-jazz-group", name: "Jazz & Music Community", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 21), createdAt: iso(minutesAgo: 21)),
        SoulmateMatch(matchId: "fixture-meera", userId: "fixture-meera", name: "Meera Iyer", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 1440), createdAt: iso(minutesAgo: 1440)),
        SoulmateMatch(matchId: "fixture-rohan", userId: "fixture-rohan", name: "Rohan Mehta", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 1500), createdAt: iso(minutesAgo: 1500)),
        SoulmateMatch(matchId: "fixture-writers", userId: "fixture-writers", name: "Writers' Corner", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 4320), createdAt: iso(minutesAgo: 4320)),
        SoulmateMatch(matchId: "fixture-arjun", userId: "fixture-arjun", name: "Gurusharan Gupta", meetingId: "fixture-meet", meetingDate: iso(minutesAgo: 10080), createdAt: iso(minutesAgo: 10080)),
    ]

    static let previews: [String: ChatMessage] = [
        "fixture-ananya": ChatMessage(id: "fixture-preview-ananya-msg", matchId: "fixture-ananya", senderId: "fixture-ananya", text: "Typing...", createdAt: iso(minutesAgo: 1)),
        "fixture-jazz-group": ChatMessage(id: "fixture-preview-jazz", matchId: "fixture-jazz-group", senderId: "fixture-marco", text: "Marco: Don't forget about tomorrow!", createdAt: iso(minutesAgo: 21)),
        "fixture-meera": ChatMessage(id: "fixture-preview-meera-msg", matchId: "fixture-meera", senderId: "validation-self", text: "You: That book recommendation was perfect.", createdAt: iso(minutesAgo: 1440)),
        "fixture-rohan": ChatMessage(id: "fixture-preview-rohan-msg", matchId: "fixture-rohan", senderId: "validation-self", text: "You: Loved your playlist!", createdAt: iso(minutesAgo: 1500)),
        "fixture-writers": ChatMessage(id: "fixture-preview-writers", matchId: "fixture-writers", senderId: "fixture-priya", text: "Priya: Sharing the outline I mentioned.", createdAt: iso(minutesAgo: 4320)),
        "fixture-arjun": ChatMessage(id: "fixture-preview-arjun-msg", matchId: "fixture-arjun", senderId: "validation-self", text: "You: See you at the meetup!", createdAt: iso(minutesAgo: 10080)),
    ]

    static func messages(for matchId: String, currentUserId: String?) -> [ChatMessage] {
        guard matchId == "fixture-ananya" else { return [] }
        let mine = currentUserId ?? "validation-self"
        return [
            ChatMessage(id: "fixture-msg-ananya-1", matchId: matchId, senderId: "fixture-ananya", text: "Hey Priya! Loved your take on that jazz piece yesterday 🎵", createdAt: iso(minutesAgo: 5)),
            ChatMessage(id: "fixture-msg-ananya-2", matchId: matchId, senderId: mine, text: "Thank you! Which part resonated with you the most?", createdAt: iso(minutesAgo: 3)),
            ChatMessage(id: "fixture-msg-ananya-3", matchId: matchId, senderId: "fixture-ananya", text: "The improvisation section. So raw and beautiful.", createdAt: iso(minutesAgo: 2)),
            ChatMessage(id: "fixture-msg-ananya-4", matchId: matchId, senderId: mine, text: "Totally! Want to check out a live session this Saturday?", createdAt: iso(minutesAgo: 1)),
            ChatMessage(id: "fixture-msg-ananya-5", matchId: matchId, senderId: "fixture-ananya", text: "Yes! Count me in.", createdAt: iso(minutesAgo: 0)),
        ]
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

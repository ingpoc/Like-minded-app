import Foundation
import SwiftUI

@MainActor
final class MacAppState: ObservableObject {
    @Published var authSession = MacAuthSessionStore.load()
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var profile: UserProfile?
    @Published var placement: ProfileCircleMatchResult?
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var communities: [Community] = []
    @Published var joinedCommunities: [Community] = []
    @Published var isLoadingCommunities = false
    @Published var communityError: String?
    @Published var communityMembers: [CommunityMember] = []
    @Published var circles: [PlacementCircle] = []
    @Published var joinedCircles: [PlacementCircle] = []
    @Published var circleDetail: PlacementCircle?
    @Published var isLoadingCircles = false
    @Published var circleError: String?
    @Published var meetingRsvps = MeetingRsvps(circle: false, community: false)
    @Published var upcomingMeetings: [Meeting] = []
    @Published var pastMeetings: [Meeting] = []
    @Published var isLoadingMeetings = false
    @Published var meetingError: String?
    @Published var soulmateEnabled = false
    @Published var soulmatePendingSelections: [SoulmatePendingSelection] = []
    @Published var soulmateMatches: [SoulmateMatch] = []
    @Published var soulmateError: String?
    @Published var isLoadingSoulmate = false
    @Published var chatMessages: [ChatMessage] = []
    @Published var messageError: String?
    @Published var notifications: [MacNotificationItem] = []
    @Published var activityItems: [MacNotificationItem] = []
    @Published var notificationError: String?

    private var client: LikemindedAPIClient {
        LikemindedAPIClient(authToken: authSession?.token)
    }

    var isSignedIn: Bool {
        authSession != nil
    }

    func signInForLocalValidationIfNeeded() async {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        guard environment["LIKEMINDED_DEV_AUTH_BYPASS"] == "1" || arguments.contains("--likeminded-dev-auth-bypass") else { return }
        // Default to validation-gurusharan (primary seeded user with prod-like data).
        let identityToken = Self.argumentValue(after: "--likeminded-dev-auth-token", in: arguments) ?? environment["LIKEMINDED_DEV_AUTH_TOKEN"] ?? "validation-gurusharan"
        let fullName = Self.argumentValue(after: "--likeminded-dev-auth-name", in: arguments) ?? environment["LIKEMINDED_DEV_AUTH_NAME"] ?? "Gurusharan Gupta"
        isAuthenticating = true
        authError = nil
        do {
            let response = try await client.authenticateWithApple(
                identityToken: identityToken,
                authorizationCode: nil,
                fullName: fullName
            )
            await saveSessionAndLoadPlacement(response)
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
        #endif
    }

    func signInWithApple() async {
        isAuthenticating = true
        authError = nil
        do {
            let response = try await client.authenticateWithApple(
                identityToken: "macos-apple-sign-in",
                authorizationCode: nil,
                fullName: "Mac Tester"
            )
            await saveSessionAndLoadPlacement(response)
        } catch {
            authError = "Sign in failed. Check Apple auth or local validation bypass."
        }
        isAuthenticating = false
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private func saveSessionAndLoadPlacement(_ response: AppleAuthResponse) async {
        let session = MacAuthSession(
            userId: response.user.id,
            token: response.sessionToken,
            email: response.user.email,
            fullName: response.user.fullName
        )
        MacAuthSessionStore.save(session)
        authSession = session
        await loadCurrentProfile()
        await loadCurrentPlacement()
    }

    func signOut() {
        MacAuthSessionStore.clear()
        authSession = nil
        profile = nil
        placement = nil
        authError = nil
        loadError = nil
        communities = []
        joinedCommunities = []
        communityMembers = []
        circles = []
        joinedCircles = []
        circleDetail = nil
        upcomingMeetings = []
        pastMeetings = []
        soulmateMatches = []
        chatMessages = []
        notifications = []
        activityItems = []
    }

    func deleteAccount() async -> Bool {
        do {
            try await client.deleteAccount()
            signOut()
            return true
        } catch {
            authError = "Account could not be deleted. Please try again or contact support."
            return false
        }
    }

    func loadCurrentProfile() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            profile = try await client.fetchMyProfile()
            loadError = nil
        } catch {
            profile = nil
            loadError = "No profile yet. Complete the voice profile to unlock this screen."
        }
        isLoading = false
    }

    func loadCurrentPlacement() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            placement = try await client.fetchMyPlacement()
            loadError = nil
        } catch {
            placement = nil
            if profile == nil {
                loadError = "No profile placement yet. Complete the voice profile to unlock this screen."
            }
        }
        isLoading = false
    }

    func acceptPlacement() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            placement = try await client.updatePlacement(action: "accept")
            loadError = nil
        } catch {
            loadError = "Placement update failed. Please retry."
        }
        isLoading = false
    }

    func deferPlacement() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            placement = try await client.updatePlacement(action: "defer")
            loadError = nil
        } catch {
            loadError = "Placement update failed. Please retry."
        }
        isLoading = false
    }

    func swapPrimaryCircle() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            placement = try await client.updatePlacement(action: "swap")
            loadError = nil
        } catch {
            loadError = "Placement update failed. Please retry."
        }
        isLoading = false
    }

    func reportCircleConcern(_ message: String) async {
        guard isSignedIn else { return }
        do {
            try await client.registerCircleConcern()
        } catch {
            loadError = "Concern could not be registered."
        }
    }

    func fetchCircles() async {
        isLoadingCircles = true
        defer { isLoadingCircles = false }
        do {
            async let catalog = client.fetchCircles()
            async let joined = isSignedIn ? client.fetchMyCircles() : []
            circles = try await catalog
            joinedCircles = try await joined
            if let firstCircle = joinedCircles.first {
                circleDetail = try await client.fetchCircleDetail(id: firstCircle.id)
            }
            circleError = nil
        } catch {
            circleError = "Circles could not be loaded."
        }
    }

    func fetchCommunities() async {
        isLoadingCommunities = true
        defer { isLoadingCommunities = false }
        do {
            async let catalog = client.fetchCommunities()
            async let joined = isSignedIn ? client.fetchMyCommunities() : []
            communities = try await catalog
            joinedCommunities = try await joined
            communityError = nil
        } catch {
            communityError = "Communities could not be loaded."
        }
    }

    func joinCommunity(id: String) async {
        do {
            try await client.joinCommunity(id: id)
            await fetchCommunities()
        } catch {
            communityError = "Community could not be joined."
        }
    }

    func leaveCommunity(id: String) async {
        do {
            try await client.leaveCommunity(id: id)
            await fetchCommunities()
        } catch {
            communityError = "Community could not be left."
        }
    }

    func createCommunity(name: String, summary: String, themes: [String]) async -> Community? {
        do {
            let community = try await client.createCommunity(name: name, summary: summary, themes: themes)
            await fetchCommunities()
            communityError = nil
            return community
        } catch {
            communityError = "Community could not be created."
            return nil
        }
    }

    func fetchCommunityMembers(id: String) async {
        guard isSignedIn else { return }
        do {
            communityMembers = try await client.fetchCommunityMembers(id: id)
        } catch {
            communityMembers = []
        }
    }

    func fetchMeetings() async {
        guard isSignedIn else { return }
        isLoadingMeetings = true
        defer { isLoadingMeetings = false }
        do {
            let response = try await client.fetchMeetings()
            meetingRsvps = response.rsvps
            upcomingMeetings = response.upcoming
            pastMeetings = response.past
            meetingError = nil
        } catch {
            meetingError = "Meetups could not be loaded."
        }
    }

    func updateMeetingRSVP(kind: String, available: Bool) async {
        do {
            try await client.updateMeetingRSVP(kind: kind, available: available)
            if kind == "circle" {
                meetingRsvps = MeetingRsvps(circle: available, community: meetingRsvps.community)
            } else {
                meetingRsvps = MeetingRsvps(circle: meetingRsvps.circle, community: available)
            }
            meetingError = nil
        } catch {
            meetingError = "RSVP could not be saved."
        }
    }

    func createMeeting(kind: String, targetId: String, title: String, scheduledAt: String, location: String, details: String) async -> Meeting? {
        do {
            let meeting = try await client.createMeeting(kind: kind, targetId: targetId, title: title, scheduledAt: scheduledAt, location: location, details: details)
            await fetchMeetings()
            meetingError = nil
            return meeting
        } catch {
            meetingError = "Event could not be created."
            return nil
        }
    }

    func saveMeetingRecapNote(meetingId: String, note: String) async {
        do {
            try await client.saveMeetingRecapNote(meetingId: meetingId, note: note)
            await fetchMeetings()
        } catch {
            meetingError = "Recap note could not be saved."
        }
    }

    func fetchSoulmateStatus() async {
        guard isSignedIn else { return }
        isLoadingSoulmate = true
        defer { isLoadingSoulmate = false }
        do {
            let status = try await client.fetchSoulmateStatus()
            soulmateEnabled = status.enabled
            soulmatePendingSelections = status.pendingSelections
            soulmateMatches = try await client.fetchSoulmateMatches()
            if let firstMatch = soulmateMatches.first {
                chatMessages = try await client.fetchMessages(matchId: firstMatch.matchId)
            }
            soulmateError = nil
        } catch {
            soulmateError = "Soulmate could not be loaded."
        }
    }

    func setSoulmateEnabled(_ enabled: Bool) async {
        do {
            try await client.setSoulmateEnabled(enabled)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                soulmateEnabled = enabled
            }
            await fetchSoulmateStatus()
        } catch {
            soulmateError = "Soulmate preference could not be saved."
        }
    }

    func fetchSoulmateMatchDetail(id: String) async throws -> SoulmateMatchDetail {
        try await client.fetchSoulmateMatchDetail(id: id)
    }

    func fetchMessages(matchId: String) async throws -> [ChatMessage] {
        try await client.fetchMessages(matchId: matchId)
    }

    func loadMessages(matchId: String) async {
        guard !matchId.isEmpty else { return }
        do {
            chatMessages = try await client.fetchMessages(matchId: matchId)
            messageError = nil
        } catch {
            messageError = "Messages could not be loaded."
        }
    }

    func sendMessage(matchId: String, text: String) async throws -> ChatMessage {
        try await client.sendMessage(matchId: matchId, text: text)
    }

    func fetchFirstMatchMessages() async {
        guard isSignedIn, let firstMatch = soulmateMatches.first else { return }
        await loadMessages(matchId: firstMatch.matchId)
    }

    func fetchNotifications() async {
        guard isSignedIn else { return }
        do {
            let response = try await client.fetchNotifications()
            notifications = response.notifications
            activityItems = response.activity
            notificationError = nil
        } catch {
            notificationError = "Notifications could not be loaded."
        }
    }
}

struct MacAuthSession: Codable, Equatable {
    let userId: String
    let token: String
    let email: String?
    let fullName: String?
}

enum MacAuthSessionStore {
    private static let service = "com.likeminded.mac.auth"
    private static let account = "session"

    static func load() -> MacAuthSession? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--likeminded-reset-auth-session") {
            clear()
            return nil
        }
        #endif
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(MacAuthSession.self, from: data)
    }

    static func save(_ session: MacAuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

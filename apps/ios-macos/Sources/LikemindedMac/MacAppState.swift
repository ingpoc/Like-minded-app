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
    @Published var soulmatePreferences = SoulmatePreferences.defaults
    @Published var soulmatePendingSelections: [SoulmatePendingSelection] = []
    @Published var soulmateMatches: [SoulmateMatch] = []
    @Published var soulmateError: String?
    @Published var isLoadingSoulmate = false
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatPreviews: [String: ChatMessage] = [:]
    @Published var messageError: String?
    @Published var notifications: [MacNotificationItem] = []
    @Published var activityItems: [MacNotificationItem] = []
    @Published var notificationError: String?
    @Published var readNotificationIds: Set<String> = []
    @Published var concernFlag = false
    @Published var placementConcern = ""

    static let defaultPlacementConcernCopy = "This circle doesn't match how I connect with people."

    var displayPlacementConcern: String {
        let trimmed = placementConcern.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultPlacementConcernCopy : trimmed
    }

    /// Saved profile name from API — not dev-auth seed or Apple sign-in display name.
    var profileDisplayName: String? {
        guard let raw = profile?.basicInfo?.name.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    var profileFirstName: String? {
        guard let name = profileDisplayName else { return nil }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    @Published var requestedSettingsPane: String?

    private var client: LikemindedAPIClient {
        LikemindedAPIClient(authToken: authSession?.token)
    }

    var isSignedIn: Bool {
        authSession != nil
    }

    #if DEBUG
    static var devProfileEmptyPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("--likeminded-dev-profile-empty")
    }
    #else
    static var devProfileEmptyPreview: Bool { false }
    #endif

    func applyDevProfileEmptyPreviewIfNeeded() {
        guard Self.devProfileEmptyPreview else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            placement = nil
            concernFlag = false
            placementConcern = ""
        }
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
            await saveSessionAndLoadPlacement(response, authProvider: "apple")
            applyDevProfileConcernLaunchArg(from: arguments)
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
        #endif
    }

    func signInWithApple(using controller: AppleSignInController) async {
        isAuthenticating = true
        authError = nil
        let result = await controller.signIn()
        switch result {
        case .success(let payload):
            do {
                let response = try await client.authenticateWithApple(
                    identityToken: payload.identityToken,
                    authorizationCode: payload.authorizationCode,
                    fullName: payload.fullName,
                    nonce: payload.rawNonce
                )
                await saveSessionAndLoadPlacement(response, authProvider: "apple", appleUserIdentifier: payload.userIdentifier)
            } catch {
                authError = AppleSignInSupport.userFacingMessage(for: error)
            }
        case .failure(let error):
            authError = AppleSignInSupport.userFacingMessage(for: error)
        }
        isAuthenticating = false
    }

    func signInWithGoogle() async {
        isAuthenticating = true
        authError = nil
        do {
            let idToken = try await GoogleSignInSupport.signIn()
            let response = try await client.authenticateWithGoogle(idToken: idToken)
            await saveSessionAndLoadPlacement(response, authProvider: "google")
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isAuthenticating = false
    }

    func signInWithWallet(_ wallet: WalletProvider, controller: WalletSignInController) async {
        isAuthenticating = true
        authError = nil
        do {
            let callback = try await controller.signIn(baseURL: LikemindedAPIClient.defaultBaseURL(), wallet: wallet)
            let response = AppleAuthResponse(
                user: APIUser(id: callback.userId, email: nil, fullName: callback.fullName),
                sessionToken: callback.sessionToken,
                expiresIn: 60 * 60 * 24 * 30
            )
            await saveSessionAndLoadPlacement(response, authProvider: "wallet")
        } catch {
            authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isAuthenticating = false
    }

    func completeWalletSignIn(_ response: AppleAuthResponse) async {
        await saveSessionAndLoadPlacement(response, authProvider: "wallet")
    }

    func validateStoredAppleCredentialIfNeeded() async {
        guard authSession?.authProvider == "apple" else { return }
        guard let appleUserIdentifier = authSession?.appleUserIdentifier else { return }
        let isAuthorized = await AppleSignInSupport.validateCredentialState(for: appleUserIdentifier)
        guard !isAuthorized else { return }
        signOut()
        authError = "Your Apple sign-in is no longer valid. Please sign in again."
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private func saveSessionAndLoadPlacement(
        _ response: AppleAuthResponse,
        authProvider: String,
        appleUserIdentifier: String? = nil
    ) async {
        let session = MacAuthSession(
            userId: response.user.id,
            token: response.sessionToken,
            email: response.user.email,
            fullName: response.user.fullName,
            appleUserIdentifier: appleUserIdentifier,
            authProvider: authProvider
        )
        MacAuthSessionStore.save(session)
        authSession = session
        await loadCurrentProfile()
        await loadCurrentPlacement()
        applyDevProfileEmptyPreviewIfNeeded()
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
        concernFlag = false
        placementConcern = ""
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
            applyConcernState(concernFlag: profile?.concernFlag, placementConcern: profile?.placementConcern)
            loadError = nil
        } catch {
            profile = nil
            loadError = "No profile yet. Complete the voice profile to unlock this screen."
        }
        applyValidationLaunchOverrides()
        applyDevProfileEmptyPreviewIfNeeded()
        isLoading = false
    }

    @discardableResult
    func updateProfileBasics(
        name: String,
        city: String,
        gender: Gender?,
        dateOfBirth: String? = nil,
        pincode: String? = nil,
        interests: [String] = []
    ) async -> Bool {
        guard isSignedIn else { return false }
        let existing = profile?.basicInfo
        let update = BasicInfoUpdate(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: (gender ?? existing?.gender)?.rawValue,
            dateOfBirth: dateOfBirth ?? existing?.dateOfBirth,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            pincode: pincode ?? existing?.pincode
        )
        let interestModels = interests.map { Interest(area: "general", label: $0, depth: .active) }
        do {
            profile = try await client.updateProfile(basicInfo: update, interests: interestModels.isEmpty ? nil : interestModels)
            loadError = nil
            return true
        } catch {
            loadError = "Profile could not be saved."
            return false
        }
    }

    /// Refresh profile from API after local edits (e.g. tab switch) so UI shows saved basics.
    func refreshProfileDisplay() async {
        await loadCurrentProfile()
    }

    func loadCurrentPlacement() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            placement = try await client.fetchMyPlacement()
            applyConcernState(concernFlag: placement?.concernFlag, placementConcern: placement?.placementConcern)
            loadError = nil
            applyDevProfileEmptyPreviewIfNeeded()
        } catch {
            placement = nil
            applyDevProfileEmptyPreviewIfNeeded()
            if profile == nil {
                loadError = "No profile placement yet. Complete the voice profile to unlock this screen."
            }
        }
        applyValidationLaunchOverrides()
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
        let note = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        placementConcern = note
        concernFlag = true
        do {
            try await client.registerCircleConcern(message: note)
            loadError = nil
        } catch {
            loadError = "Concern could not be registered."
        }
    }

    private func applyConcernState(concernFlag: Bool?, placementConcern: String?) {
        if concernFlag == true {
            self.concernFlag = true
        }
        if let placementConcern {
            let trimmed = placementConcern.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                self.placementConcern = trimmed
            }
        }
        if self.concernFlag && self.placementConcern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.placementConcern = Self.defaultPlacementConcernCopy
        }
    }

    private func applyDevProfileConcernLaunchArg(from arguments: [String]) {
        guard arguments.contains("--likeminded-dev-profile-concern") else { return }
        let message = Self.argumentValue(after: "--likeminded-dev-profile-concern", in: arguments)
            ?? Self.defaultPlacementConcernCopy
        placementConcern = message
        concernFlag = true
    }

    private func applyValidationLaunchOverrides() {
        #if DEBUG
        applyDevProfileConcernLaunchArg(from: ProcessInfo.processInfo.arguments)
        #endif
    }

    func fetchCircles() async {
        isLoadingCircles = true
        defer { isLoadingCircles = false }
        do {
            async let catalog = client.fetchCircles()
            async let joined = isSignedIn ? client.fetchMyCircles() : []
            circles = try await catalog
            joinedCircles = try await joined
            if let firstCircle = joinedCircles.first, circleDetail == nil {
                circleDetail = try await client.fetchCircleDetail(id: firstCircle.id)
            }
            circleError = nil
        } catch {
            circleError = "Circles could not be loaded."
        }
    }

    func loadCircleDetail(id: String) async {
        do {
            circleDetail = try await client.fetchCircleDetail(id: id)
            circleError = nil
        } catch {
            circleError = "Circle detail could not be loaded."
        }
    }

    func fetchCommunities() async {
        isLoadingCommunities = true
        defer { isLoadingCommunities = false }
        do {
            communities = try await client.fetchCommunities()
        } catch {
            communityError = "Communities could not be loaded."
            return
        }

        if isSignedIn {
            do {
                joinedCommunities = try await client.fetchMyCommunities()
            } catch {
                joinedCommunities = []
            }
        } else {
            joinedCommunities = []
        }
        communityError = nil
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

    func joinMeeting(id: String) async throws -> LiveKitJoinToken {
        try await client.joinMeeting(id: id)
    }

    func fetchSoulmateStatus() async {
        guard isSignedIn else { return }
        isLoadingSoulmate = true
        defer { isLoadingSoulmate = false }
        do {
            let status = try await client.fetchSoulmateStatus()
            soulmateEnabled = status.enabled
            soulmatePreferences = status.preferences ?? .defaults
            soulmatePendingSelections = status.pendingSelections
            soulmateMatches = try await client.fetchSoulmateMatches()
            var previews: [String: ChatMessage] = [:]
            for match in soulmateMatches {
                let messages = try await client.fetchMessages(matchId: match.matchId)
                if let last = messages.last {
                    previews[match.matchId] = last
                }
            }
            chatPreviews = previews
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

    func saveSoulmatePreferences(_ preferences: SoulmatePreferences) async -> Bool {
        do {
            soulmatePreferences = try await client.setSoulmatePreferences(preferences)
            soulmateError = nil
            return true
        } catch {
            soulmateError = "Discovery preferences could not be saved."
            return false
        }
    }

    func submitFeedback(rating: Int, message: String) async -> Bool {
        do {
            try await client.submitFeedback(
                profileId: profile?.profileId,
                placementId: placement?.placementId,
                rating: rating,
                message: message,
                appVersion: "LikemindedMac 0.1.0"
            )
            return true
        } catch {
            loadError = "Support note could not be sent."
            return false
        }
    }

    func refreshProfileFromReflection(_ answers: [String]) async -> Bool {
        guard isSignedIn else { return false }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await client.createProfileFromInterview(
                interviewTranscript: answers.joined(separator: "\n"),
                reflectionAnswers: answers
            )
            placement = result
            await loadCurrentProfile()
            loadError = nil
            return true
        } catch {
            loadError = "Voice profile refresh could not be saved."
            return false
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
            if let last = chatMessages.last {
                chatPreviews[matchId] = last
            }
            messageError = nil
        } catch {
            messageError = "Messages could not be loaded."
        }
    }

    func sendMessage(matchId: String, text: String) async throws -> ChatMessage {
        let message = try await client.sendMessage(matchId: matchId, text: text)
        chatPreviews[matchId] = message
        return message
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

    func markNotificationsRead() {
        readNotificationIds = Set(notifications.map(\.id))
    }
}

struct MacAuthSession: Codable, Equatable {
    let userId: String
    let token: String
    let email: String?
    let fullName: String?
    let appleUserIdentifier: String?
    let authProvider: String?
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

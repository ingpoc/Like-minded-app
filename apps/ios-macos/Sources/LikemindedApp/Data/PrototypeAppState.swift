import Foundation
import SwiftUI

@MainActor
final class PrototypeAppState: ObservableObject {
    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        if args.contains("--likeminded-start-past-meet-detail")
            || env["LIKEMINDED_VALIDATION_SCREEN"] == "past-meet-detail" {
            validationDirectCommunityMembers = false
        } else if args.contains("--likeminded-start-community-members")
            || UserDefaults.standard.string(forKey: "LIKEMINDED_VALIDATION_SCREEN") == "communityMembers" {
            validationDirectCommunityMembers = true
        }
        #endif
    }

    @Published var authSession = AuthSessionStore.load()
    @Published var isAuthenticating = false
    @Published var authError: String?
    @Published var slice: ReflectPlaceConnectSlice?
    @Published var placementId: String?
    @Published var isLoading = false
    @Published var sourceLabel = "Loading"
    @Published var loadError: String?
    @Published var hasConfirmedConnection = false
    @Published var editedReflection = PrototypeData.reflectPlaceConnectSlice.profile.reflection.summary
    @Published var reflectionDraft = PrototypeAppState.defaultReflectionAnswers.joined(separator: "\n")
    @Published var realtimeSession: RealtimeSessionEnvelope?
    @Published var realtimeStatus = "Ready"
    @Published var realtimeError: String?
    @Published var isStartingVoice = false
    @Published var capturedVoiceSignals: [String] = []
    @Published var isSynthesizingPlacement = false
    @Published var realtimeTranscript = ""
    @Published var basicInfo: BasicInfo?
    @Published var concernFlag = false
    @Published var placementConcern = ""
    @Published var communities: [Community] = []
    @Published var joinedCommunities: [Community] = []
    @Published var isLoadingCommunities = false
    @Published var communityError: String?
    @Published var communityMembers: [CommunityMember] = []
    @Published var isLoadingCommunityMembers = false
    @Published var circles: [PlacementCircle] = []
    @Published var joinedCircles: [PlacementCircle] = []
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
    @Published var chatPreviews: [String: ChatMessage] = [:]
    @Published var soulmateError: String?
    @Published var isLoadingSoulmate = false
    @Published var soulmatePreferences = SoulmatePreferences.defaults
    @Published var notifications: [NotificationItem] = []
    @Published var activityItems: [NotificationItem] = []
    @Published var notificationError: String?
    @Published var readNotificationIds: Set<String> = []
    @Published var requestedTab: AppTab?
    @Published var validationDirectCommunityMembers = false
    @Published var pendingPastMeetDetail = false

    private let voiceClient = RealtimeVoiceClient()

    private var client: LikemindedAPIClient {
        LikemindedAPIClient(authToken: authSession?.token)
    }

    static let defaultReflectionAnswers = [
        "Slow, honest conversations.",
        "Warm, direct friendships.",
        "I want closeness with clear pacing and room to reflect."
    ]

    static let defaultPlacementConcernCopy = "This circle doesn't match how I connect with people."

    var displayPlacementConcern: String {
        let trimmed = placementConcern.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultPlacementConcernCopy : trimmed
    }

    var activeSlice: ReflectPlaceConnectSlice {
        slice ?? PrototypeData.reflectPlaceConnectSlice
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
        if let info = slice?.profile.basicInfo ?? basicInfo {
            basicInfo = info
        }
        slice = nil
        placementId = nil
        sourceLabel = "Ready"
        loadError = nil
    }

    var currentPlacement: CirclePlacement {
        activeSlice.placement
    }

    var canOpenConnection: Bool {
        switch currentPlacement.userState {
        case .accepted, .swapped:
            return true
        case .proposed, .deferred:
            return false
        }
    }

    var visibleMatches: [MatchRecommendation] {
        switch currentPlacement.userState {
        case .accepted, .swapped:
            return PrototypeData.matches
        case .proposed:
            return Array(PrototypeData.matches.prefix(1))
        case .deferred:
            return []
        }
    }

    var visibleChats: [ChatPreview] {
        canOpenConnection ? PrototypeData.chats : []
    }

    var connectionsGateMessage: String {
        switch currentPlacement.userState {
        case .accepted:
            return "Your circle is live with member and meetup details."
        case .swapped:
            return "Room swapped. Let the new fit settle."
        case .proposed:
            return "Accept or swap a room before full browsing."
        case .deferred:
            return "Connections paused until placement resumes."
        }
    }

    var currentReflectionAnswers: [String] {
        reflectionDraft
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var voiceIsReady: Bool {
        realtimeSession?.isReady == true
    }

    var hasCapturedVoiceSignals: Bool {
        !capturedVoiceSignals.isEmpty
    }

    var isVoiceStreaming: Bool {
        realtimeStatus == RealtimeVoicePhase.streaming.rawValue || realtimeStatus == RealtimeVoicePhase.stopping.rawValue
    }

    func signInForLocalValidationIfNeeded() async {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--likeminded-start-community-members") {
            validationDirectCommunityMembers = true
        }
        if arguments.contains("--likeminded-start-past-meet-detail")
            || environment["LIKEMINDED_VALIDATION_SCREEN"] == "past-meet-detail" {
            validationDirectCommunityMembers = false
            UserDefaults.standard.set("past-meet-detail", forKey: "LIKEMINDED_VALIDATION_SCREEN")
        }
        if arguments.contains("--likeminded-start-chat")
            || environment["LIKEMINDED_VALIDATION_SCREEN"] == "chat" {
            UserDefaults.standard.set("chat", forKey: "LIKEMINDED_VALIDATION_SCREEN")
        }
        guard environment["LIKEMINDED_DEV_AUTH_BYPASS"] == "1" || arguments.contains("--likeminded-dev-auth-bypass") else { return }
        let shouldSeedVoicePlacement = arguments.contains("--likeminded-dev-voice-placement")
        isAuthenticating = true
        authError = nil
        let devToken = Self.argumentValue(after: "--likeminded-dev-auth-token", in: arguments)
            ?? environment["LIKEMINDED_DEV_AUTH_TOKEN"]
            ?? "local-simulator-tester"
        let devName = Self.argumentValue(after: "--likeminded-dev-auth-name", in: arguments)
            ?? environment["LIKEMINDED_DEV_AUTH_NAME"]
            ?? "Simulator Tester"
        do {
            let response = try await client.authenticateWithApple(
                identityToken: devToken,
                authorizationCode: nil,
                fullName: devName
            )
            await saveSessionAndLoadPlacement(response, authProvider: "apple")
            if shouldSeedVoicePlacement {
                await createProfileFromInterview(
                    transcript: environment["LIKEMINDED_DEV_TRANSCRIPT"] ?? "I want honest conversations, small warm circles, steady trust, books, design, and people who communicate directly."
                )
            }
            applyDevProfileConcernLaunchArg(from: arguments)
            applyDevTabLaunchArg(from: arguments)
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
        #endif
    }

    func signIn(with payload: AppleSignInCredentialPayload) async {
        isAuthenticating = true
        authError = nil
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

    private func saveSessionAndLoadPlacement(
        _ response: AppleAuthResponse,
        authProvider: String,
        appleUserIdentifier: String? = nil
    ) async {
        let session = AuthSession(
            userId: response.user.id,
            token: response.sessionToken,
            email: response.user.email,
            fullName: response.user.fullName,
            appleUserIdentifier: appleUserIdentifier,
            authProvider: authProvider
        )
        AuthSessionStore.save(session)
        authSession = session
        await loadCurrentPlacement()
        applyDevProfileEmptyPreviewIfNeeded()
    }

    func signOut() {
        AuthSessionStore.clear()
        authSession = nil
        slice = nil
        placementId = nil
        realtimeSession = nil
        authError = nil
        loadError = nil
        voiceClient.disconnect()
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

    func loadCurrentPlacement() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            let result = try await client.fetchMyPlacement()
            applyProfileResult(result, source: "Saved placement")
            loadError = nil
            applyDevProfileEmptyPreviewIfNeeded()
        } catch {
            if slice == nil {
                sourceLabel = "Ready"
            }
            loadError = nil
        }
        applyValidationLaunchOverrides()
        isLoading = false
    }

    func startVoiceSession() async {
        guard isSignedIn else {
            authError = "Sign in before starting a voice profile."
            return
        }
        isStartingVoice = true
        realtimeStatus = "Opening"
        realtimeError = nil
        voiceClient.authToken = authSession?.token
        voiceClient.baseURL = client.baseURL
        voiceClient.basicInfo = basicInfo
        voiceClient.reinterviewContext = concernFlag ? placementConcernContext : nil

        do {
            try await voiceClient.start(
                sdpOffer: "",
                model: realtimeSession?.model ?? "gpt-realtime-1.5",
                voice: realtimeSession?.voice ?? "marin"
            ) { [weak self] update in
                self?.applyVoiceUpdate(update)
            }
        } catch {
            realtimeStatus = RealtimeVoicePhase.failed.rawValue
            realtimeError = error.localizedDescription
        }

        isStartingVoice = false
    }

    func stopVoiceSession() async {
        await voiceClient.stop()
    }

    func resetVoiceSession() {
        voiceClient.disconnect()
        realtimeSession = nil
        realtimeStatus = RealtimeVoicePhase.idle.rawValue
        realtimeError = nil
        realtimeTranscript = ""
        capturedVoiceSignals = []
    }

    func seedVoiceSessionPreviewIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--likeminded-dev-voice-preview") else { return }
        realtimeStatus = RealtimeVoicePhase.streaming.rawValue
        realtimeError = nil
        capturedVoiceSignals = [
            "Prefers slow, honest conversation",
            "Values steady and thoughtful pacing",
            "Enjoys depth over small talk"
        ]
        #endif
    }

    func synthesizePlacementFromVoice() async {
        let answers = capturedVoiceSignals.isEmpty ? currentReflectionAnswers : capturedVoiceSignals
        reflectionDraft = answers.joined(separator: "\n")
        isSynthesizingPlacement = true
        await loadSlice()
        isSynthesizingPlacement = false
    }

    func loadSlice() async {
        isLoading = true
        hasConfirmedConnection = false

        do {
            let result = try await client.fetchMyPlacement()
            applyProfileResult(result, source: "Saved placement")
            loadError = nil
        } catch {
            sourceLabel = "Ready"
            loadError = "No saved placement yet. Start a voice profile to create one."
        }

        isLoading = false
    }

    func updatePlacementState(_ newState: PlacementState) {
        withMutableSlice { next in
            next.placement.userState = newState
        }

        if !canOpenConnection {
            hasConfirmedConnection = false
        }
    }

    func acceptPlacement() {
        withMutableSlice { next in
            var updatedProfile = next.profile
            updatedProfile = SynthesizedProfile(
                profileId: updatedProfile.profileId,
                displayName: updatedProfile.displayName,
                basicInfo: updatedProfile.basicInfo,
                values: updatedProfile.values,
                communicationStyle: updatedProfile.communicationStyle,
                emotionalRhythm: updatedProfile.emotionalRhythm,
                relationshipIntent: updatedProfile.relationshipIntent,
                interests: updatedProfile.interests,
                privacy: updatedProfile.privacy,
                reflection: ProfileReflection(
                    summary: editedReflection,
                    strengths: updatedProfile.reflection.strengths,
                    nextQuestion: updatedProfile.reflection.nextQuestion
                )
            )
            next.profile = updatedProfile
        }
        Task {
            try? await client.updateProfile(reflectionSummary: editedReflection, signals: slice?.signals)
            await updatePlacementAction("accept")
        }
    }

    func deferPlacement() {
        Task { await updatePlacementAction("defer") }
    }

    func swapPrimaryCircle() {
        Task { await updatePlacementAction("swap") }
    }

    func confirmConnection() {
        hasConfirmedConnection = true
    }

    func resetConnection() {
        hasConfirmedConnection = false
    }

    private func withMutableSlice(_ update: (inout ReflectPlaceConnectSlice) -> Void) {
        var next = activeSlice
        update(&next)
        slice = next
    }

    func createProfileFromInterview() async {
        await createProfileFromInterview(transcript: voiceClient.interviewTranscript)
    }

    func startReinterview() async {
        await startVoiceSession()
    }

    func completeOnboarding(_ info: BasicInfo) {
        basicInfo = info
        loadError = nil
    }

    @discardableResult
    func updateProfileBasics(
        name: String,
        city: String,
        gender: Gender?,
        dateOfBirth: String?,
        pincode: String?
    ) async -> Bool {
        guard isSignedIn else { return false }
        let existing = basicInfo ?? slice?.profile.basicInfo
        let update = BasicInfoUpdate(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: (gender ?? existing?.gender)?.rawValue,
            dateOfBirth: dateOfBirth ?? existing?.dateOfBirth,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            pincode: pincode ?? existing?.pincode
        )
        do {
            let profile = try await client.updateProfile(basicInfo: update)
            if let info = profile.basicInfo {
                basicInfo = info
            }
            loadError = nil
            return true
        } catch {
            loadError = "Profile could not be saved."
            return false
        }
    }

    @discardableResult
    func refreshProfileFromReflection(_ answers: [String]) async -> Bool {
        guard isSignedIn else { return false }
        isSynthesizingPlacement = true
        defer { isSynthesizingPlacement = false }
        do {
            let result = try await client.createProfileFromInterview(
                interviewTranscript: answers.joined(separator: "\n"),
                reflectionAnswers: answers
            )
            applyProfileResult(result, source: "Voice profile refreshed")
            loadError = nil
            return true
        } catch {
            loadError = "Voice profile refresh could not be saved."
            return false
        }
    }

    private func createProfileFromInterview(transcript: String) async {
        let transcript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }
        guard isSignedIn else {
            authError = "Sign in before creating a profile."
            return
        }
        isSynthesizingPlacement = true
        sourceLabel = "AI interview..."

        do {
            let result = try await client.createProfileFromInterview(
                interviewTranscript: transcript,
                reflectionAnswers: currentReflectionAnswers.isEmpty ? nil : currentReflectionAnswers
            )

            guard !result.profileId.isEmpty else {
                throw URLError(.zeroByteResource)
            }

            applyProfileResult(result, source: result.placement.isNewCircle ? "New circle for you" : "AI Interview Profile")
            loadError = nil
        } catch {
            sourceLabel = "Retry"
            loadError = "Profile creation failed. Check the API connection and try again."
        }

        isSynthesizingPlacement = false
        isLoading = false
    }

    func submitFeedback(rating: Int, message: String) async {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await client.submitFeedback(
                profileId: slice?.profile.profileId,
                placementId: placementId,
                rating: rating,
                message: message,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
            )
        } catch {
            loadError = "Feedback could not be sent. Please try again."
        }
    }

    func reportPlacementConcern(_ message: String) async {
        let note = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        placementConcern = note
        concernFlag = true
        try? await client.registerCircleConcern(message: note)
        await submitFeedback(rating: 2, message: "Circle fit concern: \(note)")
    }

    func fetchCircles() async {
        isLoadingCircles = true
        defer { isLoadingCircles = false }
        do {
            async let catalog = client.fetchCircles()
            async let joined = isSignedIn ? client.fetchMyCircles() : []
            circles = try await catalog
            joinedCircles = try await joined
            circleError = nil
        } catch {
            circleError = "Circles could not be loaded."
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
        isLoadingCommunityMembers = true
        defer { isLoadingCommunityMembers = false }
        do {
            communityMembers = try await client.fetchCommunityMembers(id: id)
            communityError = nil
        } catch {
            communityMembers = []
            communityError = "Community members could not be loaded."
        }
    }

    func createMeeting(
        kind: String,
        targetId: String,
        title: String,
        scheduledAt: String,
        location: String,
        details: String
    ) async -> Meeting? {
        do {
            let meeting = try await client.createMeeting(
                kind: kind,
                targetId: targetId,
                title: title,
                scheduledAt: scheduledAt,
                location: location,
                details: details
            )
            await fetchMeetings()
            meetingError = nil
            return meeting
        } catch {
            meetingError = "Event could not be created."
            return nil
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

    func saveMeetingRecapNote(meetingId: String, note: String) async {
        do {
            try await client.saveMeetingRecapNote(meetingId: meetingId, note: note)
            await fetchMeetings()
        } catch {
            meetingError = "Recap note could not be saved."
        }
    }

    func joinMeeting(id: String) async throws -> LiveKitJoinToken {
        try await LiveKitTokenProvider(client: client).token(for: id)
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

    func fetchSoulmateStatus() async {
        guard isSignedIn else { return }
        isLoadingSoulmate = true
        defer { isLoadingSoulmate = false }
        do {
            let status = try await client.fetchSoulmateStatus()
            soulmateEnabled = status.enabled
            soulmatePendingSelections = status.pendingSelections
            soulmatePreferences = status.preferences ?? .defaults
            soulmateMatches = try await client.fetchSoulmateMatches()
            var previews: [String: ChatMessage] = [:]
            for match in soulmateMatches {
                let messages = try await client.fetchMessages(matchId: match.matchId)
                if let last = messages.last {
                    previews[match.matchId] = last
                }
            }
            chatPreviews = previews
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
            soulmateError = "Soulmate preferences could not be saved."
            return false
        }
    }

    func submitSoulmateSelection(meetingId: String, selectedUserIds: [String]) async {
        do {
            try await client.submitSoulmateSelection(meetingId: meetingId, selectedUserIds: selectedUserIds)
            await fetchSoulmateStatus()
        } catch {
            soulmateError = "Soulmate selection could not be saved."
        }
    }

    func fetchSoulmateMatchDetail(id: String) async throws -> SoulmateMatchDetail {
        try await client.fetchSoulmateMatchDetail(id: id)
    }

    func fetchMessages(matchId: String) async throws -> [ChatMessage] {
        try await client.fetchMessages(matchId: matchId)
    }

    func sendMessage(matchId: String, text: String) async throws -> ChatMessage {
        try await client.sendMessage(matchId: matchId, text: text)
    }

    private var placementConcernContext: String {
        [
            "User concern: \(placementConcern)",
            "Current circle: \(currentPlacement.primaryCircle.name)",
            "Current profile summary: \(activeSlice.profile.reflection.summary)",
            "Existing voice/profile state should be reused; ask only what is needed to correct placement."
        ].joined(separator: "\n")
    }

    private func updatePlacementAction(_ action: String) async {
        do {
            let result = try await client.updatePlacement(action: action)
            applyProfileResult(result, source: "Placement updated")
            if action != "accept" {
                hasConfirmedConnection = false
            }
            loadError = nil
        } catch {
            loadError = "Placement update failed. Please retry."
        }
    }

    private func applyProfileResult(_ result: ProfileCircleMatchResult, source: String) {
        let style = result.signals.communicationStyle?.primary ?? "balanced"
        let energy = result.signals.socialEnergy ?? "steady"
        let attachment = result.signals.attachment ?? "secure"
        var newSlice = PrototypeData.reflectPlaceConnectSlice
        newSlice.profile = SynthesizedProfile(
            profileId: result.profileId,
            displayName: result.basicInfo?.name ?? basicInfo?.name ?? "You",
            basicInfo: result.basicInfo ?? basicInfo,
            values: deriveValues(from: result.signals),
            communicationStyle: style,
            emotionalRhythm: energy,
            relationshipIntent: attachment,
            interests: result.interests?.isEmpty == false ? result.interests! : deriveInterests(from: result.signals),
            privacy: ProfilePrivacy(aiReflectionVisibleToUser: true, matchExplanationVisibleToMatches: false),
            reflection: ProfileReflection(
                summary: result.profileSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? result.profileSummary!
                    : "AI extracted your personality from \(estimateWordCount(from: voiceClient.interviewTranscript)) words of voice conversation.",
                strengths: deriveStrengths(from: result.signals),
                nextQuestion: nextQuestion(from: result.signals)
            )
        )
        newSlice.placement = result.placement
        newSlice.signals = result.signals
        newSlice.hiddenSignals = result.hiddenSignals
        slice = newSlice
        placementId = result.placementId
        editedReflection = newSlice.profile.reflection.summary
        sourceLabel = source
        applyConcernState(concernFlag: result.concernFlag, placementConcern: result.placementConcern)
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

    private func applyDevTabLaunchArg(from arguments: [String]) {
        if arguments.contains("--likeminded-start-circles") || arguments.contains("--likeminded-start-circle-detail") {
            requestedTab = .circles
        } else if arguments.contains("--likeminded-start-create-event")
            || arguments.contains("--likeminded-start-create-community")
            || arguments.contains("--likeminded-start-community-members")
            || arguments.contains("--likeminded-start-community-detail")
            || arguments.contains("--likeminded-start-communities") {
            requestedTab = .communities
        } else if arguments.contains("--likeminded-start-soulmate")
            || arguments.contains("--likeminded-start-soulmate-selection")
            || arguments.contains("--likeminded-start-chat") {
            requestedTab = .soulmate
        } else if arguments.contains("--likeminded-start-profile")
            || arguments.contains("--likeminded-start-settings")
            || arguments.contains("--likeminded-start-settings-info")
            || arguments.contains("--likeminded-start-settings-support") {
            requestedTab = .profile
        } else if arguments.contains("--likeminded-start-past-meet-detail") {
            requestedTab = .meet
            pendingPastMeetDetail = true
        }
    }

    private func applyValidationLaunchOverrides() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        applyDevProfileConcernLaunchArg(from: arguments)
        applyDevTabLaunchArg(from: arguments)
        #endif
    }

    private func estimateWordCount(from transcript: String) -> Int {
        transcript.split { $0.isWhitespace || $0.isNewline }.count
    }

    private func deriveValues(from signals: ProfileSignals) -> [String] {
        var values: [String] = []
        if signals.bigFive.openness > 0.65 { values.append("curiosity") }
        if signals.bigFive.conscientiousness > 0.65 { values.append("intentionality") }
        if signals.bigFive.agreeableness > 0.65 { values.append("warmth") }
        if signals.bigFive.neuroticism > 0.6 { values.append("emotional depth") }
        if signals.trustPattern == "fastTrust" { values.append("generous trust") }
        if signals.socialEnergy == "low" { values.append("presence") }
        if signals.socialEnergy == "high" { values.append("energy") }
        if values.isEmpty { values = ["authenticity", "thoughtful connection"] }
        return values
    }

    private func deriveStrengths(from signals: ProfileSignals) -> [String] {
        var strengths: [String] = []
        if signals.bigFive.openness > 0.6 { strengths.append("Open to new ideas and experiences") }
        if signals.bigFive.agreeableness > 0.6 { strengths.append("Warm and cooperative with others") }
        if signals.bigFive.extraversion > 0.6 { strengths.append("Energetic in social settings") }
        if signals.bigFive.extraversion < 0.4 { strengths.append("Thoughtful and reflective listener") }
        if signals.trustPattern == "slowTrust" { strengths.append("Builds deep, earned trust over time") }
        if signals.communicationStyle?.primary == "direct" { strengths.append("Communicates clearly and honestly") }
        if signals.communicationStyle?.primary == "warm" { strengths.append("Makes others feel heard and understood") }
        if signals.communicationStyle?.primary == "analytical" { strengths.append("Thinks deeply and communicates with precision") }
        if strengths.isEmpty { strengths = ["Authentic communicator", "Thoughtful presence"] }
        return Array(strengths.prefix(4))
    }

    private func deriveInterests(from signals: ProfileSignals) -> [Interest] {
        var interests: [Interest] = []
        if signals.bigFive.openness > 0.6 { interests.append(Interest(area: "mind", label: "ideas", depth: .active)) }
        if signals.socialEnergy == "high" { interests.append(Interest(area: "community", label: "community", depth: .active)) }
        if signals.socialEnergy == "low" { interests.append(Interest(area: "connection", label: "1:1 conversation", depth: .deep)) }
        if signals.bigFive.conscientiousness > 0.6 { interests.append(Interest(area: "work", label: "meaningful work", depth: .active)) }
        if signals.bigFive.agreeableness > 0.6 { interests.append(Interest(area: "people", label: "people", depth: .active)) }
        if interests.isEmpty {
            interests = [
                Interest(area: "connection", label: "genuine connection", depth: .active),
                Interest(area: "connection", label: "meaningful conversation", depth: .active)
            ]
        }
        return interests
    }

    private func nextQuestion(from signals: ProfileSignals) -> String {
        if signals.bigFive.openness > 0.6 {
            return "What idea has captured your curiosity recently?"
        }
        if signals.bigFive.agreeableness > 0.6 {
            return "When do you feel most at peace with the people around you?"
        }
        if signals.bigFive.extraversion > 0.6 {
            return "What kind of social setting makes you feel most alive?"
        }
        return "What kind of connection are you hoping to find here?"
    }

    private func applyVoiceUpdate(_ update: RealtimeVoiceUpdate) {
        realtimeStatus = update.phase.rawValue

        if let message = update.message {
            realtimeError = update.phase == .failed ? message : nil
            if update.phase != .failed {
                sourceLabel = message
            }
        }

        if let transcript = update.transcript, !transcript.isEmpty {
            realtimeTranscript = transcript
            let signals = Self.signals(from: realtimeTranscript)
            if !signals.isEmpty {
                capturedVoiceSignals = signals
            }
        }

        // Auto-submit transcript when voice session ends with content
        if update.didPersistProfile {
            concernFlag = false
            placementConcern = ""
            Task {
                await loadCurrentPlacement()
            }
        }
    }

    private static func argumentValue(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func signals(from transcript: String) -> [String] {
        transcript
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-•*0123456789. "))
            }
            .filter { !$0.isEmpty && $0.count > 5 }
            .prefix(5)
            .map { String($0) }
    }
}

import AuthenticationServices
import Foundation

@MainActor
final class PrototypeAppState: ObservableObject {
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

    private let voiceClient = RealtimeVoiceClient()

    private var client: LikemindedAPIClient {
        LikemindedAPIClient(authToken: authSession?.token)
    }

    static let defaultReflectionAnswers = [
        "Slow, honest conversations.",
        "Warm, direct friendships.",
        "I want closeness with clear pacing and room to reflect."
    ]

    var activeSlice: ReflectPlaceConnectSlice {
        slice ?? PrototypeData.reflectPlaceConnectSlice
    }

    var isSignedIn: Bool {
        authSession != nil
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
            return "Room accepted. Fuller paths are open."
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
        guard environment["LIKEMINDED_DEV_AUTH_BYPASS"] == "1" || arguments.contains("--likeminded-dev-auth-bypass") else { return }
        let shouldSeedVoicePlacement = arguments.contains("--likeminded-dev-voice-placement")
        isAuthenticating = true
        authError = nil
        do {
            let response = try await client.authenticateWithApple(
                identityToken: environment["LIKEMINDED_DEV_AUTH_TOKEN"] ?? "local-simulator-tester",
                authorizationCode: nil,
                fullName: "Simulator Tester"
            )
            await saveSessionAndLoadPlacement(response)
            if shouldSeedVoicePlacement {
                await createProfileFromInterview(
                    transcript: environment["LIKEMINDED_DEV_TRANSCRIPT"] ?? "I want honest conversations, small warm circles, steady trust, books, design, and people who communicate directly."
                )
            }
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
        #endif
    }

    func signIn(with credential: ASAuthorizationAppleIDCredential) async {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            authError = "Apple did not return an identity token."
            return
        }
        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        let formatter = PersonNameComponentsFormatter()
        let fullName = credential.fullName.map { formatter.string(from: $0) }
        isAuthenticating = true
        authError = nil
        do {
            let response = try await client.authenticateWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName?.isEmpty == false ? fullName : nil
            )
            await saveSessionAndLoadPlacement(response)
        } catch {
            authError = error.localizedDescription
        }
        isAuthenticating = false
    }

    private func saveSessionAndLoadPlacement(_ response: AppleAuthResponse) async {
        let session = AuthSession(
            userId: response.user.id,
            token: response.sessionToken,
            email: response.user.email,
            fullName: response.user.fullName
        )
        AuthSessionStore.save(session)
        authSession = session
        await loadCurrentPlacement()
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

    func loadCurrentPlacement() async {
        guard isSignedIn else { return }
        isLoading = true
        do {
            let result = try await client.fetchMyPlacement()
            applyProfileResult(result, source: "Saved placement")
            loadError = nil
        } catch {
            if slice == nil {
                sourceLabel = "Ready"
            }
            loadError = nil
        }
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

        do {
            // WebRTC flow — no client secret needed, SDP exchange handles auth
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
            displayName: "You",
            values: deriveValues(from: result.signals),
            communicationStyle: style,
            emotionalRhythm: energy,
            relationshipIntent: attachment,
            interests: deriveInterests(from: result.signals),
            privacy: ProfilePrivacy(aiReflectionVisibleToUser: true, matchExplanationVisibleToMatches: false),
            reflection: ProfileReflection(
                summary: "AI extracted your personality from \(estimateWordCount(from: voiceClient.interviewTranscript)) words of voice conversation.",
                strengths: deriveStrengths(from: result.signals),
                nextQuestion: nextQuestion(from: result.signals)
            )
        )
        newSlice.placement = result.placement
        newSlice.signals = result.signals
        slice = newSlice
        placementId = result.placementId
        editedReflection = newSlice.profile.reflection.summary
        sourceLabel = source
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

    private func deriveInterests(from signals: ProfileSignals) -> [String] {
        var interests: [String] = []
        if signals.bigFive.openness > 0.6 { interests.append("ideas") }
        if signals.socialEnergy == "high" { interests.append("community") }
        if signals.socialEnergy == "low" { interests.append("1:1 conversation") }
        if signals.bigFive.conscientiousness > 0.6 { interests.append("meaningful work") }
        if signals.bigFive.agreeableness > 0.6 { interests.append("people") }
        if interests.isEmpty { interests = ["genuine connection", "meaningful conversation"] }
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
            realtimeTranscript += transcript
            let signals = Self.signals(from: realtimeTranscript)
            if !signals.isEmpty {
                capturedVoiceSignals = signals
            }
        }

        // Auto-submit transcript when voice session ends with content
        if update.phase == .stopped && !realtimeTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await createProfileFromInterview(transcript: realtimeTranscript)
            }
        }
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

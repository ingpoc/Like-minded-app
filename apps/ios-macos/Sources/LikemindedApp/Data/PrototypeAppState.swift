import Foundation

@MainActor
final class PrototypeAppState: ObservableObject {
    @Published var slice: ReflectPlaceConnectSlice?
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

    private let client = LikemindedAPIClient()
    private let voiceClient = RealtimeVoiceClient()

    static let defaultReflectionAnswers = [
        "Slow, honest conversations.",
        "Warm, direct friendships.",
        "I want closeness with clear pacing and room to reflect."
    ]

    var activeSlice: ReflectPlaceConnectSlice {
        slice ?? PrototypeData.reflectPlaceConnectSlice
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

    func startVoiceSession() async {
        isStartingVoice = true
        realtimeStatus = "Opening"
        realtimeError = nil

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
            let loadedSlice = try await client.fetchReflectPlaceConnect(reflectionAnswers: currentReflectionAnswers)
            slice = loadedSlice
            editedReflection = loadedSlice.profile.reflection.summary
            sourceLabel = "Mock API"
            loadError = nil
        } catch {
            if slice == nil {
                slice = PrototypeData.reflectPlaceConnectSlice
            }
            sourceLabel = "Local"
            loadError = "Mock API offline. Showing local prototype data."
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
        updatePlacementState(.accepted)
    }

    func deferPlacement() {
        updatePlacementState(.deferred)
    }

    func swapPrimaryCircle() {
        withMutableSlice { next in
            guard let nextPrimary = next.placement.secondaryCircles.first else { return }

            let oldPrimary = next.placement.primaryCircle
            next.placement.primaryCircle = nextPrimary
            next.placement.secondaryCircles = Array(next.placement.secondaryCircles.dropFirst()) + [oldPrimary]
            next.placement.userState = .swapped
        }

        hasConfirmedConnection = false
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
        guard !voiceClient.interviewTranscript.isEmpty else { return }
        isSynthesizingPlacement = true
        sourceLabel = "AI interview..."

        do {
            let result = try await client.createProfileFromInterview(
                interviewTranscript: voiceClient.interviewTranscript,
                reflectionAnswers: currentReflectionAnswers.isEmpty ? nil : currentReflectionAnswers
            )

            guard !result.profileId.isEmpty else {
                throw URLError(.zeroByteResource)
            }

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
            slice = newSlice
            sourceLabel = result.placement.isNewCircle ? "New circle for you" : "AI Interview Profile"
            loadError = nil
        } catch {
            if slice == nil {
                slice = PrototypeData.reflectPlaceConnectSlice
            }
            sourceLabel = "Local"
            loadError = "Profile creation offline. Showing prototype data."
        }

        isSynthesizingPlacement = false
        isLoading = false
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
                await createProfileFromInterview()
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

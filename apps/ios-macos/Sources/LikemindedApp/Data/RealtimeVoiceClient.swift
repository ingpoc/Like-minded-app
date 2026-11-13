import AVFoundation
import Foundation
import LiveKitWebRTC

enum RealtimeVoicePhase: String {
    case idle = "Ready"
    case connecting = "Opening"
    case streaming = "Listening"
    case speaking = "Responding"
    case stopping = "Placing"
    case stopped = "Captured"
    case failed = "Voice issue"
}

enum RealtimeVoiceError: LocalizedError {
    case microphoneDenied
    case microphoneRestricted
    case microphoneUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Microphone access is off. Allow Likeminded in Privacy & Security → Microphone settings, then try again."
        case .microphoneRestricted:
            "Microphone access is restricted. Check Screen Time or device-management settings."
        case .microphoneUnavailable:
            "No microphone is available. Connect an input device, then try again."
        }
    }
}

struct RealtimeVoiceUpdate {
    let phase: RealtimeVoicePhase
    let message: String?
    let transcript: String?
    var didPersistProfile = false
}

final class RealtimeVoiceClient: NSObject {
    var baseURL = LikemindedAPIClient.defaultBaseURL()
    var authToken: String?
    var basicInfo: BasicInfo?

    private var onUpdate: ((RealtimeVoiceUpdate) -> Void)?
    private var isStreaming = false
    private var isClosing = false

    private var peerConnection: LKRTCPeerConnection?
    private var dataChannel: LKRTCDataChannel?
    private var audioTrack: LKRTCAudioTrack?
    private var audioLevelTimer: Timer?
    private var onAudioLevel: ((Double) -> Void)?
    private var previousAudioEnergy: Double?
    private var previousAudioDuration: Double?
    private var voiceSession: RealtimeSessionEnvelope?
    private var currentModel: String = "gpt-realtime-mini"
    private var currentVoice: String = "marin"
    private var ephemeralKey: String?

    private var assistantTranscriptBuffer = ""
    private var conversationTranscript = ""
    private var userTurnCount = 0
    private var didSubmitProfilePlacement = false
    private var processedFunctionCallIDs = Set<String>()
    private var inFlightFunctionCallIDs = Set<String>()
    private var functionCallGeneration = UUID()
    private let functionCallLock = NSLock()

    private let factory: LKRTCPeerConnectionFactory

    private var audioPlayerNode: AVAudioPlayerNode?
    private let audioEngine = AVAudioEngine()
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    override init() {
        LKRTCInitializeSSL()
        factory = LKRTCPeerConnectionFactory()
        super.init()
    }

    private func log(_ msg: String) {
        NSLog("[RealtimeVoice] \(msg)")
    }

    func start(
        sdpOffer: String,
        model: String,
        voice: String,
        ephemeralKey: String,
        onAudioLevel: ((Double) -> Void)? = nil,
        onUpdate: @escaping (RealtimeVoiceUpdate) -> Void
    ) async throws {
        try await ensureMicrophoneAccess()
        var didStart = false
        defer {
            if !didStart { teardown() }
        }
        self.onUpdate = onUpdate
        self.currentModel = model
        self.currentVoice = voice
        self.ephemeralKey = ephemeralKey
        self.onAudioLevel = onAudioLevel
        previousAudioEnergy = nil
        previousAudioDuration = nil
        isClosing = false
        assistantTranscriptBuffer = ""
        conversationTranscript = ""
        userTurnCount = 0
        resetFunctionCallState()
        publish(.connecting, message: "Connecting to Realtime.", transcript: nil)
        log("start: WebRTC connection")

        // Set up audio session for WebRTC
#if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try audioSession.setActive(true)
        log("start: audio session configured voiceChat")
#endif

        // Create peer connection
        let config = LKRTCConfiguration()
        config.iceServers = []
        config.sdpSemantics = .unifiedPlan

        let constraints = LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        guard let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            throw NSError(domain: "LikemindedRealtimeVoice", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create RTCPeerConnection."
            ])
        }
        peerConnection = pc
        log("start: peer connection created")

        // Add audio track for mic input
        let audioConstraints = LKRTCMediaConstraints(
            mandatoryConstraints: [
                "googEchoCancellation": "true",
                "googAutoGainControl": "true",
                "googNoiseSuppression": "true"
            ],
            optionalConstraints: nil
        )
        let audioSource = factory.audioSource(with: audioConstraints)
        let track = factory.audioTrack(with: audioSource, trackId: "audio0")
        audioTrack = track
        pc.add(track, streamIds: ["audio"])
        log("start: audio track added")

        // Create data channel for events
        let dcConfig = LKRTCDataChannelConfiguration()
        dcConfig.isOrdered = true
        guard let dc = pc.dataChannel(forLabel: "oai-events", configuration: dcConfig) else {
            throw NSError(domain: "LikemindedRealtimeVoice", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create data channel."
            ])
        }
        dc.delegate = self
        dataChannel = dc
        log("start: data channel created")

        // Create SDP offer, set local description
        let offerConstraints = LKRTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "true"],
            optionalConstraints: nil
        )
        let sdp = try await createOffer(peer: pc, constraints: offerConstraints)
        try await setLocalDescription(peer: pc, sdp: sdp)
        log("start: local SDP offer created")

        // Exchange SDP with our server, which forwards to OpenAI
        let answerSdp = try await exchangeSDPDirectly(pc.localDescription?.sdp ?? sdpOffer)
        try Task.checkCancellation()
        log("start: received SDP answer from server")

        // Set remote description
        let answer = LKRTCSessionDescription(type: .answer, sdp: answerSdp)
        try await setRemoteDescription(peer: pc, description: answer)
        log("start: remote description set")

        isStreaming = true
        startAudioLevelMonitoring()
        didStart = true
    }

    private func ensureMicrophoneAccess() async throws {
        guard AVCaptureDevice.default(for: .audio) != nil else {
            throw RealtimeVoiceError.microphoneUnavailable
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted { throw RealtimeVoiceError.microphoneDenied }
        case .denied:
            throw RealtimeVoiceError.microphoneDenied
        case .restricted:
            throw RealtimeVoiceError.microphoneRestricted
        @unknown default:
            throw RealtimeVoiceError.microphoneUnavailable
        }
    }

    func stop() async {
        guard isStreaming else {
            disconnect()
            return
        }
        isClosing = true
        publish(.stopping, message: "Wrapping up the conversation.", transcript: nil)
        teardown()
        isStreaming = false
        publish(.stopped, message: stoppedMessage(), transcript: nil)
    }

    func disconnect() {
        isClosing = true
        teardown()
        isStreaming = false
        publish(.stopped, message: "Voice session closed.", transcript: nil)
    }

    private var heartbeatTimer: Timer?

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.dataChannel?.readyState == .open {
                self.sendEvent(["type": "ping"])
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func attemptReconnect() {
        log("ICE connection lost; a new ephemeral session is required")
        teardown()
        publish(.failed, message: "Voice connection lost. Start again.", transcript: nil)
    }

    private func teardown() {
        stopHeartbeat()
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        onAudioLevel?(0)
        onAudioLevel = nil
        previousAudioEnergy = nil
        previousAudioDuration = nil
        dataChannel?.close()
        dataChannel = nil
        peerConnection?.close()
        peerConnection = nil
        audioTrack = nil
        audioEngine.stop()
        audioPlayerNode?.stop()
        ephemeralKey = nil
    }

    private func startAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        guard onAudioLevel != nil else { return }
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            self?.sampleOutboundAudioLevel()
        }
    }

    private func sampleOutboundAudioLevel() {
        guard let peerConnection else { return }
        peerConnection.statistics { [weak self] report in
            let audioStatistics = report.statistics.values.filter { statistic in
                statistic.type == "media-source" || statistic.type == "outbound-rtp"
            }
            let directLevel = audioStatistics.compactMap { statistic in
                (statistic.values["audioLevel"] as? NSNumber)?.doubleValue
            }.max()
            let energySample = audioStatistics.compactMap { statistic -> (energy: Double, duration: Double)? in
                guard let energy = statistic.values["totalAudioEnergy"] as? NSNumber,
                      let duration = statistic.values["totalSamplesDuration"] as? NSNumber else {
                    return nil
                }
                return (energy.doubleValue, duration.doubleValue)
            }.max { first, second in
                first.duration < second.duration
            }
            DispatchQueue.main.async {
                guard let self else { return }
                var measuredLevel = directLevel
                if let energySample {
                    if let previousAudioEnergy = self.previousAudioEnergy,
                       let previousAudioDuration = self.previousAudioDuration,
                       energySample.duration > previousAudioDuration {
                        let energyDelta = max(energySample.energy - previousAudioEnergy, 0)
                        let durationDelta = energySample.duration - previousAudioDuration
                        measuredLevel = Self.normalizedAudioLevel(
                            rootMeanSquare: sqrt(energyDelta / durationDelta)
                        )
                    }
                    self.previousAudioEnergy = energySample.energy
                    self.previousAudioDuration = energySample.duration
                }
                if let measuredLevel {
                    self.onAudioLevel?(min(max(measuredLevel, 0), 1))
                }
            }
        }
    }

    private static func normalizedAudioLevel(rootMeanSquare: Double) -> Double {
        let decibels = 20 * log10(max(rootMeanSquare, 0.000_01))
        return min(max((decibels + 55) / 55, 0), 1)
    }

    // MARK: - SDP Exchange

    private func exchangeSDPDirectly(_ sdp: String) async throws -> String {
        guard let ephemeralKey else { throw URLError(.userAuthenticationRequired) }
        self.ephemeralKey = nil
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/realtime/calls")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(ephemeralKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/sdp", forHTTPHeaderField: "content-type")
        request.httpBody = sdp.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: errorText])
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - WebRTC async wrappers

    private func createOffer(peer: LKRTCPeerConnection, constraints: LKRTCMediaConstraints) async throws -> LKRTCSessionDescription {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<LKRTCSessionDescription, Error>) in
            peer.offer(for: constraints) { sdp, error in
                if let error { cont.resume(throwing: error) }
                else if let sdp { cont.resume(returning: sdp) }
                else { cont.resume(throwing: URLError(.unknown)) }
            }
        }
    }

    private func setLocalDescription(peer: LKRTCPeerConnection, sdp: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            peer.setLocalDescription(sdp) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }

    private func setRemoteDescription(peer: LKRTCPeerConnection, description: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            peer.setRemoteDescription(description) { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            }
        }
    }

    // MARK: - Event handling

    private func handleEvent(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return
        }

        log("recv: \(type)")

        switch type {
        case "session.created", "session.updated":
            log("session ready")
        case "conversation.item.input_audio_transcription.completed":
            let transcript = object["transcript"] as? String ?? ""
            appendTranscript("User", transcript)
        case "input_audio_buffer.committed":
            userTurnCount += 1
        case "response.output_audio_transcript.delta", "response.output_text.delta":
            let delta = object["delta"] as? String ?? ""
            assistantTranscriptBuffer += delta
        case "response.output_item.done":
            if let item = object["item"] as? [String: Any] {
                handleConversationItem(item)
            }
        case "response.function_call_arguments.done":
            let name = object["name"] as? String
            if (name == nil || name == "submit_profile_placement"),
               let arguments = object["arguments"] as? String,
               !arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task {
                    await submitProfilePlacement(arguments, callID: object["call_id"] as? String)
                }
            }
        case "response.output_audio_transcript.done", "response.output_text.done":
            let fullText = object["text"] as? String ?? object["transcript"] as? String ?? assistantTranscriptBuffer
            appendTranscript("AI", fullText)
            assistantTranscriptBuffer = ""
        case "response.output_audio.delta":
            if let delta = object["delta"] as? String {
                log("recv audio delta: \(delta.count) bytes")
                publish(.speaking, message: "AI is responding", transcript: conversationTranscript)
            }
        case "response.cancel":
            log("response cancelled by server — sending response.create to continue")
            sendEvent(["type": "response.create"])
        case "conversation.item.create":
            if let item = object["item"] as? [String: Any], let itemType = item["type"] as? String, itemType == "message" {
                log("conversation item created — server captured user input, triggering response")
                sendEvent(["type": "response.create"])
            }
        case "response.done":
            log("response.done — turn complete")
            publish(.streaming, message: "Listening", transcript: conversationTranscript)
        case "error":
            let errorObj = object["error"] as? [String: Any]
            let errorMsg = errorObj?["message"] as? String ?? "Realtime session error."
            log("server error: \(errorMsg)")
            publish(.failed, message: errorMsg, transcript: nil)
        default:
            break
        }
    }

    private func handleConversationItem(_ item: [String: Any]) {
        guard item["type"] as? String == "function_call",
              item["name"] as? String == "submit_profile_placement",
              let arguments = item["arguments"] as? String,
              !arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        Task {
            await submitProfilePlacement(arguments, callID: item["call_id"] as? String)
        }
    }

    private func submitProfilePlacement(_ arguments: String, callID: String?) async {
        let claim = claimFunctionCall(callID)
        guard claim.accepted else { return }
        var didProcess = false
        defer {
            finishFunctionCall(callID, generation: claim.generation, didProcess: didProcess)
        }
        guard let data = arguments.data(using: .utf8),
              var payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            log("ignored incomplete profile placement payload")
            return
        }
        payload["interviewTranscript"] = conversationTranscript
        if let basicInfo,
           let data = try? JSONEncoder().encode(basicInfo),
           let object = try? JSONSerialization.jsonObject(with: data) {
            payload["basicInfo"] = object
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let url = baseURL.appendingPathComponent("/v1/realtime/profile-placement")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let callID { request.setValue("realtime-profile-\(callID)", forHTTPHeaderField: "Idempotency-Key") }
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }
            didProcess = true
            if let callID {
                sendFunctionResult(callID: callID, output: ["saved": true])
            }
            publish(.stopped, message: "Profile saved.", transcript: conversationTranscript, didPersistProfile: true)
        } catch {
            if let callID {
                sendFunctionResult(callID: callID, output: ["saved": false, "error": "profile_placement_save_failed"])
            }
            publish(.failed, message: "Profile placement could not be saved.", transcript: nil)
        }
    }

    private func claimFunctionCall(_ callID: String?) -> (accepted: Bool, generation: UUID) {
        functionCallLock.lock()
        defer { functionCallLock.unlock() }
        let generation = functionCallGeneration
        guard let callID else { return (true, generation) }
        guard !processedFunctionCallIDs.contains(callID), !inFlightFunctionCallIDs.contains(callID) else {
            return (false, generation)
        }
        inFlightFunctionCallIDs.insert(callID)
        return (true, generation)
    }

    private func resetFunctionCallState() {
        functionCallLock.lock()
        defer { functionCallLock.unlock() }
        functionCallGeneration = UUID()
        didSubmitProfilePlacement = false
        processedFunctionCallIDs = []
        inFlightFunctionCallIDs = []
    }

    private func finishFunctionCall(_ callID: String?, generation: UUID, didProcess: Bool) {
        functionCallLock.lock()
        defer { functionCallLock.unlock() }
        guard generation == functionCallGeneration else { return }
        didSubmitProfilePlacement = didSubmitProfilePlacement || didProcess
        guard let callID else { return }
        inFlightFunctionCallIDs.remove(callID)
        if didProcess { processedFunctionCallIDs.insert(callID) }
    }

    private func sendFunctionResult(callID: String, output: [String: Any]) {
        let outputText = (try? JSONSerialization.data(withJSONObject: output))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        sendEvent([
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callID,
                "output": outputText
            ]
        ])
        sendEvent([
            "type": "response.create",
            "response": [
                "instructions": "A profile draft was saved. Continue the interview naturally and update the profile again after the next meaningful answer."
            ]
        ])
    }

    private func sendEvent(_ event: [String: Any?]) {
        let compacted = compact(event)
        guard let data = try? JSONSerialization.data(withJSONObject: compacted) else { return }
        let buffer = LKRTCDataBuffer(data: data, isBinary: false)
        dataChannel?.sendData(buffer)
        log("send: \((compacted as? [String: Any])?["type"] as? String ?? "unknown")")
    }

    private func compact(_ value: Any?) -> Any {
        if let dictionary = value as? [String: Any?] {
            return dictionary.reduce(into: [String: Any]()) { result, element in
                if let elementValue = element.value {
                    result[element.key] = compact(elementValue)
                } else {
                    result[element.key] = NSNull()
                }
            }
        }
        if let array = value as? [Any?] {
            return array.map { compact($0) }
        }
        return value ?? NSNull()
    }

    private func publish(_ phase: RealtimeVoicePhase, message: String?, transcript: String?, didPersistProfile: Bool = false) {
        DispatchQueue.main.async {
            self.onUpdate?(RealtimeVoiceUpdate(phase: phase, message: message, transcript: transcript, didPersistProfile: didPersistProfile))
        }
    }

    private func stoppedMessage() -> String {
        functionCallLock.lock()
        let submitted = didSubmitProfilePlacement
        functionCallLock.unlock()
        if submitted {
            return "Profile placement is being saved."
        }
        if userTurnCount == 0 && conversationTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No conversation captured yet. Start again and say a little about how you connect."
        }
        return "Not enough conversation yet to create a full profile. Keep talking so the AI can place you."
    }

    private func appendTranscript(_ speaker: String, _ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !conversationTranscript.isEmpty {
            conversationTranscript += "\n"
        }
        conversationTranscript += "\(speaker): \(trimmed)"
        publish(.streaming, message: nil, transcript: conversationTranscript)
    }

    var interviewTranscript: String {
        conversationTranscript
    }
}

// MARK: - LKRTCPeerConnectionDelegate

extension RealtimeVoiceClient: LKRTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCIceConnectionState) {
        log("ICE state: \(stateChanged)")
        if stateChanged == .connected {
            publish(.streaming, message: "Listening — say hello!", transcript: nil)
        } else if stateChanged == .disconnected {
            if !isClosing {
                log("ICE disconnected — attempting reconnect")
                publish(.connecting, message: "Reconnecting…", transcript: nil)
                attemptReconnect()
            }
        } else if stateChanged == .failed {
            if !isClosing {
                log("ICE failed")
                publish(.failed, message: "Voice connection lost.", transcript: nil)
            }
        }
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {
        log("remote stream added")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {
        log("data channel opened: \(dataChannel.label)")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {
        log("negotiation needed")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {
        log("ICE gathering: \(newState)")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {
        log("signaling state: \(stateChanged)")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd receiver: LKRTCRtpReceiver) {
        log("rtp receiver added")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove receiver: LKRTCRtpReceiver) {
        log("rtp receiver removed")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {
        log("remote stream removed")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        log("ICE candidate generated")
    }

    func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {
        log("ICE candidates removed")
    }
}

// MARK: - LKRTCDataChannelDelegate

extension RealtimeVoiceClient: LKRTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: LKRTCDataChannel) {
        log("data channel state: \(dataChannel.readyState)")
        if dataChannel.readyState == .open {
            startHeartbeat()
            // Send response.create to trigger AI greeting
            sendEvent(["type": "response.create"])
            log("data channel open — sent response.create")
        } else {
            stopHeartbeat()
        }
    }

    func dataChannel(_ dataChannel: LKRTCDataChannel, didReceiveMessageWith buffer: LKRTCDataBuffer) {
        guard let messageText = String(data: buffer.data, encoding: .utf8) else { return }
        handleEvent(messageText)
    }
}

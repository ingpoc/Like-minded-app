import AVFoundation
import Foundation
import LiveKitWebRTC

enum RealtimeVoicePhase: String {
    case idle = "Ready"
    case connecting = "Opening"
    case streaming = "Listening"
    case stopping = "Placing"
    case stopped = "Captured"
    case failed = "Voice issue"
}

struct RealtimeVoiceUpdate {
    let phase: RealtimeVoicePhase
    let message: String?
    let transcript: String?
}

final class RealtimeVoiceClient: NSObject {
    private var onUpdate: ((RealtimeVoiceUpdate) -> Void)?
    private var isStreaming = false
    private var isClosing = false

    private var peerConnection: LKRTCPeerConnection?
    private var dataChannel: LKRTCDataChannel?
    private var audioTrack: LKRTCAudioTrack?
    private var voiceSession: RealtimeSessionEnvelope?
    private var currentModel: String = "gpt-realtime-1.5"
    private var currentVoice: String = "marin"

    private var transcriptBuffer = ""

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
        onUpdate: @escaping (RealtimeVoiceUpdate) -> Void
    ) async throws {
        self.onUpdate = onUpdate
        self.currentModel = model
        self.currentVoice = voice
        isClosing = false
        transcriptBuffer = ""
        reconnectAttempts = 0
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
        let answerSdp = try await exchangeSDPViaServer(pc.localDescription?.sdp ?? sdpOffer)
        log("start: received SDP answer from server")

        // Set remote description
        let answer = LKRTCSessionDescription(type: .answer, sdp: answerSdp)
        try await setRemoteDescription(peer: pc, description: answer)
        log("start: remote description set")

        isStreaming = true
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
        publish(.stopped, message: "Interview complete. Creating your profile.", transcript: nil)
    }

    func disconnect() {
        isClosing = true
        teardown()
        isStreaming = false
        publish(.stopped, message: "Voice session closed.", transcript: nil)
    }

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 3
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
        guard reconnectAttempts < maxReconnectAttempts else {
            log("ICE reconnect: max attempts reached")
            publish(.failed, message: "Voice connection lost.", transcript: nil)
            return
        }

        reconnectAttempts += 1
        log("ICE reconnect: attempt \(reconnectAttempts)/\(maxReconnectAttempts)")

        Task { [weak self] in
            guard let self else { return }
            do {
                // Tear down existing connection locally
                self.dataChannel?.close()
                self.dataChannel = nil
                self.peerConnection?.close()
                self.peerConnection = nil
                self.audioTrack = nil

                // Re-create peer connection and audio track
                let config = LKRTCConfiguration()
                config.iceServers = []
                config.sdpSemantics = .unifiedPlan
                let constraints = LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
                guard let pc = self.factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
                    throw NSError(domain: "LikemindedRealtimeVoice", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to create RTCPeerConnection."
                    ])
                }
                self.peerConnection = pc

                let audioConstraints = LKRTCMediaConstraints(
                    mandatoryConstraints: [
                        "googEchoCancellation": "true",
                        "googAutoGainControl": "true",
                        "googNoiseSuppression": "true"
                    ],
                    optionalConstraints: nil
                )
                let audioSource = self.factory.audioSource(with: audioConstraints)
                let track = self.factory.audioTrack(with: audioSource, trackId: "audio0")
                self.audioTrack = track
                pc.add(track, streamIds: ["audio"])

                let dcConfig = LKRTCDataChannelConfiguration()
                dcConfig.isOrdered = true
                guard let dc = pc.dataChannel(forLabel: "oai-events", configuration: dcConfig) else {
                    throw NSError(domain: "LikemindedRealtimeVoice", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to create data channel."
                    ])
                }
                self.dataChannel = dc

                // Re-negotiate
                let offerConstraints = LKRTCMediaConstraints(
                    mandatoryConstraints: ["OfferToReceiveAudio": "true"],
                    optionalConstraints: nil
                )
                let sdp = try await self.createOffer(peer: pc, constraints: offerConstraints)
                try await self.setLocalDescription(peer: pc, sdp: sdp)
                let answerSdp = try await self.exchangeSDPViaServer(pc.localDescription?.sdp ?? sdp.sdp)
                let answer = LKRTCSessionDescription(type: .answer, sdp: answerSdp)
                try await self.setRemoteDescription(peer: pc, description: answer)

                self.reconnectAttempts = 0
                self.isStreaming = true
                self.log("ICE reconnect: successful")
            } catch {
                self.log("ICE reconnect failed: \(error.localizedDescription)")
                self.publish(.failed, message: "Voice connection lost.", transcript: nil)
            }
        }
    }

    private func teardown() {
        stopHeartbeat()
        dataChannel?.close()
        dataChannel = nil
        peerConnection?.close()
        peerConnection = nil
        audioTrack = nil
        audioEngine.stop()
        audioPlayerNode?.stop()
    }

    // MARK: - SDP Exchange

    private func exchangeSDPViaServer(_ sdp: String) async throws -> String {
        let url = URL(string: "http://127.0.0.1:8787/v1/realtime/calls")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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
        case "response.output_audio_transcript.delta", "response.output_text.delta":
            let delta = object["delta"] as? String ?? ""
            transcriptBuffer += delta
            publish(.streaming, message: nil, transcript: transcriptBuffer)
        case "response.output_audio_transcript.done", "response.output_text.done":
            let fullText = object["text"] as? String ?? object["transcript"] as? String ?? transcriptBuffer
            transcriptBuffer = fullText
            publish(.streaming, message: nil, transcript: fullText)
        case "response.output_audio.delta":
            if let delta = object["delta"] as? String {
                log("recv audio delta: \(delta.count) bytes")
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
        case "error":
            let errorObj = object["error"] as? [String: Any]
            let errorMsg = errorObj?["message"] as? String ?? "Realtime session error."
            log("server error: \(errorMsg)")
            publish(.failed, message: errorMsg, transcript: nil)
        default:
            break
        }
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

    private func publish(_ phase: RealtimeVoicePhase, message: String?, transcript: String?) {
        DispatchQueue.main.async {
            self.onUpdate?(RealtimeVoiceUpdate(phase: phase, message: message, transcript: transcript))
        }
    }

    var interviewTranscript: String {
        transcriptBuffer
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

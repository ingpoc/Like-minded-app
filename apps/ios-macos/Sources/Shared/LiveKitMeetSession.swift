import Foundation
import LiveKit

@MainActor
final class LiveKitMeetSession: ObservableObject {
    let room = Room()

    @Published private(set) var isConnected = false
    @Published private(set) var isPrototypeFallback = false
    @Published var isMuted = false
    @Published var statusMessage = "Connecting"
    @Published var errorMessage: String?

    func connect(url: String, token: String) async {
        statusMessage = "Connecting"
        isPrototypeFallback = false
        guard !url.isEmpty, !token.isEmpty else {
            isConnected = false
            isPrototypeFallback = true
            statusMessage = "Preview mode"
            return
        }
        do {
            try await room.connect(url: url, token: token)
            try await room.localParticipant.setCamera(enabled: true)
            try await room.localParticipant.setMicrophone(enabled: true)
            isConnected = true
            statusMessage = "Live"
        } catch {
            isConnected = false
            isPrototypeFallback = true
            errorMessage = error.localizedDescription
            statusMessage = "Preview mode"
        }
    }

    func setMuted(_ muted: Bool) async {
        isMuted = muted
        guard isConnected, !isPrototypeFallback else { return }
        try? await room.localParticipant.setMicrophone(enabled: !muted)
    }

    func disconnect() async {
        guard isConnected, !isPrototypeFallback else {
            isConnected = false
            return
        }
        await room.disconnect()
        isConnected = false
        statusMessage = "Disconnected"
    }
}

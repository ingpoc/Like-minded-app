import LiveKit
import SwiftUI

struct MacGroupVideoCallView: View {
    @ObservedObject var appState: MacAppState
    let meeting: Meeting
    var navigate: ((MacPrototypeScreen) -> Void)?

    @StateObject private var room = Room()
    @State private var connectionError: String?
    @State private var isCallMuted = false
    @State private var callSidePanel = "Participants"
    @State private var isLeaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.title)
                        .font(MacType.section)
                    Text(LikemindedDate.full(meeting.scheduledAt))
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
                Spacer()
                callStatus(
                    icon: "video.fill",
                    title: connectionStatusTitle,
                    detail: connectionStatusDetail
                )
                callStatus(
                    icon: "person.2",
                    title: "\(participantCount) participants",
                    detail: nil
                )
            }

            if let connectionError {
                Text(connectionError)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.clay)
                    .padding(.horizontal, 4)
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 14) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        ForEach(tileNames.prefix(4), id: \.self) { name in
                            callTile(name)
                        }
                    }
                    callControls
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 16) {
                    MacPanel {
                        HStack(spacing: 12) {
                            ForEach(["Participants", "Agenda"], id: \.self) { panel in
                                Button(panel) { callSidePanel = panel }
                                    .font(MacType.button)
                                    .foregroundStyle(callSidePanel == panel ? MacPalette.accent : MacPalette.muted)
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(panel)
                                    .accessibilityValue(callSidePanel == panel ? "Selected" : "Not selected")
                            }
                        }
                        Divider()
                        if callSidePanel == "Participants" {
                            ForEach(tileNames, id: \.self) { participant in
                                HStack {
                                    Text(participant)
                                    if participant == meeting.hostName {
                                        MacPill(text: "Host", isSelected: true)
                                    }
                                    Spacer()
                                    Image(systemName: isCallMuted && participant == localParticipantName ? "mic.slash.fill" : "mic.fill")
                                        .foregroundStyle(MacPalette.accent)
                                }
                                .font(MacType.body)
                                .accessibilityLabel("\(participant) microphone \(isCallMuted && participant == localParticipantName ? "off" : "on")")
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Opening check-in")
                                Text("Share one useful signal")
                                Text("Pick one follow-up")
                            }
                            .font(MacType.body)
                        }
                    }
                    MacPanel {
                        Label("A safe, respectful space", systemImage: "shield.checkered")
                            .font(MacType.button)
                        Text("Be present, be kind, and listen with an open heart.")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                    }
                }
                .frame(width: 330)
            }
        }
        .task {
            await connectToRoom()
        }
        .onDisappear {
            Task { await disconnectFromRoom() }
        }
    }

    private var localParticipantName: String {
        appState.profile?.basicInfo?.name ?? "You"
    }

    private var connectionStatusTitle: String {
        switch room.connectionState {
        case .connected:
            return "Live"
        case .connecting, .reconnecting:
            return "Connecting"
        case .disconnected:
            return connectionError == nil ? "Preparing room" : "Offline"
        @unknown default:
            return "Connecting"
        }
    }

    private var connectionStatusDetail: String? {
        switch room.connectionState {
        case .connected:
            return "Camera and microphone active"
        case .connecting, .reconnecting:
            return "Joining LiveKit room"
        case .disconnected:
            return connectionError == nil ? "Requesting join token" : "LiveKit server unavailable"
        @unknown default:
            return nil
        }
    }

    private var participantCount: Int {
        max(meeting.groupSize, room.remoteParticipants.count + 1)
    }

    private var tileNames: [String] {
        if room.connectionState == .connected {
            var names = [localParticipantName]
            names.append(contentsOf: room.remoteParticipants.values.map { String(describing: $0.identity) })
            while names.count < max(4, meeting.groupSize) {
                names.append("Seat \(names.count + 1)")
            }
            return names
        }
        var names = [meeting.hostName, localParticipantName]
        names.append(contentsOf: appState.soulmateMatches.map(\.name))
        let unique = NSOrderedSet(array: names).compactMap { $0 as? String }
        return Array(unique.prefix(8))
    }

    private func connectToRoom() async {
        connectionError = nil
        appState.activeCallMeetingId = meeting.id
        do {
            let token = try await appState.joinMeeting(id: meeting.id)
            try await room.connect(url: token.url, token: token.token)
            try await room.localParticipant.setCamera(enabled: true)
            try await room.localParticipant.setMicrophone(enabled: true)
            isCallMuted = false
        } catch {
            connectionError = error.localizedDescription
            appState.meetingError = error.localizedDescription
        }
    }

    private func disconnectFromRoom() async {
        await room.disconnect()
    }

    private func callTile(_ name: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [MacPalette.sage.opacity(0.9), MacPalette.accent.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(String(name.prefix(1)))
                .font(.system(size: 72, weight: .semibold, design: .serif))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Label(name, systemImage: "cellularbars")
                .font(MacType.button)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .foregroundStyle(.white)
                .padding(12)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityLabel("\(name) video tile")
    }

    private var callControls: some View {
        HStack(spacing: 22) {
            Button("Chat") { navigate?(.messages) }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open call chat")
            Button("Participants") { callSidePanel = "Participants" }
                .buttonStyle(.bordered)
                .accessibilityLabel("Show call participants")
            Button {
                Task {
                    isCallMuted.toggle()
                    try? await room.localParticipant.setMicrophone(enabled: !isCallMuted)
                }
            } label: {
                Label(isCallMuted ? "Unmute mic" : "Mute mic", systemImage: isCallMuted ? "mic.slash.fill" : "mic.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: 56, height: 56)
                    .background(MacPalette.accent, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCallMuted ? "Unmute microphone" : "Mute microphone")
            .accessibilityValue(isCallMuted ? "Muted" : "Unmuted")
            Label(room.connectionState == .connected ? "Good connection" : "Connecting", systemImage: "cellularbars")
                .font(MacType.button)
                .foregroundStyle(MacPalette.ink)
            Button("Leave") {
                Task {
                    guard !isLeaving else { return }
                    isLeaving = true
                    await disconnectFromRoom()
                    navigate?(.meetOverview)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel("Leave meetup")
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private func callStatus(icon: String, title: String, detail: String?) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MacType.button)
                if let detail {
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(MacPalette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }
}

import LiveKit
import SwiftUI

struct MeetView: View {
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Meet", subtitle: "When you meet.") {
                RSVPCard(rsvps: appState.meetingRsvps) { kind, available in
                    Task { await appState.updateMeetingRSVP(kind: kind, available: available) }
                }

                if appState.isLoadingMeetings {
                    ProgressView("Loading meets")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)
                }

                if let error = appState.meetingError {
                    Text(error)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.amber)
                }

                if appState.upcomingMeetings.isEmpty {
                    PreMeetTeaserCard(
                        title: "Weekend groups form Friday",
                        detail: "RSVP now. We will show group composition and host details after scheduling.",
                        tone: 0
                    )
                } else {
                    ForEach(appState.upcomingMeetings.prefix(2)) { meeting in
                        PreMeetTeaserCard(
                            title: meeting.kind == "circle" ? "Your Sunday meet" : "Your Saturday meet",
                            detail: "\(meeting.compositionSummary)\nHost: \(meeting.hostName).",
                            tone: meeting.kind == "circle" ? 2 : 0
                        )
                    }
                }

                FeatureCard(title: "Upcoming meets", eyebrow: "Live") {
                    if appState.upcomingMeetings.isEmpty {
                        Text("No scheduled meets yet.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(appState.upcomingMeetings) { meeting in
                                UpcomingMeetCard(meeting: meeting)
                            }
                        }
                    }
                }

                FeatureCard(title: "Past meets", eyebrow: "History") {
                    if appState.pastMeetings.isEmpty {
                        Text("Past meets will appear here.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.pastMeetings) { meeting in
                                NavigationLink {
                                    PastMeetDetailView(meeting: meeting)
                                } label: {
                                    PastMeetRow(meeting: meeting)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                    .frame(width: 42, height: 42)
                    .background(PrototypePalette.surface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 8)
                    .padding(.top, 42)
                    .padding(.trailing, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await appState.fetchMeetings()
            }
        }
    }
}

private struct RSVPCard: View {
    let rsvps: MeetingRsvps
    let onChange: (String, Bool) -> Void
    @State private var saturdayAvailable = false
    @State private var sundayAvailable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Available this weekend?")
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(PrototypePalette.ink)

            RSVPRow(
                icon: "calendar",
                tint: PrototypePalette.success,
                title: "Saturday",
                subtitle: "Community meetup",
                isAvailable: $saturdayAvailable
            )
            .onChange(of: saturdayAvailable) { _, value in onChange("community", value) }

            Divider().overlay(PrototypePalette.rule)

            RSVPRow(
                icon: "calendar.badge.clock",
                tint: PrototypePalette.amber,
                title: "Sunday",
                subtitle: "Circle meetup",
                isAvailable: $sundayAvailable
            )
            .onChange(of: sundayAvailable) { _, value in onChange("circle", value) }

            Divider().overlay(PrototypePalette.rule)

            Label("RSVP closes Friday midnight.", systemImage: "timer")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(18)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
        .sensoryFeedback(.success, trigger: saturdayAvailable)
        .sensoryFeedback(.success, trigger: sundayAvailable)
        .onAppear {
            saturdayAvailable = rsvps.community
            sundayAvailable = rsvps.circle
        }
        .onChange(of: rsvps) { _, next in
            saturdayAvailable = next.community
            sundayAvailable = next.circle
        }
    }
}

private struct RSVPRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isAvailable: Bool
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.ink)
                Text(subtitle)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    isAvailable.toggle()
                }
            } label: {
                ZStack(alignment: isAvailable ? .trailing : .leading) {
                    Capsule(style: .continuous)
                        .fill(PrototypePalette.rule.opacity(0.65))
                        .frame(width: 116, height: 34)

                    Capsule(style: .continuous)
                        .fill(isAvailable ? PrototypePalette.accent : PrototypePalette.muted)
                        .frame(width: 62, height: 30)
                        .matchedGeometryEffect(id: "rsvp-pill", in: pillNamespace)
                        .padding(.horizontal, 2)

                    HStack {
                        Text("Not")
                        Spacer()
                        Text("Available")
                    }
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(isAvailable ? PrototypePalette.ink : PrototypePalette.subink)
                    .padding(.horizontal, 10)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct PreMeetTeaserCard: View {
    let title: String
    let detail: String
    let tone: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(tone == 0 ? PrototypePalette.accentSoft : PrototypePalette.amber.opacity(0.20))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: tone == 0 ? "person.3.sequence.fill" : "circle.grid.2x2.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PrototypePalette.accent)
                )

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text(detail)
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

private struct UpcomingMeetCard: View {
    @EnvironmentObject private var appState: PrototypeAppState
    let meeting: Meeting

    private var canJoin: Bool {
        Date() >= (ISO8601DateFormatter().date(from: meeting.scheduledAt) ?? .distantFuture)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(meeting.title)
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)
                Spacer()
                Text(countdownText)
                    .font(PrototypeTypography.metadata.monospacedDigit())
                    .foregroundStyle(PrototypePalette.accent)
            }

            Text("\(formattedDate) • Host \(meeting.hostName) • \(meeting.groupSize) people")
                .font(PrototypeTypography.body)
                .foregroundStyle(PrototypePalette.subink)

            NavigationLink {
                GroupVideoCallView(meeting: meeting)
            } label: {
                Label(canJoin ? "Join live room" : "Join unlocks at meetup time", systemImage: "video.fill")
                    .font(PrototypeTypography.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canJoin ? PrototypePalette.accent : PrototypePalette.rule)
                    .foregroundStyle(canJoin ? .white : PrototypePalette.subink)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scaleEffect(canJoin ? 1.01 : 1.0)
                    .animation(canJoin ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: canJoin)
            }
            .disabled(!canJoin)
        }
        .padding(16)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }

    private var countdownText: String {
        guard let date = ISO8601DateFormatter().date(from: meeting.scheduledAt) else { return "Soon" }
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        return "\(seconds / 86_400)d \((seconds % 86_400) / 3_600)h away"
    }

    private var formattedDate: String {
        guard let date = ISO8601DateFormatter().date(from: meeting.scheduledAt) else { return meeting.scheduledAt }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct PastMeetRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PrototypePalette.success)
                .frame(width: 38, height: 38)
                .background(PrototypePalette.success.opacity(0.13))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text("\(meeting.scheduledAt.prefix(10)) • Host \(meeting.hostName)")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.muted)
        }
        .padding(14)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

private struct PastMeetDetailView: View {
    let meeting: Meeting

    var body: some View {
        ScreenContainer(title: "Past meet", subtitle: meeting.title) {
            FeatureCard(title: "Meet info", eyebrow: "No transcript") {
                Text("\(meeting.compositionSummary)\nHost: \(meeting.hostName)\nDate: \(meeting.scheduledAt.prefix(10))")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
            }
        }
    }
}

struct GroupVideoCallView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @StateObject private var room = Room()
    @State private var error: String?
    @State private var isMuted = false
    let meeting: Meeting

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text(room.connectionState == .connected ? "● Live" : "Connecting")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(room.connectionState == .connected ? PrototypePalette.success : PrototypePalette.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule(style: .continuous))

                    Text("\(max(1, room.remoteParticipants.count + 1)) participants")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white)

                    Spacer()
                    Image(systemName: "shield.lefthalf.filled")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.top, 12)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    VideoTile(name: "You", index: 0)
                    ForEach(Array(room.remoteParticipants.values.enumerated()), id: \.element.identity) { index, participant in
                        VideoTile(name: String(describing: participant.identity), index: index + 1)
                    }
                    ForEach(room.remoteParticipants.count + 1..<max(meeting.groupSize, 1), id: \.self) { index in
                        VideoTile(name: "Seat \(index + 1)", index: index)
                    }
                }
                .padding(.horizontal, 10)

                if let error {
                    Text(error)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.amber)
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 8)

                HStack(spacing: 42) {
                    Button {
                        Task {
                            isMuted.toggle()
                            try? await room.localParticipant.setMicrophone(enabled: !isMuted)
                        }
                    } label: {
                        CallControl(icon: isMuted ? "mic.slash.fill" : "mic.fill", title: isMuted ? "Muted" : "Mute")
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await room.disconnect() }
                    } label: {
                        CallControl(icon: "phone.down.fill", title: "Leave", isDestructive: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(.regularMaterial.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.bottom, 22)
            }
        }
        .task {
            do {
                let token = try await appState.joinMeeting(id: meeting.id)
                try await room.connect(url: token.url, token: token.token)
                try await room.localParticipant.setCamera(enabled: true)
                try await room.localParticipant.setMicrophone(enabled: true)
            } catch {
                self.error = error.localizedDescription
            }
        }
        .onDisappear {
            Task { await room.disconnect() }
        }
    }
}

private struct VideoTile: View {
    let name: String
    let index: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(index % 3 == 0 ? Color.white.opacity(0.16) : Color.white.opacity(0.09))
                .aspectRatio(0.78, contentMode: .fit)
                .overlay {
                    Circle()
                        .fill(PrototypePalette.accent.opacity(0.82))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Text(String(name.prefix(1)))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )
                }

            Text(name)
                .font(PrototypeTypography.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.30))
                .clipShape(Capsule(style: .continuous))
                .padding(8)
        }
    }
}

private struct CallControl: View {
    let icon: String
    let title: String
    var isDestructive = false

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(isDestructive ? Color.red : Color.white.opacity(0.16))
                .clipShape(Circle())

            Text(title)
                .font(PrototypeTypography.caption)
                .foregroundStyle(.white.opacity(0.86))
        }
    }
}

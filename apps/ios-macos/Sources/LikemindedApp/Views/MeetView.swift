import LiveKit
import SwiftUI

#if DEBUG
private enum MeetValidationFlags {
    static var allowsEarlyJoin: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--likeminded-dev-meet-join") || args.contains("--likeminded-start-video-call")
    }

    static var opensVideoCallDirectly: Bool {
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-video-call")
    }

    static var opensPastMeetDetail: Bool {
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-past-meet-detail")
    }
}
#else
private enum MeetValidationFlags {
    static var allowsEarlyJoin: Bool { false }
    static var opensVideoCallDirectly: Bool { false }
    static var opensPastMeetDetail: Bool { false }
}
#endif

private enum MeetRoute: Hashable {
    case messages
    case chat(SoulmateMatch)
}

struct MeetView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    // Notifications deep-link is owned by RootView (--likeminded-start-notifications).
    // Do not auto-open the Meet sheet from that flag or Done cannot reach the Meet tab.
    @State private var showingNotifications = false
    @State private var showVideoCall = MeetValidationFlags.opensVideoCallDirectly
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScreenContainer(title: "Meet", subtitle: "When you meet.", trailingHeader: { meetTitleActions }) {
                RSVPCard(rsvps: appState.meetingRsvps) { kind, available in
                    Task { await appState.updateMeetingRSVP(kind: kind, available: available) }
                }

                if let heroMeeting = appState.upcomingMeetings.first {
                    MeetHeroJoinCard(meeting: heroMeeting)
                } else if !appState.isLoadingMeetings {
                    MeetEmptyHeroCard()
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

                if !appState.pastMeetings.isEmpty {
                    FeatureCard(title: "Past meets", eyebrow: "History") {
                        VStack(spacing: 10) {
                            ForEach(appState.pastMeetings) { meeting in
                                NavigationLink(value: meeting) {
                                    PastMeetRow(meeting: meeting)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Meeting.self) { meeting in
                PastMeetDetailView(meeting: meeting) {
                    // Full reset — removeLast alone can no-op if path desyncs with the pushed destination.
                    appState.pendingPastMeetDetail = false
                    navigationPath = NavigationPath()
                }
                .environmentObject(appState)
                .accessibilityIdentifier("past-meet-detail")
            }
            .navigationDestination(for: MeetRoute.self) { route in
                switch route {
                case .messages:
                    ConversationListView(matches: appState.soulmateMatches)
                        .environmentObject(appState)
                case .chat(let match):
                    ChatView(match: match)
                        .environmentObject(appState)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNotifications) {
                NotificationsView()
                    .environmentObject(appState)
            }
            .task {
                await appState.fetchMeetings()
                await appState.fetchSoulmateStatus()
                openPendingPastMeetDetailIfNeeded()
                if MeetValidationFlags.opensVideoCallDirectly, appState.upcomingMeetings.first != nil {
                    showVideoCall = true
                }
            }
            .onChange(of: appState.pendingPastMeetDetail) { _, _ in
                openPendingPastMeetDetailIfNeeded()
            }
            .onChange(of: appState.pastMeetings.count) { _, _ in
                openPendingPastMeetDetailIfNeeded()
            }
            .fullScreenCover(isPresented: $showVideoCall) {
                if let meeting = appState.upcomingMeetings.first {
                    GroupVideoCallView(meeting: meeting)
                        .environmentObject(appState)
                }
            }
        }
    }

    private var meetTitleActions: some View {
        HStack(spacing: 10) {
            Button {
                navigationPath.append(MeetRoute.messages)
            } label: {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                    .frame(width: 42, height: 42)
                    .background(PrototypePalette.surface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Messages")
            .accessibilityIdentifier("title-messages")

            Button {
                showingNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)
                        .frame(width: 42, height: 42)
                        .background(PrototypePalette.surface)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.06), radius: 14, y: 8)

                    if !appState.notifications.isEmpty {
                        Circle()
                            .fill(PrototypePalette.coral)
                            .frame(width: 9, height: 9)
                            .offset(x: -4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Notifications")
        }
        .accessibilitySortPriority(100)
    }

    private func openPendingPastMeetDetailIfNeeded() {
        guard appState.pendingPastMeetDetail,
              navigationPath.isEmpty,
              let meeting = appState.pastMeetings.first else { return }
        navigationPath.append(meeting)
        appState.pendingPastMeetDetail = false
    }
}

private struct MeetEmptyHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.75))
            Text("No upcoming meetups")
                .font(PrototypeTypography.cardTitle)
                .foregroundStyle(.white)
            Text("RSVP for this weekend to get scheduled.")
                .font(PrototypeTypography.body)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
}

private struct MeetHeroJoinCard: View {
    let meeting: Meeting

    private var canJoin: Bool {
        if MeetValidationFlags.allowsEarlyJoin { return true }
        return Date() >= (LikemindedDate.parse(meeting.scheduledAt) ?? .distantFuture)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upcoming meetup")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white.opacity(0.85))
                    Text(LikemindedDate.meetHeader(meeting.scheduledAt))
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer(minLength: 12)
                Text(LikemindedDate.countdownUntil(meeting.scheduledAt))
                    .font(PrototypeTypography.metadata.monospacedDigit())
                    .foregroundStyle(PrototypePalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.95))
                    .clipShape(Capsule(style: .continuous))
                    .contentTransition(.numericText())
            }

            Text(meeting.title)
                .font(PrototypeTypography.cardTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Host: \(meeting.hostName)", systemImage: "person.circle")
                Label("\(meeting.groupSize) participants", systemImage: "person.2")
                if !meeting.compositionSummary.isEmpty {
                    Label(meeting.compositionSummary, systemImage: "person.3")
                }
            }
            .font(PrototypeTypography.caption)
            .foregroundStyle(.white.opacity(0.88))

            NavigationLink {
                GroupVideoCallView(meeting: meeting)
            } label: {
                Label(canJoin ? "Join video call" : "Join unlocks at meetup time", systemImage: "video.fill")
                    .font(PrototypeTypography.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(canJoin ? 0.92 : 0.55))
                    .foregroundStyle(PrototypePalette.accent)
                    .clipShape(Capsule(style: .continuous))
            }
            .disabled(!canJoin)
            .accessibilityLabel(canJoin ? "Join video call" : "Join unlocks at meetup time")
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [PrototypePalette.accent, PrototypePalette.accentDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
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
                isAvailable: $saturdayAvailable,
                availableLabel: "Saturday Available",
                unavailableLabel: "Saturday unavailable"
            )
            .onChange(of: saturdayAvailable) { _, value in onChange("community", value) }

            Divider().overlay(PrototypePalette.rule)

            RSVPRow(
                icon: "calendar.badge.clock",
                tint: PrototypePalette.amber,
                title: "Sunday",
                subtitle: "Circle meetup",
                isAvailable: $sundayAvailable,
                availableLabel: "Sunday Available",
                unavailableLabel: "Sunday unavailable"
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isAvailable: Bool
    let availableLabel: String
    let unavailableLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            identity
            choices
        }
    }

    private var identity: some View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var choices: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 4) {
                    availableChoice
                    unavailableChoice
                }
            } else {
                HStack(spacing: 0) {
                    availableChoice
                    unavailableChoice
                }
            }
        }
        .padding(3)
        .background(PrototypePalette.rule.opacity(0.55))
        .clipShape(
            RoundedRectangle(
                cornerRadius: dynamicTypeSize.isAccessibilitySize ? 16 : 999,
                style: .continuous
            )
        )
    }

    private var availableChoice: some View {
        RSVPChoice(title: "Available", accessibilityLabel: availableLabel, isSelected: isAvailable) {
            withAnimation(reduceMotion ? nil : .interactive) {
                isAvailable = true
            }
        }
    }

    private var unavailableChoice: some View {
        RSVPChoice(title: "Unavailable", accessibilityLabel: unavailableLabel, isSelected: !isAvailable) {
            withAnimation(reduceMotion ? nil : .interactive) {
                isAvailable = false
            }
        }
    }
}

private struct RSVPChoice: View {
    let title: String
    let accessibilityLabel: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PrototypeTypography.caption)
                .foregroundStyle(isSelected ? .white : PrototypePalette.subink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? PrototypePalette.accent : .clear)
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
                Text("\(LikemindedDate.short(meeting.scheduledAt)) • Host \(meeting.hostName)")
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("past-row")
        .accessibilityLabel("Past meet row")
        .accessibilityValue("\(meeting.title), \(LikemindedDate.short(meeting.scheduledAt))")
    }
}

struct PastMeetDetailView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    let meeting: Meeting
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showingSoulmateSelection = false
    @State private var messageMatch: SoulmateMatch?
    @State private var reflectionNote = ""
    @State private var noteStatus: String?
    @State private var isSavingNote = false

    var body: some View {
        ScreenContainer(title: "Meet recap", subtitle: "Great meeting!") {
            VStack(alignment: .leading, spacing: 16) {
                Text("You attended \(meeting.title) on \(formattedDate).")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
            .background(PrototypePalette.roomGradient(meeting.kind == "circle" ? 0 : 2))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            FeatureCard(title: "Meeting insights", eyebrow: "Summary") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    RecapMetricCell(value: "\(meeting.groupSize)", label: "People attended")
                    RecapMetricCell(value: "\(appState.soulmateMatches.count)", label: "Mutual matches")
                    RecapMetricCell(value: LikemindedDate.short(meeting.scheduledAt), label: "Meet date")
                    RecapMetricCell(value: meeting.kind.capitalized, label: "Room type")
                }

            }

            FeatureCard(title: "Your notes", eyebrow: "Private") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add a private note about how this meet felt.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)

                    TextField("Add a private note...", text: $reflectionNote, axis: .vertical)
                        .font(PrototypeTypography.caption)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .accessibilityLabel("Reflection note field")

                    HStack {
                        Button {
                            Task { await saveNote() }
                        } label: {
                            Label(isSavingNote ? "Saving" : "Save note", systemImage: "checkmark.circle.fill")
                                .font(PrototypeTypography.button)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PrototypePalette.accent)
                        .disabled(isSavingNote)
                        .accessibilityLabel("Save note")

                        if let noteStatus {
                            Text(noteStatus)
                                .font(PrototypeTypography.metadata)
                                .foregroundStyle(PrototypePalette.subink)
                        }
                    }
                }
            }

            FeatureCard(title: "People you connected with", eyebrow: "Connections") {
                if appState.soulmateMatches.isEmpty {
                    Text("No mutual matches from seeded meetups yet.")
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.subink)
                } else {
                    VStack(spacing: 10) {
                        ForEach(appState.soulmateMatches) { match in
                            RecapConnectionRow(match: match) {
                                messageMatch = match
                            }
                        }
                    }
                }
            }

            if appState.soulmateEnabled {
                FeatureCard(title: "Did you connect?", eyebrow: "Soulmate") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mutual selection only. They won't see your choice until they choose you too.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)

                        Button {
                            showingSoulmateSelection = true
                        } label: {
                            PrimaryActionButton(title: "Select connections", systemImage: "heart")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Select connections")
                        .accessibilityIdentifier("recap-select-connections")
                    }
                }
            }
        }
        .navigationTitle("Recap")
        .navigationBarTitleDisplayMode(.inline)
        // Reserve explicit space for the custom action-backed control instead of overlaying content.
        .toolbar(.hidden, for: .navigationBar)
        .prototypeBackNavigation(label: "Back to meet") {
            appState.pendingPastMeetDetail = false
            if let onBack {
                onBack()
            }
            dismiss()
        }
        .sheet(isPresented: $showingSoulmateSelection) {
            SoulmateSelectionDialog(meetingId: meeting.id)
                .environmentObject(appState)
        }
        // Nested NavigationLink under the floating tab bar often no-ops; push via destination instead.
        .navigationDestination(item: $messageMatch) { match in
            ChatView(match: match)
                .environmentObject(appState)
        }
        .task {
            await appState.fetchSoulmateStatus()
        }
        .onAppear {
            reflectionNote = meeting.recapNote ?? ""
        }
    }

    private var formattedDate: String {
        LikemindedDate.full(meeting.scheduledAt)
    }

    private func saveNote() async {
        isSavingNote = true
        await appState.saveMeetingRecapNote(meetingId: meeting.id, note: reflectionNote)
        noteStatus = appState.meetingError == nil ? "Saved" : appState.meetingError
        isSavingNote = false
    }
}

private struct RecapMetricCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(PrototypePalette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecapConnectionRow: View {
    let match: SoulmateMatch
    var onMessage: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PrototypePalette.accentSoft)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(match.name.prefix(1)))
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(match.name)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text(match.meetingDate.map { "Met \(LikemindedDate.short($0))" } ?? "Seeded mutual match")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
            }

            Spacer()

            Button(action: onMessage) {
                Text("Message")
                    .font(PrototypeTypography.metadata.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(PrototypePalette.accent, in: Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Message \(match.name)")
            .accessibilityIdentifier("recap-message-match")
        }
        .padding(12)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

struct GroupVideoCallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: PrototypeAppState
    @StateObject private var liveKitSession = LiveKitMeetSession()
    @State private var showingParticipants = false
    let meeting: Meeting

    private var isLive: Bool {
        liveKitSession.isConnected
    }

    private var participantCount: Int {
        if liveKitSession.isConnected {
            return max(meeting.groupSize, liveKitSession.room.remoteParticipants.count + 1)
        }
        return max(meeting.groupSize, callParticipants.count)
    }

    private var callParticipants: [String] {
        var names = [meeting.hostName]
        if let profileName = appState.basicInfo?.name {
            names.append(profileName)
        }
        names.append(contentsOf: appState.soulmateMatches.map(\.name))
        names.append(contentsOf: ["Priya", "Arjun", "Meera", "Rohan", "Karan", "Neha", "Vikram"])
        return Array(NSOrderedSet(array: names).compactMap { $0 as? String }.prefix(meeting.groupSize))
    }

    var body: some View {
        // Pin mute/leave/participants to the bottom overlay so a tall tile grid
        // (large groupSize) cannot push call controls below the viewport.
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text(isLive ? "● Live" : "Connecting")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(isLive ? PrototypePalette.success : PrototypePalette.amber)
                        .contentTransition(.opacity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule(style: .continuous))

                    Text("\(participantCount) participants")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Spacer()

                    Image(systemName: "shield.lefthalf.filled")
                    Image(systemName: "ellipsis")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.top, 12)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        if liveKitSession.isPrototypeFallback {
                            ForEach(Array(callParticipants.enumerated()), id: \.offset) { index, name in
                                VideoTile(
                                    name: name,
                                    index: index,
                                    isHost: name == meeting.hostName
                                )
                            }
                        } else {
                            VideoTile(name: "You", index: 0)
                            ForEach(Array(liveKitSession.room.remoteParticipants.values.enumerated()), id: \.element.identity) { index, participant in
                                VideoTile(name: String(describing: participant.identity), index: index + 1)
                            }
                            ForEach(liveKitSession.room.remoteParticipants.count + 1..<max(meeting.groupSize, 1), id: \.self) { index in
                                VideoTile(name: "Seat \(index + 1)", index: index)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .accessibilityLabel("Participant tiles grid")
                    .accessibilityValue("\(participantCount) participants")

                    if let error = liveKitSession.errorMessage, liveKitSession.isPrototypeFallback {
                        Text("Live room unavailable: \(error)")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.amber)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 118)
            }

            HStack(spacing: 42) {
                Button {
                    Task { await liveKitSession.setMuted(!liveKitSession.isMuted) }
                } label: {
                    CallControl(icon: liveKitSession.isMuted ? "mic.slash.fill" : "mic.fill", title: liveKitSession.isMuted ? "Muted" : "Mute")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(liveKitSession.isMuted ? "Unmute microphone" : "Mute microphone")

                Button {
                    Task {
                        await liveKitSession.disconnect()
                        dismiss()
                    }
                } label: {
                    CallControl(icon: "phone.down.fill", title: "Leave", isDestructive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Leave meetup")

                Button {
                    showingParticipants = true
                } label: {
                    CallControl(icon: "person.2.fill", title: "Participants")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show participants")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(.regularMaterial.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.bottom, 22)

            VideoTile(name: "You", index: 0, isSelfPreview: true)
                .frame(width: 88, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 2))
                .padding(.trailing, 16)
                .padding(.bottom, 108)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .accessibilityHidden(true)
        }
        .sheet(isPresented: $showingParticipants) {
            NavigationStack {
                List {
                    ForEach(callParticipants, id: \.self) { participant in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(PrototypePalette.accent.opacity(0.82))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(participant.prefix(1)))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                )
                            Text(participant)
                            if participant == meeting.hostName {
                                Text("Host")
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(PrototypePalette.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PrototypePalette.accentSoft)
                                    .clipShape(Capsule(style: .continuous))
                            }
                            Spacer()
                            Image(systemName: "mic.fill")
                                .foregroundStyle(PrototypePalette.accent)
                        }
                    }
                }
                .navigationTitle("Participants")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .task {
            await connectToRoom()
        }
        .onDisappear {
            Task { await liveKitSession.disconnect() }
        }
    }

    private func connectToRoom() async {
        do {
            let token = try await appState.joinMeeting(id: meeting.id)
            await liveKitSession.connect(url: token.url, token: token.token)
        } catch {
            await liveKitSession.connect(url: "", token: "")
            liveKitSession.errorMessage = error.localizedDescription
        }
    }
}

private struct VideoTile: View {
    let name: String
    let index: Int
    var isHost = false
    var isSelfPreview = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PrototypePalette.accent.opacity(index.isMultiple(of: 2) ? 0.72 : 0.55),
                            Color.white.opacity(index.isMultiple(of: 3) ? 0.18 : 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(isSelfPreview ? nil : 0.78, contentMode: .fit)
                .overlay {
                    if !isSelfPreview {
                        Text(String(name.prefix(1)))
                            .font(.system(size: 52, weight: .semibold, design: .serif))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

            if isHost {
                Text("Host")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PrototypePalette.accent)
                    .clipShape(Capsule(style: .continuous))
                    .padding(8)
            }

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Text(name)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(.white)
                    if !isSelfPreview {
                        Image(systemName: "cellularbars")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PrototypePalette.success)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.30))
                .clipShape(Capsule(style: .continuous))
                .padding(8)
            }
        }
        .accessibilityLabel("\(name) video tile")
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

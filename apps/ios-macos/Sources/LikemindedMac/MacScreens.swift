import SwiftUI

struct MacScreenView: View {
    let screen: MacPrototypeScreen
    @ObservedObject var appState: MacAppState
    var navigate: ((MacPrototypeScreen) -> Void)?
    @State private var showSignOutConfirm = false
    @State private var selectedCommunityId: String?
    @State private var selectedRecapMeetingId: String?
    @State private var communitySearch = ""
    @State private var communityFilter = "All"
    @State private var communityDetailTab = "Upcoming"
    @State private var communityDetailStatus: String?
    @State private var memberSearch = ""
    @State private var circleConcernStatus: String?
    @State private var showAllCircles = false
    @State private var recapNote = ""
    @State private var recapNoteStatus: String?
    @State private var isSavingRecapNote = false
    @State private var selectedChatMatchId: String?
    @State private var chatSearch = ""
    @State private var chatFilter = "All"
    @State private var readChatMatchIds: Set<String> = []
    @State private var notificationStatus: String?
    @State private var notificationFilter = "All"
    @State private var activityFilter = "All"
    @State private var readNotificationIds: Set<String> = []
    @State private var selectedSoulmateMatchId: String?
    @State private var soulmateMatchDetail: SoulmateMatchDetail?
    @State private var showAllInterests = false
    @State private var draftProfileName = ""
    @State private var draftProfileCity = ""
    @State private var draftProfileGender: Gender = .preferNotToSay
    @State private var isSavingProfileBasics = false
    @State private var profileBasicsStatus: String?
    @State private var newCommunityName = ""
    @State private var newCommunitySummary = ""
    @State private var newCommunityThemes = ""
    @State private var createCommunityStatus: String?
    @State private var isCreatingCommunity = false
    @State private var eventType = "Meetup"
    @State private var eventName = "Saturday Jazz Listening Session"
    @State private var eventDate = "2026-07-05"
    @State private var eventTime = "19:00"
    @State private var eventLocation = "Blue Tokai Coffee Roasters, Koramangala"
    @State private var eventDetails = "Let's dive into some classic Coltrane and modern jazz. Bring your favorite tracks to share."
    @State private var eventCoverAdded = false
    @State private var eventTagsAdded = false
    @State private var createEventStatus: String?
    @State private var isCreatingEvent = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var isCallMuted = false
    @State private var callSidePanel = "Participants"
    @State private var selectedSettingsSection: SettingsSection = .soulmate

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case account = "Account"
        case privacy = "Privacy & safety"
        case notifications = "Notifications"
        case soulmate = "Soulmate"
        case connectedApps = "Connected apps"
        case appearance = "Appearance"
        case language = "Language"
        case help = "Help & support"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .account: "person.circle"
            case .privacy: "shield"
            case .notifications: "bell"
            case .soulmate: "heart.fill"
            case .connectedApps: "square.grid.2x2"
            case .appearance: "sun.max"
            case .language: "globe"
            case .help: "questionmark.circle"
            }
        }
    }

    var body: some View {
        Group {
            if screen == .welcome {
                content
            } else if screen == .chat || screen == .messages {
                content
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(screen.eyebrow.uppercased())
                    .font(MacType.eyebrow)
                    .foregroundStyle(MacPalette.accent)
                Text(dynamicTitle)
                    .font(MacType.title)
                    .foregroundStyle(MacPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitleText)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .frame(maxWidth: 460, alignment: .leading)
            }
            Spacer()
        }
    }

    private var subtitleText: String {
        let state = _appState.wrappedValue
        if screen == .meetRecap, let meeting = currentRecapMeeting {
            return "You attended \(meeting.title) on \(LikemindedDate.full(meeting.scheduledAt))."
        }
        if screen == .circleDetail, let circle = appState.circleDetail {
            return circle.placementReason
        }
        guard screen == .meetOverview, state.isSignedIn else { return screen.subtitle }
        if let name = state.profile?.basicInfo?.name {
            let first = name.split(separator: " ").first.map(String.init) ?? name
            return "Good evening, \(first) 👋"
        }
        return screen.subtitle
    }

    private var dynamicTitle: String {
        switch screen {
        case .communityDetail, .communityMembers:
            return selectedCommunity?.name ?? screen.title
        case .circleDetail:
            return appState.circleDetail?.name ?? screen.title
        case .soulmateDetail:
            return appState.soulmateMatches.first?.name ?? screen.title
        default:
            return screen.title
        }
    }

    private var selectedCommunity: Community? {
        let communities = appState.joinedCommunities + appState.communities
        if let selectedCommunityId, let community = communities.first(where: { $0.id == selectedCommunityId }) {
            return community
        }
        return appState.joinedCommunities.first ?? appState.communities.first
    }

    private var profileInfo: BasicInfo? {
        appState.profile?.basicInfo
    }

    private var profileInterests: [Interest] {
        appState.profile?.interests ?? []
    }

    private var currentRecapMeeting: Meeting? {
        if let selectedRecapMeetingId,
           let meeting = (appState.pastMeetings + appState.upcomingMeetings).first(where: { $0.id == selectedRecapMeetingId }) {
            return meeting
        }
        return appState.pastMeetings.first ?? appState.upcomingMeetings.first
    }

    private func displayMemberCount(for circle: PlacementCircle) -> Int {
        if circle.membersOnline > 0 { return circle.membersOnline }
        if let detailed = appState.circleDetail, detailed.id == circle.id, detailed.membersOnline > 0 {
            return detailed.membersOnline
        }
        if let catalog = appState.circles.first(where: { $0.id == circle.id }), catalog.membersOnline > 0 {
            return catalog.membersOnline
        }
        return 12
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .welcome: welcome
        case .meetOverview: meetOverview
        case .circlesRoom: circlesRoom
        case .profileEdit: profileEdit
        case .chat: chat(title: "Chats", compact: false)
        case .communitiesBrowse: communitiesBrowse
        case .communityDetail: communityDetail(memberMode: false)
        case .meetRecap: meetRecap
        case .meetVideoCall: meetVideoCall
        case .myProfile: myProfile(editing: false)
        case .soulmateOverview: soulmateOverview
        case .soulmateDiscover: soulmateDiscover
        case .soulmateDetail: soulmateDetail
        case .communityMembers: communityMembers
        case .createEvent: createEvent
        case .messages: chat(title: "Messages", compact: true)
        case .notifications: notifications
        case .profileOnboarding: profileOnboarding
        case .profileSignals: myProfile(editing: true)
        case .circleDetail: communityDetail(memberMode: true)
        case .settingsSoulmate: settingsSoulmate
        case .createCommunity: createCommunity
        }
    }

    // MARK: - 1. welcome

    private var welcome: some View {
        HStack(spacing: 54) {
            VStack(alignment: .leading, spacing: 28) {
                Text("Likeminded")
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(MacPalette.accent)
                VStack(alignment: .leading, spacing: 8) {
                    Text("When you meet, matters.")
                        .font(MacType.title)
                        .foregroundStyle(MacPalette.ink)
                    Text("AI helps you meet the right people in the right rooms.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .frame(maxWidth: 400, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "waveform", title: "Voice profile", detail: "Let your voice speak first")
                    featureRow(icon: "lock", title: "Private by design", detail: "Your data stays yours")
                    featureRow(icon: "person.2", title: "Circle placement", detail: "Find your people effortlessly")
                }
                .padding(.vertical, 8)
                Button {
                    Task { await appState.signInWithApple() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.title3)
                        Text(appState.isAuthenticating ? "Signing in" : "Sign in with Apple")
                            .font(MacType.button)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(appState.isAuthenticating)
                .accessibilityLabel("Sign in with Apple")
                if let authError = appState.authError {
                    Text(authError)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.clay)
                }
                Text("By continuing, you agree to our Terms & Privacy Policy.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            .frame(width: 370)
            Spacer()
            MacOrb()
                .frame(width: 430, height: 360)
        }
        .frame(maxWidth: .infinity, minHeight: 560, alignment: .topLeading)
    }

    // MARK: - 2. meetOverview

    private var meetOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                if appState.isSignedIn {
                    if let meeting = appState.upcomingMeetings.first {
                        heroCard(meeting)
                            .frame(minWidth: 560)
                    } else {
                        emptyMeetupCard
                            .frame(minWidth: 560)
                    }
                    availabilityPanel
                } else {
                    MacPanel {
                        Text("Sign in to see your meetups")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                    }
                    .frame(height: 250)
                }
            }
            MacPanel(title: "Past meetups") {
                pastMeets
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchMeetings()
            }
        }
    }

    private var emptyMeetupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }
            Text("No upcoming meetups")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text("RSVP for this weekend to get scheduled.")
                .font(MacType.body)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.15), lineWidth: 1))
        .frame(height: 250)
    }

    private func heroCard(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upcoming meetup")
                        .font(MacType.small.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(LikemindedDate.meetHeader(meeting.scheduledAt))
                        .font(MacType.eyebrow)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer(minLength: 12)
                Text(LikemindedDate.countdownUntil(meeting.scheduledAt))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(MacPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.95), in: Capsule())
                    .contentTransition(.numericText())
            }
            Text(meeting.title)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Label("Host: \(meeting.hostName)", systemImage: "person.circle")
                Label("\(meeting.groupSize) participants", systemImage: "person.2")
                if !meeting.compositionSummary.isEmpty {
                    Label(meeting.compositionSummary, systemImage: "person.3")
                }
            }
            .font(MacType.body)
            .foregroundStyle(.white.opacity(0.88))
            Spacer(minLength: 4)
            Button("Join meetup") {
                navigate?(.meetVideoCall)
            }
            .font(MacType.button)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.92), in: Capsule())
            .foregroundStyle(MacPalette.accent)
            .buttonStyle(.plain)
            .accessibilityLabel("Join \(meeting.title) meetup")
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .leading)
        .background(
            LinearGradient(
                colors: [MacPalette.accent, Color(red: 0.04, green: 0.20, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - 21. meetVideoCall

    private var meetVideoCall: some View {
        let meeting = appState.upcomingMeetings.first
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting?.title ?? "Sunday Circle Meetup")
                        .font(MacType.section)
                    Text(meeting.map { LikemindedDate.full($0.scheduledAt) } ?? "Today - 7:00 PM - 8:00 PM")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
                Spacer()
                callStatus(icon: "video.fill", title: "Camera on", detail: "Everyone's camera is on")
                callStatus(icon: "person.2", title: "\(meeting?.groupSize ?? 10) participants", detail: nil)
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 14) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                        ForEach(callParticipants.prefix(4), id: \.self) { name in
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
                            ForEach(callParticipants, id: \.self) { participant in
                                HStack {
                                    Text(participant)
                                    if participant == meeting?.hostName {
                                        MacPill(text: "Host", isSelected: true)
                                    }
                                    Spacer()
                                    Image(systemName: "mic.fill")
                                        .foregroundStyle(MacPalette.accent)
                                }
                                .font(MacType.body)
                                .accessibilityLabel("\(participant) microphone on")
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
            if appState.upcomingMeetings.isEmpty {
                await appState.fetchMeetings()
            }
        }
    }

    private var callParticipants: [String] {
        var names = [appState.upcomingMeetings.first?.hostName, appState.profile?.basicInfo?.name]
            .compactMap { $0 }
        names.append(contentsOf: appState.soulmateMatches.map(\.name))
        names.append(contentsOf: ["Arjun", "Meera", "Rohan", "Karan", "Neha"])
        return Array(NSOrderedSet(array: names).compactMap { $0 as? String }.prefix(8))
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
                isCallMuted.toggle()
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
            Label("Good connection", systemImage: "cellularbars")
                .font(MacType.button)
                .foregroundStyle(MacPalette.ink)
            Button("Leave") { navigate?(.meetOverview) }
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

    private var availabilityPanel: some View {
        MacPanel(title: "Available this weekend?") {
            VStack(spacing: 12) {
                availabilityRow("Saturday", detail: "Community meetup", available: appState.meetingRsvps.community, kind: "community")
                Divider()
                availabilityRow("Sunday", detail: "Circle meetup", available: appState.meetingRsvps.circle, kind: "circle")
            }
            Label("RSVP closes Friday midnight.", systemImage: "clock")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .frame(width: 390)
    }

    private func availabilityRow(_ day: String, detail: String, available: Bool, kind: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(day)
                    .font(MacType.button)
                Text(detail)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    Task { await appState.updateMeetingRSVP(kind: kind, available: true) }
                } label: {
                    MacPill(text: "Available", isSelected: available)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day) \(detail) available")
                .accessibilityValue(available ? "Selected" : "Not selected")
                Button {
                    Task { await appState.updateMeetingRSVP(kind: kind, available: false) }
                } label: {
                    MacPill(text: "Not", isSelected: !available)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day) \(detail) not available")
                .accessibilityValue(!available ? "Selected" : "Not selected")
            }
        }
    }

    // MARK: - 3. circlesRoom

    private var circlesRoom: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !appState.joinedCircles.isEmpty {
                let myCircle = appState.joinedCircles.first!
                HStack(alignment: .top, spacing: 18) {
                    Button {
                        appState.circleDetail = myCircle
                        navigate?(.circleDetail)
                    } label: {
                        featuredCircleCard(myCircle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open your circle \(myCircle.name)")
                    concernCard
                        .frame(width: 300)
                }
            } else if appState.isSignedIn {
                MacPanel(title: "No joined circle yet") {
                    Text("Your starter circle will appear here after profile placement. Explore available rooms below for now.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Available circles")
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)
                    Spacer()
                    Button(showAllCircles ? "Show less" : "Browse all circles") {
                        showAllCircles.toggle()
                    }
                    .font(MacType.button)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(MacPalette.surface, in: Capsule())
                    .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                    .buttonStyle(.plain)
                    .accessibilityLabel(showAllCircles ? "Show fewer circles" : "Browse all circles")
                }
                if showAllCircles {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 260), spacing: 16, alignment: .leading)], alignment: .leading, spacing: 16) {
                        ForEach(Array(appState.circles.enumerated()), id: \.element.id) { index, circle in
                            circleCardButton(circle, index: index)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(appState.circles.enumerated()), id: \.element.id) { index, circle in
                                circleCardButton(circle, index: index)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .task {
            await appState.fetchCircles()
        }
    }

    private let gradientTones: [Color] = [MacPalette.accent, MacPalette.sage, MacPalette.clay, MacPalette.accent, MacPalette.sage]

    private func featuredCircleCard(_ circle: PlacementCircle) -> some View {
        ZStack(alignment: .bottomLeading) {
            DoodleCover(assetName: DoodleArt.circle(circle.id), height: 240, cornerRadius: 18, scrimStyle: .heroOverlay)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(circle.name)
                        .font(MacType.coverTitle)
                        .foregroundStyle(.white)
                    Text(circle.roomEnergy)
                        .font(MacType.coverMeta)
                        .foregroundStyle(.white.opacity(0.92))
                }
                FlowLayout(spacing: 8) {
                    ForEach(circle.themes.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(MacType.small.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.18), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
                    }
                }
                HStack(spacing: 20) {
                    Label("Sunday 7pm", systemImage: "clock")
                    Label("\(displayMemberCount(for: circle)) members", systemImage: "person.2")
                }
                .font(MacType.coverMeta)
                .foregroundStyle(.white.opacity(0.9))
            }
            .doodleOverlayText()
            .padding(24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 240)
    }

    private var concernCard: some View {
        MacPanel {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "hand.raised.slash")
                    .font(.title2)
                    .foregroundStyle(MacPalette.accent)
                Text("This doesn't feel like my circle")
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                Text(circleConcernStatus ?? "Ask for a placement refresh when the room feels off.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                Button("Request refresh") {
                    circleConcernStatus = "Requesting a placement refresh..."
                    Task {
                        await appState.reportCircleConcern("macOS circle concern")
                        circleConcernStatus = appState.loadError ?? "Placement refresh requested."
                    }
                }
                .font(MacType.button)
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MacPalette.accent, in: Capsule())
                .foregroundStyle(.white)
                .accessibilityLabel("Request circle placement refresh")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 170)
    }

    private func circleCardButton(_ circle: PlacementCircle, index: Int) -> some View {
        Button {
            appState.circleDetail = circle
            navigate?(.circleDetail)
        } label: {
            circleCard(circle, index: index)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(circle.name) circle")
        .accessibilityValue("\(displayMemberCount(for: circle)) members")
    }

    private func circleCard(_ circle: PlacementCircle, index: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            DoodleCover(assetName: DoodleArt.circle(circle.id), height: 170, cornerRadius: 18, scrimStyle: .bottomBand)
            VStack(alignment: .leading, spacing: 4) {
                Text(circle.name)
                    .font(MacType.coverTitleSmall)
                    .foregroundStyle(.white)
                Text("\(displayMemberCount(for: circle)) members")
                    .font(MacType.coverMeta)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .doodleOverlayText()
            .padding(18)
        }
        .frame(width: 240, height: 170)
    }

    // MARK: - 4. profileEdit

    private var profileEdit: some View {
        let profile = appState.profile
        let signals = profile?.signals
        let traits = profileTraitRows(from: signals)
        return HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Living profile")
                    .font(MacType.section)
                    .foregroundStyle(.white)
                Text("Read-only signals from your voice profile")
                    .font(MacType.small)
                    .foregroundStyle(.white.opacity(0.75))
                HStack(spacing: 10) {
                    ForEach(profileSignalLabels(from: signals), id: \.title) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(MacType.small)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(item.value)
                                .font(MacType.button)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                Label(signals?.communicationStyle?.primary.map { "\($0.capitalized) communicator" } ?? "Voice profile signals", systemImage: "message")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                VStack(spacing: 12) {
                    ForEach(traits, id: \.label) { trait in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(trait.left)
                                    .font(MacType.small)
                                    .foregroundStyle(.white.opacity(0.75))
                                Spacer()
                                Text(trait.right)
                                    .font(MacType.small)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.2))
                                    Capsule()
                                        .fill(.white.opacity(0.85))
                                        .frame(width: max(8, geo.size.width * trait.value))
                                }
                            }
                            .frame(height: 8)
                            .accessibilityLabel(trait.label)
                            .accessibilityValue(String(format: "%.0f percent", trait.value * 100))
                        }
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(width: 480)
            MacPanel(title: "Interests") {
                let interests = profile?.interests.map(\.label) ?? []
                tagWrap(interests.isEmpty ? ["Interests appear after your voice profile"] : interests)
                Divider()
                Text("Reflection")
                    .font(MacType.section)
                Text("Your read")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacPalette.muted)
                Text(profile?.profileSummary ?? "Complete your voice profile to see your private read.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                Button("Back to profile") {
                    navigate?(.myProfile)
                }
                    .font(MacType.button)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(MacPalette.accent, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to profile")
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.loadCurrentProfile()
            }
        }
    }

    // MARK: - 5. chat / messages (mockup 05 + 15)

    private var filteredChatMatches: [SoulmateMatch] {
        var matches = appState.soulmateMatches
        if chatFilter == "Unread" {
            matches = matches.filter { !readChatMatchIds.contains($0.matchId) }
        } else if chatFilter == "Groups" {
            matches = []
        }
        let query = chatSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return matches }
        return matches.filter { match in
            match.name.lowercased().contains(query)
                || (appState.chatPreviews[match.matchId]?.text.lowercased().contains(query) ?? false)
        }
    }

    private func chat(title: String, compact: Bool) -> some View {
        let selectedMatch = appState.soulmateMatches.first(where: { $0.matchId == selectedChatMatchId })
            ?? filteredChatMatches.first
            ?? appState.soulmateMatches.first
        let listWidth: CGFloat = compact ? 340 : 360
        return HStack(alignment: .top, spacing: 18) {
            // Conversation list — mockup Messages sidebar
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(title)
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)
                    Spacer()
                    Button {
                        navigate?(.soulmateDiscover)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MacPalette.accent)
                            .frame(width: 32, height: 32)
                            .background(MacPalette.accentSoft.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Find matches")
                    .help("Open Soulmate discover to find people to message")
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MacPalette.muted)
                    TextField(compact ? "Search messages" : "Search conversations", text: $chatSearch)
                        .font(MacType.body)
                        .textFieldStyle(.plain)
                        .accessibilityLabel(compact ? "Search messages" : "Search conversations")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(MacPalette.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MacPalette.line, lineWidth: 1))

                HStack(spacing: 8) {
                    ForEach(["All", "Unread", "Groups"], id: \.self) { filter in
                        Button(filter) { chatFilter = filter }
                            .font(MacType.small.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(chatFilter == filter ? MacPalette.accent : MacPalette.background, in: Capsule())
                            .foregroundStyle(chatFilter == filter ? .white : MacPalette.ink)
                            .overlay(Capsule().stroke(chatFilter == filter ? Color.clear : MacPalette.line, lineWidth: 1))
                            .buttonStyle(.plain)
                            .accessibilityLabel(filter)
                            .accessibilityValue(chatFilter == filter ? "Selected" : "Not selected")
                    }
                }

                ScrollView {
                    VStack(spacing: 6) {
                        if chatFilter == "Groups" {
                            Text("Group threads are not part of this MVP. Mutual match chats appear under All.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .padding(.vertical, 12)
                        } else if filteredChatMatches.isEmpty {
                            Text(appState.soulmateMatches.isEmpty
                                  ? "No conversations yet. Mutual matches appear here after meetups."
                                  : chatFilter == "Unread"
                                    ? "No unread conversations."
                                    : "No conversations match “\(chatSearch)”.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .padding(.vertical, 12)
                        }

                        ForEach(filteredChatMatches) { match in
                            Button {
                                selectedChatMatchId = match.matchId
                                readChatMatchIds.insert(match.matchId)
                            } label: {
                                chatListRow(
                                    match,
                                    selected: match.matchId == selectedMatch?.matchId,
                                    unread: !readChatMatchIds.contains(match.matchId)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open conversation with \(match.name)")
                        }
                    }
                }
            }
            .padding(18)
            .frame(width: listWidth, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(MacPalette.line, lineWidth: 1))

            // Active thread — mockup right pane
            VStack(spacing: 0) {
                if let selectedMatch {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            MacAvatar(initials: String(selectedMatch.name.prefix(1)), color: MacPalette.accentSoft, size: 40)
                            Circle()
                                .fill(MacPalette.accent)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(MacPalette.surface, lineWidth: 2))
                                .offset(x: 1, y: 1)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedMatch.name)
                                .font(MacType.button)
                                .foregroundStyle(MacPalette.ink)
                            Text("Online")
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.accent)
                        }
                        Spacer()
                        // Mockup shows call/info chrome; voice/video are not in MVP.
                        chatHeaderIcon("phone", label: "Voice call planned")
                        chatHeaderIcon("video", label: "Video call planned")
                        chatHeaderIcon("info.circle", label: "Conversation info planned")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    Divider().overlay(MacPalette.line)

                    if appState.chatMessages.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Text(appState.messageError ?? "No messages yet. Say hello.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 14) {
                                    Text("Today")
                                        .font(MacType.small.weight(.semibold))
                                        .foregroundStyle(MacPalette.muted)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 4)
                                    ForEach(appState.chatMessages) { message in
                                        messageBubble(
                                            message,
                                            mine: message.senderId == appState.authSession?.userId
                                        )
                                        .id(message.id)
                                    }
                                }
                                .padding(20)
                            }
                            .onChange(of: appState.chatMessages.count) { _, _ in
                                if let last = appState.chatMessages.last {
                                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                                }
                            }
                        }
                    }

                    Divider().overlay(MacPalette.line)
                    MacChatComposer(
                        matchId: selectedMatch.matchId,
                        appState: appState,
                        placeholder: "Type a message..."
                    )
                } else {
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36))
                            .foregroundStyle(MacPalette.accentSoft)
                        Text("Select a conversation")
                            .font(MacType.section)
                        Text("Mutual match threads from meetups show up here.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, minHeight: 520, maxHeight: .infinity, alignment: .top)
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
                selectedChatMatchId = selectedChatMatchId ?? appState.soulmateMatches.first?.matchId
                if let matchId = selectedChatMatchId {
                    readChatMatchIds.insert(matchId)
                    await appState.loadMessages(matchId: matchId)
                }
            }
        }
        .task(id: selectedChatMatchId) {
            if let matchId = selectedChatMatchId {
                readChatMatchIds.insert(matchId)
                await appState.loadMessages(matchId: matchId)
            }
        }
    }

    private func chatHeaderIcon(_ systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(MacPalette.muted.opacity(0.55))
            .frame(width: 34, height: 34)
            .background(MacPalette.background, in: Circle())
            .overlay(Circle().stroke(MacPalette.line, lineWidth: 1))
            .accessibilityLabel(label)
    }

    private func chatListRow(_ match: SoulmateMatch, selected: Bool, unread: Bool) -> some View {
        let preview = appState.chatPreviews[match.matchId]
        let previewText = preview?.text ?? "No messages yet"
        let stamp = preview.map { chatTimeLabel($0.createdAt) } ?? chatTimeLabel(match.createdAt)
        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                MacAvatar(initials: String(match.name.prefix(1)), color: MacPalette.accentSoft, size: 44)
                if unread {
                    Circle()
                        .fill(MacPalette.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(MacPalette.surface, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(match.name)
                        .font(MacType.button)
                        .foregroundStyle(MacPalette.ink)
                    Spacer()
                    Text(stamp)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
                Text(previewText)
                    .font(MacType.small)
                    .foregroundStyle(unread ? MacPalette.ink : MacPalette.muted)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(selected ? MacPalette.accentSoft.opacity(0.45) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chatTimeLabel(_ iso: String) -> String {
        if let date = LikemindedDate.parse(iso) {
            if Calendar.current.isDateInToday(date) {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return formatter.string(from: date)
            }
            return LikemindedDate.short(iso)
        }
        return String(iso.prefix(10))
    }

    // MARK: - 6. communitiesBrowse (mockup plate 06: horizontal filters + create tile in grid)

    private var communitiesBrowse: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MacPalette.muted)
                    .font(MacType.body)
                TextField("Search communities...", text: $communitySearch)
                    .font(MacType.body)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search communities")
            }
            .padding(12)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MacPalette.line, lineWidth: 1))

            HStack(spacing: 10) {
                ForEach(["All", "Trending", "Nearby", "New"], id: \.self) { filter in
                    Button {
                        communityFilter = filter
                    } label: {
                        Text(filter)
                            .font(MacType.small.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(communityFilter == filter ? MacPalette.accent : MacPalette.surface, in: Capsule())
                            .foregroundStyle(communityFilter == filter ? .white : MacPalette.ink)
                            .overlay(Capsule().stroke(communityFilter == filter ? Color.clear : MacPalette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(filter) communities filter")
                    .accessibilityValue(communityFilter == filter ? "Selected" : "Not selected")
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 250, maximum: 300), spacing: 18, alignment: .top)],
                alignment: .leading,
                spacing: 18
            ) {
                Button {
                    navigate?(.createCommunity)
                } label: {
                    createCommunityCard
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create a community")

                ForEach(Array(filteredCommunities.enumerated()), id: \.element.id) { index, community in
                    communityTile(community, index: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await appState.fetchCommunities()
        }
    }

    private var filteredCommunities: [Community] {
        let query = communitySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var communities = appState.communities
        switch communityFilter {
        case "Trending":
            communities = communities.filter { $0.membersCount >= 10 }
        case "Nearby":
            communities = communities.filter { $0.themes.contains { ["Jazz", "Trekking", "Mindfulness"].contains($0) } }
        case "New":
            communities = communities.suffix(4).map { $0 }
        default:
            break
        }
        guard !query.isEmpty else { return communities }
        return communities.filter { community in
            community.name.lowercased().contains(query)
                || community.summary.lowercased().contains(query)
                || community.themes.contains { $0.lowercased().contains(query) }
        }
    }

    private func isCommunityJoined(_ community: Community) -> Bool {
        appState.joinedCommunities.contains { $0.id == community.id }
    }

    private let communityGradients: [(Color, Color)] = [
        (MacPalette.sage, MacPalette.accent),
        (MacPalette.clay, Color.black.opacity(0.6)),
        (MacPalette.accent, MacPalette.ink),
        (MacPalette.sage.opacity(0.7), MacPalette.clay),
    ]

    private func communityTile(_ community: Community, index: Int) -> some View {
        let joined = isCommunityJoined(community)
        return VStack(spacing: 0) {
            Button {
                selectedCommunityId = community.id
                navigate?(.communityDetail)
            } label: {
                communityCard(community, index: index, joined: joined)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(community.name) community")
            .accessibilityValue(joined ? "Joined" : "Not joined")
            Button {
                Task {
                    if joined {
                        await appState.leaveCommunity(id: community.id)
                    } else {
                        await appState.joinCommunity(id: community.id)
                    }
                }
            } label: {
                Text(joined ? "Joined" : "Join")
                    .font(MacType.small.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(joined ? MacPalette.accentSoft.opacity(0.65) : MacPalette.accent, in: Capsule())
                    .foregroundStyle(joined ? MacPalette.accent : .white)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
            .accessibilityLabel("\(joined ? "Leave" : "Join") \(community.name) community")
            .accessibilityValue(joined ? "Joined" : "Not joined")
        }
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private func communityCard(_ community: Community, index: Int, joined: Bool) -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                DoodleCover(assetName: DoodleArt.community(community.id), height: 140, cornerRadius: 0, scrimStyle: .bottomBand)
                VStack {
                    HStack {
                        Spacer()
                        Text(joined ? "Joined" : "Join")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.85), in: Capsule())
                    }
                    Spacer()
                }
                .padding(12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(community.name)
                        .font(MacType.coverTitleSmall)
                        .foregroundStyle(.white)
                }
                .doodleOverlayText()
                .padding(16)
            }
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
            VStack(alignment: .leading, spacing: 12) {
                Text(community.summary)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .lineLimit(2)
                HStack {
                    Text("\(community.membersCount) members")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                    Spacer()
                }
            }
            .padding(16)
        }
        .frame(minHeight: 220)
    }

    private var createCommunityCard: some View {
        VStack(spacing: 0) {
            ZStack {
                MacPalette.background
                VStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(MacPalette.accent, in: Circle())
                    Text("Create a community")
                        .font(MacType.coverTitleSmall)
                        .foregroundStyle(MacPalette.ink)
                    Text("Start a space for people who vibe with your interests.")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(20)
            }
            .frame(height: 140)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))

            VStack(spacing: 12) {
                Text("Member-led rooms around shared interests.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("+ Create")
                    .font(MacType.small.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(MacPalette.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .top)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MacPalette.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
        )
    }

    // MARK: - 7. communityDetail / circleDetail

    @ViewBuilder
    private func communityDetail(memberMode: Bool) -> some View {
        if memberMode {
            circleDetailScreen
        } else {
            communityDetailScreen
        }
    }

    private var circleDetailScreen: some View {
        let circle = appState.circleDetail ?? appState.joinedCircles.first
        let themes = circle?.themes ?? []
        let nextMeeting = appState.upcomingMeetings.first(where: { $0.kind == "circle" && $0.targetId == circle?.id })
        return HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    DoodleCover(
                        assetName: DoodleArt.circle(circle?.id ?? "reflective-builders"),
                        height: 220,
                        cornerRadius: 18,
                        scrimStyle: .heroOverlay
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Text(circle?.name ?? "Your circle")
                            .font(MacType.coverTitle)
                            .foregroundStyle(.white)
                        Text(circle?.placementReason ?? circle?.roomEnergy ?? "Personality-fit room")
                            .font(MacType.coverMeta)
                            .foregroundStyle(.white.opacity(0.9))
                        FlowLayout(spacing: 6) {
                            ForEach(themes.prefix(4), id: \.self) { tag in
                                Text(tag)
                                    .font(MacType.small.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.2), in: Capsule())
                            }
                        }
                    }
                    .doodleOverlayText()
                    .padding(24)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 12) {
                    Button("Message circle") { navigate?(.messages) }
                        .buttonStyle(.borderedProminent)
                        .tint(MacPalette.accent)
                        .accessibilityLabel("Message circle")
                    Button("Placement concern") {
                        Task {
                            await appState.reportCircleConcern("macOS circle detail concern")
                            circleConcernStatus = appState.loadError ?? "Concern registered. Check Profile for re-interview."
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("This does not feel like my circle")
                }

                HStack(spacing: 18) {
                    statItem("person.2", "\(circle?.membersOnline ?? 12) members")
                    if let nextMeeting {
                        statItem("calendar", "Next meetup\n\(LikemindedDate.meetHeader(nextMeeting.scheduledAt))")
                        statItem("person.crop.circle", "Host\n\(nextMeeting.hostName)")
                    } else {
                        statItem("calendar", "Next meetup\nSunday 7:00 PM")
                    }
                }

                MacPanel(title: "Upcoming") {
                    if let nextMeeting {
                        Button {
                            selectedRecapMeetingId = nextMeeting.id
                            navigate?(.meetOverview)
                        } label: {
                            pastMeetRow(nextMeeting)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("RSVP on Meet to get scheduled for the next Sunday circle meetup.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            MacPanel(title: "Circle fit") {
                Text(circle?.shortPromise ?? "A room shaped around how you connect.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                if let circle {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(circle.roomEnergy, systemImage: "sparkle")
                        Label(circle.easiestFirstAction, systemImage: "hand.wave")
                        Label(circle.fitLabel, systemImage: "checkmark.seal")
                    }
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.accent)
                }
                if let circleConcernStatus {
                    Text(circleConcernStatus)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
            }
            .frame(width: 300)
        }
        .task {
            if let id = appState.circleDetail?.id ?? appState.joinedCircles.first?.id {
                await appState.loadCircleDetail(id: id)
            } else {
                await appState.fetchCircles()
            }
        }
    }

    private var communityDetailScreen: some View {
        let community = selectedCommunity
        let themes = community?.themes ?? []
        let isJoined = community.map(isCommunityJoined) ?? false
        let nextMeeting = appState.upcomingMeetings.first(where: { $0.kind == "community" && $0.targetId == community?.id })
        return HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .bottomLeading) {
                        DoodleCover(
                            assetName: DoodleArt.community(community?.id ?? "design-craft"),
                            height: 250,
                            cornerRadius: 18,
                            scrimStyle: .heroOverlay
                        )
                        VStack(alignment: .leading, spacing: 8) {
                            Text(community?.name ?? "Community")
                                .font(MacType.coverTitle)
                                .foregroundStyle(.white)
                            Text(community?.summary ?? "Listen, share, explore.")
                                .font(MacType.coverMeta)
                                .foregroundStyle(.white.opacity(0.9))
                            FlowLayout(spacing: 6) {
                                ForEach(themes.prefix(4), id: \.self) { tag in
                                    Text(tag)
                                        .font(MacType.small.weight(.medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.white.opacity(0.2), in: Capsule())
                                }
                            }
                        }
                        .doodleOverlayText()
                        .padding(24)
                    }
                    .frame(height: 250)
                    HStack(spacing: 8) {
                        Button(isJoined ? "Joined" : "Join") {
                            guard let community else { return }
                            selectedCommunityId = community.id
                            Task {
                                if isJoined {
                                    await appState.leaveCommunity(id: community.id)
                                    communityDetailStatus = "Left \(community.name)."
                                } else {
                                    await appState.joinCommunity(id: community.id)
                                    communityDetailStatus = "Joined \(community.name)."
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.88), in: Capsule())
                        .foregroundStyle(MacPalette.accent)
                        .accessibilityLabel(isJoined ? "Leave community" : "Join community")
                        .accessibilityValue(isJoined ? "Joined" : "Not joined")

                        Button {
                            communityDetailStatus = "Guidelines, sharing, and report tools are in the About card."
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(MacType.button)
                                .padding(8)
                                .background(.white.opacity(0.88), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MacPalette.accent)
                        .accessibilityLabel("Community options")
                    }
                    .padding(18)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack(spacing: 18) {
                    statItem("person.2", "\(community?.membersCount ?? 18) members")
                    if let nextMeeting {
                        statItem("calendar", "Next meetup\n\(LikemindedDate.short(nextMeeting.scheduledAt))")
                        statItem("person.crop.circle", "Host\n\(nextMeeting.hostName)")
                    } else {
                        statItem("calendar", "Next meetup\nSaturday 7:00 PM")
                        statItem("person.crop.circle", "Host\nTBD")
                    }
                }
                .padding(.vertical, 4)

                HStack(spacing: 8) {
                    ForEach(["Upcoming", "Members", "Resources", "Highlights"], id: \.self) { tab in
                        Button(tab) { communityDetailTab = tab }
                            .buttonStyle(.plain)
                            .font(MacType.small.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(communityDetailTab == tab ? MacPalette.accentSoft : .clear, in: Capsule())
                            .foregroundStyle(communityDetailTab == tab ? MacPalette.accent : MacPalette.muted)
                            .accessibilityValue(communityDetailTab == tab ? "Selected" : "Not selected")
                    }
                }

                MacPanel(title: communityDetailTab) {
                    communityDetailTabContent
                }
            }
            .frame(maxWidth: .infinity)

            MacPanel(title: "About") {
                Text(community?.summary ?? "A seeded community from the validation database.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                Button("View guidelines") {
                    communityDetailStatus = "Guidelines opened for \(community?.name ?? "this community")."
                }
                .buttonStyle(.bordered)
                Text("You'll fit in if you:")
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(MacPalette.ink)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Love thoughtful conversations", systemImage: "checkmark.circle.fill")
                    Label("Enjoy listening deeply", systemImage: "checkmark.circle.fill")
                    Label("Value different perspectives", systemImage: "checkmark.circle.fill")
                    Label("Share and support others", systemImage: "checkmark.circle.fill")
                }
                .font(MacType.small)
                .foregroundStyle(MacPalette.accent)
                if let communityDetailStatus {
                    Text(communityDetailStatus)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 300)
        }
    }

    @ViewBuilder
    private var communityDetailTabContent: some View {
        switch communityDetailTab {
        case "Members":
            Button("View members") {
                if let community = selectedCommunity {
                    selectedCommunityId = community.id
                }
                navigate?(.communityMembers)
            }
            .buttonStyle(.borderedProminent)
        case "Resources":
            eventRow("Community guidelines", date: "Pinned")
            eventRow("Conversation prompts", date: "Updated weekly")
        case "Highlights":
            eventRow("Best essay thread", date: "12 replies")
            eventRow("Most saved recommendation", date: "Vinyl listening")
        default:
            let communityId = selectedCommunity?.id
            let communityMeetings = appState.upcomingMeetings.filter {
                $0.kind == "community" && $0.targetId == communityId
            }
            if communityMeetings.isEmpty {
                Button {
                    navigate?(.createEvent)
                } label: {
                    detailEventRow(title: "Community Meetup", subtitle: "Plan an event · Create a listening session")
                }
                .buttonStyle(.plain)
            } else {
                ForEach(communityMeetings) { meeting in
                    Button {
                        selectedRecapMeetingId = meeting.id
                        navigate?(.meetOverview)
                    } label: {
                        detailEventRow(
                            title: meeting.title,
                            subtitle: "\(LikemindedDate.meetHeader(meeting.scheduledAt)) · Host \(meeting.hostName)"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statItem(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(MacType.small.weight(.semibold))
            .foregroundStyle(MacPalette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 8. meetRecap

    private var meetRecap: some View {
        let meeting = currentRecapMeeting
        let connectedPeople = appState.soulmateMatches
        return HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                MacPanel(title: "Meeting insights") {
                    metricRow([
                        ("\(meeting?.groupSize ?? 0)", "People attended"),
                        ("\(connectedPeople.count)", "Mutual matches"),
                        (meeting.map { LikemindedDate.short($0.scheduledAt) } ?? "No date", "Meet date"),
                        (meeting?.kind.capitalized ?? "Meet", "Room type")
                    ])
                        .padding(.bottom, 4)
                    tagWrap(meeting?.compositionSummary.split(separator: ".").prefix(3).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? [])
                }
                MacPanel(title: "Your notes") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Add a private note...", text: $recapNote, axis: .vertical)
                            .font(MacType.body)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                            .frame(minHeight: 100)
                            .accessibilityLabel("Add a private note")

                        HStack {
                            Button(isSavingRecapNote ? "Saving" : "Save note") {
                                Task { await saveRecapNote(meeting) }
                            }
                            .font(MacType.small.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(MacPalette.accent, in: Capsule())
                            .foregroundStyle(.white)
                            .buttonStyle(.plain)
                            .disabled(meeting == nil || isSavingRecapNote)

                            if let recapNoteStatus {
                                Text(recapNoteStatus)
                                    .font(MacType.small)
                                    .foregroundStyle(MacPalette.muted)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            MacPanel(title: "People you connected with") {
                if connectedPeople.isEmpty {
                    Text("No mutual matches from seeded meetups yet.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
                ForEach(connectedPeople) { match in
                    HStack(spacing: 12) {
                        MacAvatar(initials: String(match.name.prefix(1)))
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(match.name)
                                .font(MacType.button)
                            Text(match.meetingDate.map { "Met \(LikemindedDate.short($0))" } ?? "Seeded mutual match")
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.muted)
                        }
                        Spacer()
                        Button("Message") {
                            selectedChatMatchId = match.matchId
                            navigate?(.chat)
                        }
                            .font(MacType.small.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(MacPalette.accent, in: Capsule())
                            .foregroundStyle(.white)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Message \(match.name)")
                    }
                    .padding(8)
                    .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                }
            }
            .frame(width: 360)
        }
        .task {
            if appState.isSignedIn {
                recapNote = meeting?.recapNote ?? ""
                await appState.fetchMeetings()
                await appState.fetchSoulmateStatus()
            }
        }
    }

    // MARK: - 9. myProfile

    private func myProfile(editing: Bool) -> some View {
        HStack(alignment: .top, spacing: 24) {
            if let profile = appState.profile {
                let name = profile.basicInfo?.name ?? "You"
                let location = profile.basicInfo?.city ?? "Your location"
                profileCard(name: name, location: location, profile: profile, editing: editing)
                VStack(spacing: 18) {
                    MacPanel {
                        HStack(alignment: .firstTextBaseline) {
                            Text(editing ? "Your personality signals" : "Personality signals")
                                .font(MacType.section)
                                .foregroundStyle(MacPalette.ink)
                            Spacer()
                            Button("Retake voice profile") {
                                navigate?(.profileOnboarding)
                            }
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.accent)
                            .buttonStyle(.plain)
                            .accessibilityLabel("Retake voice profile")
                        }
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                            spacing: 10
                        ) {
                            ForEach(profileSignalCards(from: profile.signals), id: \.title) { item in
                                signalCard(item.title, detail: item.value)
                            }
                        }
                    }
                    MacPanel {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Top interests")
                                .font(MacType.section)
                                .foregroundStyle(MacPalette.ink)
                            Spacer()
                            let interests = profile.interests.map(\.label)
                            if interests.count > 5 {
                                Button(showAllInterests ? "Show less" : "View all") {
                                    showAllInterests.toggle()
                                }
                                .font(MacType.small.weight(.semibold))
                                .foregroundStyle(MacPalette.accent)
                                .buttonStyle(.plain)
                                .accessibilityLabel(showAllInterests ? "Show less" : "View all")
                            }
                        }
                        let interests = profile.interests.map(\.label)
                        if interests.isEmpty {
                            Text("Interests appear after your voice profile.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                        } else if showAllInterests {
                            tagWrap(interests)
                        } else {
                            tagWrap(Array(interests.prefix(5)) + (interests.count > 5 ? ["+\(interests.count - 5)"] : []))
                        }
                    }
                    MacPanel(title: "My vibe") {
                        HStack(alignment: .top, spacing: 20) {
                            Text(profile.profileSummary?.isEmpty == false ? profile.profileSummary! : "Your private read appears after the voice interview.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            MacOrb()
                                .scaleEffect(0.55)
                                .frame(width: 120, height: 120)
                        }
                    }
                    HStack(alignment: .top, spacing: 18) {
                        MacPanel(title: "About me") {
                            Text(profile.profileSummary?.isEmpty == false
                                 ? profile.profileSummary!
                                 : "Your voice profile summary appears here after the interview.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                        }
                        MacPanel(title: "Languages") {
                            tagWrap(profileLanguages(for: profile))
                        }
                    }
                }
            } else if appState.isSignedIn {
                MacPanel(title: appState.isLoading ? "Loading profile..." : "Profile not ready") {
                    Text(appState.loadError ?? "Complete your voice profile to see your placement, interests, and private signals here.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    Button("Start profile setup") {
                        navigate?(.profileOnboarding)
                    }
                    .font(MacType.button)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(MacPalette.accent, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start profile setup")
                }
            } else {
                Text("Sign in to view your profile")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.loadCurrentProfile()
                await appState.loadCurrentPlacement()
                await appState.fetchCircles()
                await appState.fetchMeetings()
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private func profileCard(name: String, location: String, profile: UserProfile, editing: Bool) -> some View {
        let circleCount = max(appState.joinedCircles.count, appState.placement == nil ? 0 : 1)
        let connectionCount = appState.soulmateMatches.count
        let eventCount = appState.upcomingMeetings.count + appState.pastMeetings.count
        let gender = profile.basicInfo?.gender
        return MacPanel(dark: true) {
            VStack(spacing: 14) {
                DoodlePortrait(assetName: DoodleArt.portrait(for: gender), size: 92)
                    .padding(.top, 6)
                HStack(spacing: 8) {
                    Text(name)
                        .font(MacType.title)
                    if !editing {
                        Button {
                            navigate?(.profileEdit)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit profile")
                    }
                }
                Label(location, systemImage: "mappin")
                    .font(MacType.body)
                    .foregroundStyle(.white.opacity(0.8))
                Label("Voice profile active", systemImage: "waveform")
                    .font(MacType.small.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())
                HStack(spacing: 0) {
                    profileStat(value: "\(circleCount)", label: "Circles")
                    profileStat(value: "\(connectionCount)", label: "Connections")
                    profileStat(value: "\(eventCount)", label: "Events")
                }
                .padding(.vertical, 4)
                if let summary = profile.profileSummary, !summary.isEmpty {
                    Text(summary)
                        .font(MacType.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(3)
                }
                if editing {
                    Button("Done") {
                        navigate?(.myProfile)
                    }
                    .font(MacType.button)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .foregroundStyle(MacPalette.accent)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                } else {
                    Button("Share profile") {
                        navigate?(.profileSignals)
                    }
                    .font(MacType.button)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.16), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share profile")
                    Button("Edit profile") {
                        navigate?(.profileEdit)
                    }
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .buttonStyle(.plain)
                    .underline()
                    .accessibilityLabel("Edit profile")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 300)
    }

    private func profileLanguages(for profile: UserProfile) -> [String] {
        if profile.basicInfo?.city.localizedCaseInsensitiveContains("bangalore") == true {
            return ["English", "Hindi"]
        }
        return ["English"]
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(MacType.button)
                .foregroundStyle(.white)
            Text(label)
                .font(MacType.small)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - 10. soulmateOverview

    private var soulmateOverview: some View {
        HStack(spacing: 42) {
            MacPanel(title: appState.soulmateEnabled ? "Soulmate Enabled" : "Enable Soulmate", dark: true) {
                Text("Let us show you compatible people after your meetups and in your circles.")
                    .font(MacType.body)
                    .foregroundStyle(.white.opacity(0.8))
                Divider().background(.white.opacity(0.3))
                VStack(alignment: .leading, spacing: 12) {
                    Label("Visible only after meetups", systemImage: "checkmark.shield")
                        .font(MacType.body)
                    Label("You're in control", systemImage: "person")
                        .font(MacType.body)
                    Label("Private by design", systemImage: "lock")
                        .font(MacType.body)
                }
                .padding(.vertical, 4)
                if appState.soulmateEnabled {
                    // Toggle lives only in Settings once enabled — avoid a second enable control here.
                    Label("On — change this in Settings", systemImage: "checkmark.circle.fill")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.sage)
                        .accessibilityLabel("Soulmate is on. Change this in Settings.")
                } else {
                    Toggle("Enable Soulmate", isOn: Binding(
                        get: { appState.soulmateEnabled },
                        set: { enabled in
                            Task { await appState.setSoulmateEnabled(enabled) }
                        }
                    ))
                    .toggleStyle(.switch)
                    .tint(MacPalette.sage)
                    .accessibilityLabel("Enable Soulmate")
                    .accessibilityValue("Off")
                }
                Button("How it works") {
                    navigate?(.soulmateDiscover)
                }
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.sage)
                    .buttonStyle(.plain)
                    .underline()
            }
            .frame(width: 420)
            Spacer()
            MacOrb(heart: true)
                .scaleEffect(1.2)
                .frame(width: 470, height: 360)
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private func saveRecapNote(_ meeting: Meeting?) async {
        guard let meeting else { return }
        isSavingRecapNote = true
        await appState.saveMeetingRecapNote(meetingId: meeting.id, note: recapNote)
        recapNoteStatus = appState.meetingError == nil ? "Saved" : appState.meetingError
        isSavingRecapNote = false
    }

    // MARK: - 11. soulmateDiscover

    private var soulmateDiscover: some View {
        HStack(alignment: .top, spacing: 24) {
            MacPanel(title: "How matches work") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Matches appear only after mutual selection from a meetup. Distance and interest filters are not part of this MVP.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    formLine("Source", value: "Mutual meetup selection")
                    formLine("Visible when", value: appState.soulmateEnabled ? "Soulmate enabled" : "Soulmate off")
                    formLine("Matches", value: "\(appState.soulmateMatches.count)")
                }
            }
            .frame(width: 250)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text("Mutual matches")
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)
                    Spacer()
                    Button("New matches") {
                        Task { await appState.fetchSoulmateStatus() }
                    }
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MacPalette.surface, in: Capsule())
                        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                        .buttonStyle(.plain)
                        .accessibilityLabel("New matches")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                    ForEach(appState.soulmateMatches) { match in
                        Button {
                            selectedSoulmateMatchId = match.matchId
                            navigate?(.soulmateDetail)
                        } label: {
                            matchCard(match)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(match.name)")
                    }
                }

                if appState.soulmateMatches.isEmpty {
                    Text("Matches will appear here after your meetups.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 60)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private func matchCard(_ match: SoulmateMatch) -> some View {
        let meetingLabel = match.meetingDate.map { "Met \(LikemindedDate.short($0))" } ?? "Mutual match"
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .center) {
                LinearGradient(colors: [MacPalette.accent, MacPalette.sage.opacity(0.7), MacPalette.ink.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 8) {
                    Text(String(match.name.prefix(2)).uppercased())
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 160)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
            VStack(alignment: .leading, spacing: 8) {
                Text(match.name)
                    .font(MacType.button)
                Text(meetingLabel)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                Text("Open for interests and chat")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                HStack {
                    Spacer()
                    Image(systemName: "heart")
                        .foregroundStyle(MacPalette.accent)
                        .font(.title3)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    // MARK: - 12. soulmateDetail

    private var soulmateDetail: some View {
        let match = appState.soulmateMatches.first(where: { $0.matchId == selectedSoulmateMatchId })
            ?? appState.soulmateMatches.first
        let detail = soulmateMatchDetail
        let name = detail?.name ?? match?.name ?? "Soulmate match"
        let meetingLabel = (detail?.meetingDate ?? match?.meetingDate).map { "Met \(LikemindedDate.short($0))" }
            ?? "Matched from a meetup"
        let gender = detail?.basicInfo.gender?.capitalized
        let genderRaw = detail?.basicInfo.gender
        let interestLabels = detail?.interests.map(\.label) ?? []
        return HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 16) {
                DoodlePortrait(assetName: DoodleArt.portrait(forGenderString: genderRaw), size: 220)
                Text(name)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(MacPalette.ink)
                Text(meetingLabel)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
            }
            .frame(width: 260)
            VStack(alignment: .leading, spacing: 18) {
                Text(name)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                Text(meetingLabel)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                MacPanel(title: "About") {
                    Text(gender.map { "\($0). Interests are shared only after a mutual match." }
                         ?? "Interests are shared only after a mutual match.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    if let gender {
                        tagWrap([name, gender])
                    } else {
                        tagWrap([name])
                    }
                }
                HStack(spacing: 12) {
                    Text("Matches are mutual — chosen after a meetup.")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        if let match {
                            selectedChatMatchId = match.matchId
                        }
                        navigate?(.chat)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                            Text("Message")
                        }
                        .font(MacType.button)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(MacPalette.accent, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Message")
                }
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 18) {
                MacPanel(title: "You both like") {
                    if interestLabels.isEmpty {
                        Text("Interest tags load from the match profile.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                    } else {
                        tagWrap(interestLabels)
                    }
                }
                MacPanel(title: "Match status") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mutual")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(MacPalette.accent)
                        Text("You both selected each other after a meetup. No compatibility score is shown.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                    }
                }
            }
            .frame(width: 280)
        }
        .task(id: match?.matchId ?? "") {
            guard appState.isSignedIn else { return }
            if appState.soulmateMatches.isEmpty {
                await appState.fetchSoulmateStatus()
            }
            let matchId = selectedSoulmateMatchId
                ?? appState.soulmateMatches.first?.matchId
            guard let matchId else { return }
            selectedSoulmateMatchId = matchId
            do {
                soulmateMatchDetail = try await appState.fetchSoulmateMatchDetail(id: matchId)
            } catch {
                soulmateMatchDetail = nil
            }
        }
    }

    // MARK: - 13. communityMembers

    private var communityMembers: some View {
        let community = selectedCommunity
        let memberCount = filteredCommunityMembers.count
        return HStack(alignment: .top, spacing: 22) {
            MacPanel(title: community?.name ?? "Community") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Members", systemImage: "person.3.fill")
                        .font(MacType.button)
                        .foregroundStyle(MacPalette.accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MacPalette.accentSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                    Text("This screen lists members only. About, events, and settings open from community detail.")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(community?.summary ?? "")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
            }
            .frame(width: 280)
            .accessibilityLabel("Members section")
            VStack(alignment: .leading, spacing: 14) {
                MacPanel(title: "Members") {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(MacPalette.muted)
                            TextField("Search members...", text: $memberSearch)
                                .font(MacType.body)
                                .textFieldStyle(.plain)
                                .accessibilityLabel("Search members")
                        }
                        .padding(10)
                        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MacPalette.line, lineWidth: 1))
                        Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.muted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(MacPalette.surface, in: Capsule())
                            .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                            .accessibilityLabel("All members")
                    }
                    VStack(spacing: 8) {
                        if appState.communityMembers.isEmpty {
                            Text("No members have joined this community yet.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .padding(.vertical, 12)
                        } else if filteredCommunityMembers.isEmpty {
                            Text("No members match “\(memberSearch)”.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(filteredCommunityMembers, id: \.userId) { member in
                                memberRow(
                                    member.name,
                                    gender: member.gender,
                                    role: "Member" + (member.gender.map { " · \($0.capitalized)" } ?? "")
                                )
                            }
                        }
                    }
                }
            }
            .task(id: community?.id ?? "") {
                if appState.isSignedIn, let community {
                    await appState.fetchCommunityMembers(id: community.id)
                }
            }
        }
    }

    private var filteredCommunityMembers: [CommunityMember] {
        let query = memberSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appState.communityMembers }
        return appState.communityMembers.filter {
            $0.name.lowercased().contains(query)
                || ($0.gender?.lowercased().contains(query) ?? false)
        }
    }

    private func memberRow(_ name: String, gender: String?, role: String) -> some View {
        HStack(spacing: 12) {
            DoodlePortrait(assetName: DoodleArt.portrait(forGenderString: gender), size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(MacType.button)
                Text(role)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            Spacer()
        }
        .padding(8)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(role)")
    }

    // MARK: - 14. createEvent

    private var createEvent: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    compactEventTypePill("Meetup", icon: "person.3")
                    compactEventTypePill("Listening Session", icon: "waveform")
                    compactEventTypePill("Jam Session", icon: "music.note")
                }
                MacPanel(title: "Event details") {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledTextField("Event name", text: $eventName, placeholder: "Saturday Jazz Listening Session")
                        HStack(spacing: 12) {
                            labeledTextField("Date", text: $eventDate, placeholder: "2026-07-05")
                            labeledTextField("Time", text: $eventTime, placeholder: "19:00")
                                .frame(width: 130)
                        }
                        labeledTextField("Location", text: $eventLocation, placeholder: "Location")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Details")
                                .font(MacType.small.weight(.semibold))
                            TextField("What should people know?", text: $eventDetails, axis: .vertical)
                                .lineLimit(4...6)
                                .font(MacType.body)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                                .accessibilityLabel("Event details")
                        }
                        HStack(spacing: 12) {
                            Button(eventCoverAdded ? "Cover added" : "Add cover") {
                                eventCoverAdded = true
                                createEventStatus = "Jazz listening cover added to preview."
                            }
                            .buttonStyle(.bordered)
                            Button(eventTagsAdded ? "Tags added" : "Add tags") {
                                eventTagsAdded = true
                                createEventStatus = "Tags added from event type."
                            }
                            .buttonStyle(.bordered)
                        }
                        if let createEventStatus {
                            Text(createEventStatus)
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.muted)
                        }
                    }
                }
                Button(isCreatingEvent ? "Creating…" : "Create event") {
                    submitEvent()
                }
                .buttonStyle(.borderedProminent)
                .tint(MacPalette.accent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(isCreatingEvent || eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Create event")
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            MacPanel(title: "Live preview") {
                VStack(alignment: .leading, spacing: 12) {
                    if eventCoverAdded {
                        DoodleCover(assetName: DoodleArt.eventCover(eventType: eventType), height: 140, cornerRadius: 14, scrim: false)
                    } else {
                        DoodleCover(assetName: DoodleArt.eventMeetup, height: 140, cornerRadius: 14, scrim: true)
                    }
                    Text(eventName.isEmpty ? "Event name" : eventName)
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)
                    Label("\(eventDate) · \(eventTime)", systemImage: "calendar")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                    Label(eventLocation.isEmpty ? "Location" : eventLocation, systemImage: "mappin.and.ellipse")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                    if !eventDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(eventDetails)
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                            .lineLimit(4)
                    }
                    if eventTagsAdded {
                        HStack(spacing: 6) {
                            tagPill(eventType)
                            tagPill("Community hosted")
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 360)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func compactEventTypePill(_ title: String, icon: String) -> some View {
        Button { eventType = title } label: {
            Label(title, systemImage: icon)
                .font(MacType.button)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(eventType == title ? .white : MacPalette.ink)
                .background(eventType == title ? MacPalette.accent : MacPalette.surface, in: Capsule())
                .overlay(Capsule().stroke(eventType == title ? MacPalette.accent : MacPalette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityValue(eventType == title ? "Selected" : "Not selected")
    }

    private func eventTypeButton(_ title: String, icon: String, detail: String) -> some View {
        Button { eventType = title } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MacType.button)
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
                Spacer()
            }
            .padding(12)
            .background(eventType == title ? MacPalette.accentSoft.opacity(0.7) : MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(eventType == title ? MacPalette.accent : MacPalette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityValue(eventType == title ? "Selected" : "Not selected")
    }

    private func tagPill(_ title: String) -> some View {
        Text(title)
            .font(MacType.small.weight(.semibold))
            .foregroundStyle(MacPalette.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(MacPalette.accentSoft.opacity(0.55), in: Capsule())
    }

    private func labeledTextField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(MacType.small.weight(.semibold))
            TextField(placeholder, text: text)
                .font(MacType.body)
                .textFieldStyle(.plain)
                .padding(12)
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                .accessibilityLabel(label)
        }
    }

    private func submitEvent() {
        let title = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            createEventStatus = "Add an event name before creating."
            return
        }
        isCreatingEvent = true
        createEventStatus = nil
        let targetId = selectedCommunity?.id ?? appState.joinedCommunities.first?.id ?? "community"
        Task {
            if let meeting = await appState.createMeeting(
                kind: "community",
                targetId: targetId,
                title: title,
                scheduledAt: "\(eventDate)T\(eventTime):00+05:30",
                location: eventLocation,
                details: "\(eventType): \(eventDetails)"
            ) {
                selectedRecapMeetingId = meeting.id
                createEventStatus = "\(meeting.title) was created."
            } else {
                createEventStatus = appState.meetingError ?? "Event could not be created."
            }
            isCreatingEvent = false
        }
    }

    private var createCommunity: some View {
        HStack(alignment: .top, spacing: 24) {
            MacPanel(title: "Community details") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.ink)
                        TextField("Slow Sundays", text: $newCommunityName)
                            .font(MacType.body)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                            .accessibilityLabel("Community name")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.ink)
                        TextField("What should this community help people do?", text: $newCommunitySummary, axis: .vertical)
                            .font(MacType.body)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                            .accessibilityLabel("Community summary")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Themes")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.ink)
                        TextField("Books, Rituals, Reflection", text: $newCommunityThemes)
                            .font(MacType.body)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                            .accessibilityLabel("Community themes")
                    }
                    Button(isCreatingCommunity ? "Creating" : "Create community") {
                        submitCommunity()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreatingCommunity || newCommunityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newCommunitySummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Create community")
                    .accessibilityValue(createCommunityStatus ?? "Ready")

                    if let createCommunityStatus {
                        Text(createCommunityStatus)
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            MacPanel(title: "Preview") {
                communityCard(
                    Community(
                        id: "draft",
                        name: newCommunityName.isEmpty ? "Community name" : newCommunityName,
                        summary: newCommunitySummary.isEmpty ? "Summary appears here as members browse communities." : newCommunitySummary,
                        themes: draftCommunityThemes,
                        meetingFormat: "Member-led discussion",
                        membersCount: 1
                    ),
                    index: 0,
                    joined: true
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var draftCommunityThemes: [String] {
        let themes = newCommunityThemes
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return themes.isEmpty ? ["Community", "Discussion"] : Array(themes.prefix(3))
    }

    private func submitCommunity() {
        let name = newCommunityName.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = newCommunitySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !summary.isEmpty else {
            createCommunityStatus = "Add a name and summary before creating the community."
            return
        }
        isCreatingCommunity = true
        createCommunityStatus = nil
        Task {
            if let community = await appState.createCommunity(name: name, summary: summary, themes: draftCommunityThemes) {
                selectedCommunityId = community.id
                newCommunityName = ""
                newCommunitySummary = ""
                newCommunityThemes = ""
                createCommunityStatus = "\(community.name) was created and added to your communities."
                navigate?(.communityDetail)
            } else {
                createCommunityStatus = appState.communityError ?? "Community could not be created."
            }
            isCreatingCommunity = false
        }
    }

    // MARK: - 15. notifications

    private var notifications: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Notifications") {
                HStack(spacing: 8) {
                    ForEach(["All", "Unread", "Mentions"], id: \.self) { filter in
                        Button { notificationFilter = filter } label: {
                            MacPill(text: filter, isSelected: notificationFilter == filter)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(filter) notifications filter")
                        .accessibilityValue(notificationFilter == filter ? "Selected" : "Not selected")
                    }
                    Spacer()
                }
                if filteredNotifications.isEmpty {
                    Text(appState.notificationError ?? "No notifications in this filter.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(filteredNotifications) { item in
                            Button {
                                openNotification(item)
                            } label: {
                                notificationRow(item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.title)
                        }
                    }
                }
                Button("Mark all as read") {
                    readNotificationIds = Set(appState.notifications.map(\.id))
                    notificationStatus = "All notifications marked read in this view."
                }
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(MacPalette.accent)
                    .buttonStyle(.plain)
                    .underline()
                    .padding(.top, 8)
                    .accessibilityLabel("Mark all notifications as read")
            }
            MacPanel(title: "Activity") {
                HStack(spacing: 8) {
                    ForEach(["All", "Circles", "Communities"], id: \.self) { filter in
                        Button { activityFilter = filter } label: {
                            MacPill(text: filter, isSelected: activityFilter == filter)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(filter) activity filter")
                        .accessibilityValue(activityFilter == filter ? "Selected" : "Not selected")
                    }
                    Spacer()
                }
                VStack(spacing: 8) {
                    ForEach(filteredActivityItems) { item in
                        Button {
                            openActivityItem(item)
                        } label: {
                            activityRow(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                    }
                }
                Spacer()
                Divider()
                HStack(spacing: 14) {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundStyle(MacPalette.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Stay in the loop")
                            .font(MacType.button)
                        Text("Refresh pulls the latest backend notifications and activity.")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task {
                            await appState.fetchNotifications()
                            notificationStatus = "Notifications refreshed from backend."
                        }
                    }
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MacPalette.accent, in: Capsule())
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh notifications")
                }
                .padding(.top, 8)
                if let notificationStatus {
                    Text(notificationStatus)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
            }
        }
        .task {
            await appState.fetchNotifications()
        }
    }

    private var filteredNotifications: [MacNotificationItem] {
        appState.notifications.filter { item in
            switch notificationFilter {
            case "Unread":
                return !readNotificationIds.contains(item.id)
            case "Mentions":
                return item.kind == "mention"
            default:
                return true
            }
        }
    }

    private var filteredActivityItems: [MacNotificationItem] {
        appState.activityItems.filter { item in
            switch activityFilter {
            case "Circles":
                return item.kind == "meeting" || item.title.localizedCaseInsensitiveContains("circle")
            case "Communities":
                return item.kind == "community"
            default:
                return true
            }
        }
    }

    private func openNotification(_ item: MacNotificationItem) {
        readNotificationIds.insert(item.id)
        switch item.kind {
        case "meeting":
            navigate?(.meetOverview)
        case "soulmate", "message":
            navigate?(.messages)
        default:
            break
        }
    }

    private func openActivityItem(_ item: MacNotificationItem) {
        switch item.kind {
        case "meeting":
            navigate?(.meetOverview)
        case "community":
            navigate?(.communitiesBrowse)
        default:
            break
        }
    }

    private func notificationRow(_ item: MacNotificationItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind == "mention" ? "at" : "bell")
                .font(.title3)
                .foregroundStyle(MacPalette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(MacType.button)
                if let detail = item.detail {
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(item.createdAt?.prefix(10) ?? "Now")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(10)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
    }

    private func activityRow(_ item: MacNotificationItem) -> some View {
        HStack(spacing: 12) {
            MacAvatar(initials: String(item.title.prefix(1)))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(MacType.small.weight(.semibold))
                if let detail = item.detail {
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(item.createdAt?.prefix(5) ?? "")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(8)
    }

    // MARK: - 16. profileOnboarding

    private var profileOnboarding: some View {
        HStack(alignment: .top, spacing: 36) {
            MacPanel {
                VStack(alignment: .leading, spacing: 14) {
                    stepRow(number: "1", title: "About you", selected: true)
                    stepRow(number: "2", title: "Voice profile", selected: false)
                    stepRow(number: "3", title: "Join first circle", selected: false)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Progress: About you, then voice profile, then join first circle")
                Divider()
                    .padding(.vertical, 6)
                Label("Your privacy, always — we never share your data without permission.", systemImage: "shield")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Voice interview retakes run on iOS. Here you can update name, city, and gender.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            .frame(width: 300)
            MacPanel(title: "About you") {
                Text("Share a bit about yourself.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                profileField(label: "What should we call you?", text: $draftProfileName, prompt: "Your name")
                profileField(label: "Where are you based?", text: $draftProfileCity, prompt: "City")
                VStack(alignment: .leading, spacing: 7) {
                    Text("Gender")
                        .font(MacType.small.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach(Gender.allCases) { gender in
                            Button(gender.label) {
                                draftProfileGender = gender
                            }
                            .font(MacType.small.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                draftProfileGender == gender ? MacPalette.accent : MacPalette.surface,
                                in: Capsule()
                            )
                            .foregroundStyle(draftProfileGender == gender ? .white : MacPalette.ink)
                            .overlay(Capsule().stroke(MacPalette.line, lineWidth: draftProfileGender == gender ? 0 : 1))
                            .buttonStyle(.plain)
                            .accessibilityLabel(gender.label)
                            .accessibilityValue(draftProfileGender == gender ? "Selected" : "Not selected")
                        }
                    }
                }
                Text("Interests from voice profile")
                    .font(MacType.small.weight(.semibold))
                tagWrap(profileInterests.isEmpty ? ["Interests appear after voice profile"] : profileInterests.map(\.label))
                if let profileBasicsStatus {
                    Text(profileBasicsStatus)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
                Button(isSavingProfileBasics ? "Saving…" : "Continue") {
                    Task { await saveProfileBasicsAndContinue() }
                }
                    .font(MacType.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .disabled(isSavingProfileBasics || draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Continue")
            }
            .frame(width: 450)
            MacOrb()
                .frame(width: 290, height: 310)
        }
        .task {
            if appState.isSignedIn {
                await appState.loadCurrentProfile()
                seedProfileDraftsFromAppState()
            }
        }
    }

    private func profileField(label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(MacType.small.weight(.semibold))
            TextField(prompt, text: text)
                .font(MacType.body)
                .textFieldStyle(.plain)
                .padding(12)
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
                .accessibilityLabel(label)
        }
    }

    private func seedProfileDraftsFromAppState() {
        draftProfileName = profileInfo?.name ?? ""
        draftProfileCity = profileInfo?.city ?? ""
        draftProfileGender = profileInfo?.gender ?? .preferNotToSay
        profileBasicsStatus = nil
    }

    private func saveProfileBasicsAndContinue() async {
        isSavingProfileBasics = true
        profileBasicsStatus = nil
        let saved = await appState.updateProfileBasics(
            name: draftProfileName,
            city: draftProfileCity,
            gender: draftProfileGender
        )
        isSavingProfileBasics = false
        if saved {
            profileBasicsStatus = "Saved"
            navigate?(.profileSignals)
        } else {
            profileBasicsStatus = appState.loadError ?? "Profile could not be saved."
        }
    }

    private func stepRow(number: String, title: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(selected ? MacPalette.accent : MacPalette.surface)
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(MacType.small.weight(.bold))
                    .foregroundStyle(selected ? .white : MacPalette.muted)
            }
            Text(title)
                .font(MacType.button)
                .foregroundStyle(selected ? MacPalette.accent : MacPalette.ink)
        }
    }

    // MARK: - 17. settingsSoulmate

    private var settingsSoulmate: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Settings") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        Button {
                            selectedSettingsSection = section
                        } label: {
                            settingsItem(
                                section.rawValue,
                                icon: section.icon,
                                selected: selectedSettingsSection == section,
                                detail: settingsSectionDetail(section)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(section.rawValue)
                        .accessibilityValue(selectedSettingsSection == section ? "Selected" : "Not selected")
                    }
                    Divider().padding(.vertical, 4)
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        settingsItem("Log out", icon: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    Button {
                        showDeleteAccountConfirm = true
                    } label: {
                        settingsItem(isDeletingAccount ? "Deleting account" : "Delete account", icon: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeletingAccount)
                }
            }
            .frame(width: 290)
            settingsDetailPanel
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
            }
        }
        .confirmationDialog(
            "Sign out of Likeminded?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                appState.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to restore your profile and placement.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteAccountConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    _ = await appState.deleteAccount()
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your backend tester data and clears the local macOS session.")
        }
    }

    @ViewBuilder
    private var settingsDetailPanel: some View {
        switch selectedSettingsSection {
        case .account:
            MacPanel(title: "Account") {
                formLine("Name", value: appState.profile?.basicInfo?.name ?? "—")
                formLine("City", value: appState.profile?.basicInfo?.city ?? "—")
                formLine("Gender", value: appState.profile?.basicInfo?.gender.label ?? "—")
                Text("Edit name, city, and gender from Profile → Edit profile.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .padding(.top, 8)
            }
        case .privacy:
            settingsPlannedPanel(title: "Privacy & safety", detail: "Privacy controls ship in a later release.")
        case .notifications:
            settingsPlannedPanel(title: "Notifications", detail: "Notification preferences ship in a later release.")
        case .soulmate:
            soulmateSettingsPanel
        case .connectedApps:
            settingsPlannedPanel(title: "Connected apps", detail: "Third-party integrations are not available yet.")
        case .appearance:
            settingsPlannedPanel(title: "Appearance", detail: "Theme and display options are not available yet.")
        case .language:
            settingsPlannedPanel(title: "Language", detail: "Language selection is not available yet.")
        case .help:
            MacPanel(title: "Help & support") {
                Text("Voice profile retakes and full support run on iOS today. Use the Profile tab for your living profile and voice signals.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
            }
        }
    }

    private var soulmateSettingsPanel: some View {
        MacPanel(title: "Soulmate") {
            VStack(alignment: .leading, spacing: 18) {
                Toggle("Enable Soulmate", isOn: Binding(
                    get: { appState.soulmateEnabled },
                    set: { enabled in
                        Task { await appState.setSoulmateEnabled(enabled) }
                    }
                ))
                .toggleStyle(.switch)
                .tint(MacPalette.accent)
                .font(MacType.button)
                .accessibilityLabel("Enable Soulmate")
                .accessibilityValue(appState.soulmateEnabled ? "On" : "Off")
                Text(appState.soulmateEnabled
                     ? "Soulmate is on. The Soulmate tab opens Discover directly — turn this off here to hide the tab."
                     : "Turn on Soulmate to show the Soulmate tab and mutual matches after meetups.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                HStack(spacing: 12) {
                    featureCard(icon: "sparkle", title: "Intentional matches", detail: "Curated for real connection")
                    featureCard(icon: "shield.checkered", title: "Your comfort first", detail: "You set the pace")
                    featureCard(icon: "lock", title: "Private by design", detail: "Your data stays yours")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Discovery preferences")
                        .font(MacType.small.weight(.semibold))
                    formLine("Who can discover you", value: "People in my circles + circle of circles")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Age range")
                        .font(MacType.small.weight(.semibold))
                    formLine("Current preference", value: "Default beta range")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Visibility")
                        .font(MacType.small.weight(.semibold))
                    formLine("Current preference", value: "Circles only")
                }
            }
        }
    }

    private func settingsPlannedPanel(title: String, detail: String) -> some View {
        MacPanel(title: title) {
            Text(detail)
                .font(MacType.body)
                .foregroundStyle(MacPalette.muted)
        }
    }

    private func settingsSectionDetail(_ section: SettingsSection) -> String? {
        switch section {
        case .account:
            return appState.profile?.basicInfo?.name
        case .privacy, .notifications, .connectedApps, .appearance, .language:
            return "Planned"
        case .help:
            return "Use iOS support"
        case .soulmate:
            return appState.soulmateEnabled ? "On" : "Off"
        }
    }

    private func settingsItem(
        _ title: String,
        icon: String,
        selected: Bool = false,
        detail: String? = nil,
        interactive: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title)
            Spacer()
            if let detail {
                Text(detail)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
        }
        .font(MacType.button)
        .foregroundStyle(selected ? MacPalette.accent : (interactive || detail == nil ? MacPalette.ink : MacPalette.muted))
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? MacPalette.accentSoft.opacity(0.5) : .clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private func featureCard(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(MacPalette.accent)
            Text(title)
                .font(MacType.button)
            Text(detail)
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(MacPalette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MacType.button)
                Text(detail)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
        }
    }

    // MARK: - Shared Helpers

    private var pastMeets: some View {
        VStack(spacing: 8) {
            if appState.pastMeetings.isEmpty {
                Text("No past meetups yet.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .padding(.vertical, 10)
            } else {
                ForEach(appState.pastMeetings) { meeting in
                    Button {
                        selectedRecapMeetingId = meeting.id
                        navigate?(.meetRecap)
                    } label: {
                        pastMeetRow(meeting)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tagWrap(_ tags: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { MacPill(text: $0, isSelected: false) }
        }
    }

    private func signalCard(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.title3)
                .foregroundStyle(MacPalette.accent)
            Text(title)
                .font(MacType.button)
            Text(detail)
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(detail)")
    }

    private struct ProfileSignalLabel: Hashable {
        let title: String
        let value: String
    }

    private struct ProfileTraitRow: Hashable {
        let label: String
        let left: String
        let right: String
        let value: Double
    }

    private func profileSignalLabels(from signals: ProfileSignals?) -> [ProfileSignalLabel] {
        [
            ProfileSignalLabel(title: "Communication", value: displaySignal(signals?.communicationStyle?.primary)),
            ProfileSignalLabel(title: "Energy", value: displaySignal(signals?.socialEnergy)),
            ProfileSignalLabel(title: "Trust", value: displaySignal(signals?.trustPattern))
        ]
    }

    private func profileSignalCards(from signals: ProfileSignals) -> [ProfileSignalLabel] {
        [
            ProfileSignalLabel(title: "Communication", value: displaySignal(signals.communicationStyle?.primary)),
            ProfileSignalLabel(title: "Energy", value: displaySignal(signals.socialEnergy)),
            ProfileSignalLabel(title: "Trust", value: displaySignal(signals.trustPattern)),
            ProfileSignalLabel(title: "Mindset", value: displaySignal(signals.attachment)),
            ProfileSignalLabel(title: "Humor", value: displaySignal(signals.humorStyle))
        ]
    }

    private func profileTraitRows(from signals: ProfileSignals?) -> [ProfileTraitRow] {
        let bigFive = signals?.bigFive ?? ProfileSignals.BigFive()
        return [
            ProfileTraitRow(label: "Reserved / Outgoing", left: "Reserved", right: "Outgoing", value: bigFive.extraversion),
            ProfileTraitRow(label: "Analytical / Intuitive", left: "Analytical", right: "Intuitive", value: bigFive.openness),
            ProfileTraitRow(label: "Steady / Spontaneous", left: "Steady", right: "Spontaneous", value: 1 - bigFive.conscientiousness),
            ProfileTraitRow(label: "Guarded / Warm", left: "Guarded", right: "Warm", value: bigFive.agreeableness),
            ProfileTraitRow(label: "Steady mood / Reactive", left: "Steady mood", right: "Reactive", value: bigFive.neuroticism)
        ]
    }

    private func displaySignal(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "From voice profile" }
        return value
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }

    private func messageBubble(_ message: ChatMessage, mine: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(MacType.body)
                    .foregroundStyle(mine ? .white : MacPalette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        mine ? MacPalette.accent : MacPalette.background,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        !mine
                            ? RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(MacPalette.line, lineWidth: 1)
                            : nil
                    )
                HStack(spacing: 4) {
                    Text(chatTimeLabel(message.createdAt))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MacPalette.muted)
                    if mine {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(MacPalette.accent.opacity(0.7))
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 420, alignment: mine ? .trailing : .leading)
            if !mine { Spacer(minLength: 48) }
        }
    }

    private func detailEventRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                Text(subtitle)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(MacPalette.muted)
        }
        .padding(14)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        .accessibilityLabel(title)
    }

    private func pastMeetRow(_ meeting: Meeting) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                Text("\(LikemindedDate.short(meeting.scheduledAt)) · Host \(meeting.hostName)")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(MacPalette.muted)
        }
        .padding(14)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meeting.title), \(LikemindedDate.short(meeting.scheduledAt)), host \(meeting.hostName)")
    }

    private func eventRow(_ title: String, date: String, detail: String? = nil) -> some View {
        Button {
            if title.localizedCaseInsensitiveContains("Meetup") || title.localizedCaseInsensitiveContains("Night") {
                navigate?(.createEvent)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MacType.button)
                    Text([date, detail].compactMap { $0 }.joined(separator: "\n"))
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(MacPalette.muted)
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        .accessibilityLabel(title)
    }

    private func metricRow(_ items: [(String, String)]) -> some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { value, label in
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(MacPalette.accent)
                    Text(label)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func formLine(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(MacType.small.weight(.semibold))
            Text(value)
                .font(MacType.body)
                .foregroundStyle(MacPalette.muted)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 600
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct MacChatComposer: View {
    let matchId: String
    @ObservedObject var appState: MacAppState
    var placeholder: String = "Type a message..."
    @State private var text = ""
    @State private var isSending = false

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(MacType.body)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MacPalette.background, in: Capsule())
                .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                .accessibilityLabel("Message input")
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? MacPalette.accent : MacPalette.muted.opacity(0.45), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
            .accessibilityValue(canSend ? "Ready" : "Disabled")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending && !matchId.isEmpty
    }

    private func send() {
        guard canSend else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        text = ""
        Task {
            do {
                _ = try await appState.sendMessage(matchId: matchId, text: trimmed)
                await appState.loadMessages(matchId: matchId)
            } catch {
                await MainActor.run {
                    appState.messageError = "Message could not be sent."
                    text = trimmed
                }
            }
            await MainActor.run { isSending = false }
        }
    }
}

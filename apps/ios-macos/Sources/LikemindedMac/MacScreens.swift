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
    @State private var notificationStatus: String?
    @State private var profileTraitValue = 0.55
    @State private var soulmateDistance = 0.45
    @State private var newCommunityName = ""
    @State private var newCommunitySummary = ""
    @State private var newCommunityThemes = ""
    @State private var createCommunityStatus: String?
    @State private var isCreatingCommunity = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var isCallMuted = false
    @State private var callSidePanel = "Participants"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

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
            return "Good evening, \(name). Your next room is ready."
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Upcoming meetup")
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(LikemindedDate.full(meeting.scheduledAt))
                    .font(MacType.eyebrow)
                    .foregroundStyle(.white.opacity(0.75))
                Text(meeting.title)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 16) {
                Label("Host: \(meeting.hostName)", systemImage: "person.circle")
                    .font(MacType.body)
                Label("\(meeting.groupSize) participants", systemImage: "person.2")
                    .font(MacType.body)
            }
            .foregroundStyle(.white.opacity(0.85))
            Spacer()
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(height: 250)
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
                    featuredCircleCard(myCircle)
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(circle.name)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("Thoughtful · Deep · Intentional")
                    .font(MacType.body)
                    .foregroundStyle(.white.opacity(0.8))
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
            HStack(spacing: 24) {
                Label("Sunday 7pm", systemImage: "clock")
                Label("\(displayMemberCount(for: circle)) members", systemImage: "person.2")
            }
            .font(MacType.body)
            .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 240)
        .background(LinearGradient(colors: [MacPalette.accent, MacPalette.accent.opacity(0.7), MacPalette.ink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        let tone = gradientTones[index % gradientTones.count]
        return VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 6) {
                ForEach(circle.themes.prefix(3), id: \.self) { tag in
                    Text(tag)
                        .font(MacType.small.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.2), in: Capsule())
                }
            }
            Spacer()
            Text(circle.name)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text("\(displayMemberCount(for: circle)) members")
                .font(MacType.small)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(18)
        .frame(width: 240, height: 170)
        .background(LinearGradient(colors: [tone, tone.opacity(0.7), MacPalette.ink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - 4. profileEdit

    private var profileEdit: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Living profile")
                    .font(MacType.section)
                    .foregroundStyle(.white)
                HStack(spacing: 10) {
                    ForEach(["Communication", "Energy", "Trust"], id: \.self) { tab in
                        MacPill(text: tab, isSelected: tab == "Communication")
                    }
                }
                Label("Honest Communicator", systemImage: "message")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                profileSliders
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(width: 480)
            MacPanel(title: "Interests") {
                tagWrap(["Jazz", "Essays", "Psychology", "Design", "Cooking", "Movies", "Trekking"])
                Divider()
                Text("Reflection")
                    .font(MacType.section)
                Text("Your read")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MacPalette.muted)
                Text("You come alive in slow, emotionally honest conversations. You value meaning over noise.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                Button("Save profile edits") {
                    navigate?(.myProfile)
                }
                    .font(MacType.button)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(MacPalette.accent, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
        }
    }

    private var profileSliders: some View {
        VStack(spacing: 12) {
            ForEach(["Reserved / Outgoing", "Analytical / Intuitive", "Low Energy / High Energy", "Steady / Spontaneous", "Slow Trust / Fast Trust"], id: \.self) { label in
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(MacType.small)
                        .foregroundStyle(.white.opacity(0.8))
                    Slider(value: $profileTraitValue)
                        .tint(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - 5. chat

    private func chat(title: String, compact: Bool) -> some View {
        let selectedMatch = appState.soulmateMatches.first(where: { $0.matchId == selectedChatMatchId }) ?? appState.soulmateMatches.first
        return HStack(spacing: 0) {
            MacPanel(title: title) {
                ForEach(appState.soulmateMatches) { match in
                    Button {
                        selectedChatMatchId = match.matchId
                    } label: {
                        chatListRow(match, selected: match.matchId == selectedMatch?.matchId)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: compact ? 330 : 350)
            VStack(alignment: .leading, spacing: 0) {
                if let selectedMatch {
                    HStack {
                        MacAvatar(initials: String(selectedMatch.name.prefix(1)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedMatch.name)
                                .font(MacType.button)
                            Text("Online")
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.accent)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    Divider()
                }
                if appState.chatMessages.isEmpty {
                    VStack {
                        Spacer()
                        Text(appState.messageError ?? "No backend messages yet.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(appState.chatMessages) { message in
                                messageBubble(message.text, mine: message.senderId == appState.authSession?.userId)
                            }
                        }
                        .padding(20)
                    }
                }
                Divider()
                MacChatComposer(matchId: selectedMatch?.matchId ?? "", appState: appState)
            }
            .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous))
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
                selectedChatMatchId = selectedChatMatchId ?? appState.soulmateMatches.first?.matchId
                if let matchId = selectedChatMatchId {
                    await appState.loadMessages(matchId: matchId)
                }
            }
        }
        .task(id: selectedChatMatchId) {
            if let matchId = selectedChatMatchId {
                await appState.loadMessages(matchId: matchId)
            }
        }
    }

    private func chatListRow(_ match: SoulmateMatch, selected: Bool) -> some View {
        HStack(spacing: 12) {
            MacAvatar(initials: String(match.name.prefix(1)))
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(match.name)
                    .font(MacType.button)
                Text("Hey, how was your week?")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .lineLimit(1)
            }
            Spacer()
            Text(match.createdAt.prefix(10))
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(10)
        .background(selected ? MacPalette.accentSoft.opacity(0.55) : MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? MacPalette.accent : MacPalette.line, lineWidth: 1))
    }

    // MARK: - 6. communitiesBrowse

    private var communitiesBrowse: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MacPalette.muted)
                        .font(MacType.body)
                    TextField("Search communities...", text: $communitySearch)
                        .font(MacType.body)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MacPalette.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(["All", "Trending", "Nearby", "New"], id: \.self) { filter in
                        Button {
                            communityFilter = filter
                        } label: {
                            MacPill(text: filter, isSelected: communityFilter == filter)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(filter) communities filter")
                        .accessibilityValue(communityFilter == filter ? "Selected" : "Not selected")
                    }
                }
                Button {
                    navigate?(.createCommunity)
                } label: {
                    createCommunityCard
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create a community")
            }
            .frame(width: 280)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 280), spacing: 18, alignment: .leading)], alignment: .leading, spacing: 18) {
                ForEach(Array(filteredCommunities.enumerated()), id: \.element.id) { index, community in
                    communityTile(community, index: index)
                }
            }
            .frame(maxWidth: .infinity)
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
        let gradient = communityGradients[index % communityGradients.count]
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [gradient.0, gradient.1], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 140)
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
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    FlowLayout(spacing: 5) {
                        ForEach(community.themes.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(MacType.small.weight(.medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                    }
                }
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
        VStack(spacing: 14) {
            Image(systemName: "plus.circle")
                .font(.system(size: 36))
                .foregroundStyle(MacPalette.accent)
            Text("Create a community")
                .font(MacType.button)
                .foregroundStyle(MacPalette.accent)
            Text("Start a space for people who vibe with your interests.")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        .frame(minHeight: 230)
    }

    // MARK: - 7. communityDetail / circleDetail

    private func communityDetail(memberMode: Bool) -> some View {
        let backendCircle = memberMode ? appState.circleDetail : nil
        let community = selectedCommunity
        let themes = backendCircle?.themes ?? community?.themes ?? []
        let isJoined = community.map(isCommunityJoined) ?? true
        return HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [MacPalette.accent, MacPalette.sage.opacity(0.7), MacPalette.ink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(backendCircle?.name ?? (memberMode ? "The Thinkers' Room" : community?.name ?? "Community"))
                                .font(.system(size: 28, weight: .semibold, design: .serif))
                                .foregroundStyle(.white)
                            Text(backendCircle?.placementReason ?? (memberMode ? "Analytical · Calm · Curious" : community?.summary ?? "Listen, share, explore."))
                                .font(MacType.body)
                                .foregroundStyle(.white.opacity(0.8))
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
                    statItem("person.2", "\(community?.membersCount ?? backendCircle?.membersOnline ?? 18) members")
                    statItem("calendar", "Next meetup\nSat, Jul 5 - 7:00 PM")
                    statItem("person.crop.circle", "Host\nMarco")
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

            MacPanel(title: memberMode ? "Moderators" : "About") {
                Text(backendCircle?.placementReason ?? (memberMode ? "Your seeded host group keeps the room thoughtful." : community?.summary ?? "A seeded community from the validation database."))
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
        .task {
            if memberMode, appState.circleDetail == nil {
                await appState.fetchCircles()
            }
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
            eventRow("Community Meetup", date: "Sat, Jul 5 - 7:00 PM", detail: "Jazz & Music Lounge, Koramangala")
            eventRow("Vinyl Listening Night", date: "Sat, Jul 19 - 6:30 PM", detail: "Marco's Place")
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
                            navigate?(.messages)
                        }
                            .font(MacType.small.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(MacPalette.accent, in: Capsule())
                            .foregroundStyle(.white)
                            .buttonStyle(.plain)
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
                let initials = String(name.prefix(1))
                let location = profile.basicInfo?.city ?? "Your location"
                profileCard(name: name, initials: initials, location: location, profile: profile)
                VStack(spacing: 18) {
                    MacPanel(title: editing ? "Your personality signals" : "Personality signals") {
                        HStack(spacing: 10) {
                            ForEach(["Communication", "Energy", "Trust", "Mindset", "Creativity"], id: \.self) { signalCard($0) }
                        }
                    }
                    MacPanel(title: "Top interests") {
                        let interests = profile.interests.map { $0.label }
                        tagWrap(Array(interests.prefix(5)) + (interests.count > 5 ? ["+\(interests.count - 5)"] : []))
                    }
                    MacPanel(title: "My vibe") {
                        Text(profile.profileSummary ?? "")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                    }
                }
            } else if appState.isSignedIn {
                MacPanel(title: appState.isLoading ? "Loading profile..." : "Profile not ready") {
                    Text(appState.loadError ?? "Complete your voice profile to see your placement, interests, and private signals here.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
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
            }
        }
    }

    private func profileCard(name: String, initials: String, location: String, profile: UserProfile) -> some View {
        MacPanel(dark: true) {
            VStack(spacing: 15) {
                MacAvatar(initials: initials, color: MacPalette.accentSoft)
                    .scaleEffect(2.1)
                    .padding(.top, 20)
                Text(name)
                    .font(MacType.title)
                Label(location, systemImage: "mappin")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                MacPill(text: "Voice profile active", isSelected: true)
                Text(profile.profileSummary ?? "")
                    .font(MacType.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MacPalette.muted)
                Button("Share profile") {
                    navigate?(.profileSignals)
                }
                    .font(MacType.button)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(MacPalette.accent, in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 310)
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
                Toggle("Enable Soulmate", isOn: Binding(
                    get: { appState.soulmateEnabled },
                    set: { enabled in
                        Task { await appState.setSoulmateEnabled(enabled) }
                    }
                ))
                .toggleStyle(.switch)
                .tint(MacPalette.sage)
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
            MacPanel(title: "Filters") {
                VStack(alignment: .leading, spacing: 14) {
                    formLine("Age range", value: "24 to 32")
                    Slider(value: $soulmateDistance)
                        .tint(MacPalette.accent)
                    formLine("Distance", value: "25 km")
                    tagWrap(["Jazz", "Books", "Design"])
                    MacPill(text: "Active this week")
                }
            }
            .frame(width: 250)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                MacPill(text: "All", isSelected: true)
                MacPill(text: "Nearby")
                MacPill(text: "Interests")
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
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                    ForEach(appState.soulmateMatches) { match in
                        Button {
                            navigate?(.soulmateDetail)
                        } label: {
                            matchCard(match)
                        }
                        .buttonStyle(.plain)
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
            if appState.isSignedIn && appState.soulmateEnabled {
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private func matchCard(_ match: SoulmateMatch) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                Text("\(match.name), \(match.userId.prefix(2))")
                    .font(MacType.button)
                Text("Designer · Bangalore")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                Label("5 km away", systemImage: "location")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                FlowLayout(spacing: 5) {
                    ForEach(["Jazz", "Books", "Film"], id: \.self) { tag in
                        Text(tag)
                            .font(MacType.small.weight(.medium))
                            .foregroundStyle(MacPalette.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MacPalette.accentSoft, in: Capsule())
                    }
                }
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
        .frame(minHeight: 330)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    // MARK: - 12. soulmateDetail

    private var soulmateDetail: some View {
        let match = appState.soulmateMatches.first
        let name = match?.name ?? "Soulmate match"
        let meetingLabel = match?.meetingDate.map { "Met \(LikemindedDate.short($0))" } ?? "Matched from a seeded meetup"
        return HStack(alignment: .top, spacing: 24) {
            ZStack(alignment: .center) {
                LinearGradient(colors: [MacPalette.clay.opacity(0.8), MacPalette.accent.opacity(0.7), MacPalette.ink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 12) {
                    Text(String(name.prefix(1)))
                        .font(.system(size: 64, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text(name)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text(meetingLabel)
                        .font(MacType.body)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 360, height: 410)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 18) {
                Text(name)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                Text(meetingLabel)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                MacPanel(title: "About") {
                    Text("Seeded match from the validation database. Open messages to continue the conversation.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    tagWrap(match.map { match in [match.name, match.meetingDate.map { LikemindedDate.short($0) }].compactMap { $0 } } ?? [])
                }
                HStack(spacing: 12) {
                    Text("Matches are mutual — chosen after a meetup.")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
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
                }
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 18) {
                MacPanel(title: "You both like") {
                    tagWrap(match.map { match in [match.name, match.meetingDate.map { LikemindedDate.short($0) }, "Mutual selection"].compactMap { $0 } } ?? [])
                }
                MacPanel(title: "Compatibility") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("92%")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(MacPalette.accent)
                        Text("Your vibes align in energy, values and communication.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                    }
                }
            }
            .frame(width: 280)
        }
    }

    // MARK: - 13. communityMembers

    private var communityMembers: some View {
        let community = selectedCommunity
        return HStack(alignment: .top, spacing: 22) {
            MacPanel(title: community?.name ?? "Community") {
                VStack(alignment: .leading, spacing: 4) {
                    navItem("About", icon: "info.circle")
                    navItem("Events", icon: "calendar")
                    navItem("Members", icon: "person.3.fill", selected: true)
                    navItem("Resources", icon: "book")
                    navItem("Highlights", icon: "star")
                    navItem("Settings", icon: "gearshape")
                }
            }
            .frame(width: 280)
            VStack(alignment: .leading, spacing: 14) {
                MacPanel(title: "Members") {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(MacPalette.muted)
                            TextField("Search members...", text: $memberSearch)
                                .font(MacType.body)
                                .textFieldStyle(.plain)
                        }
                        .padding(10)
                        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MacPalette.line, lineWidth: 1))
                        HStack(spacing: 6) {
                            MacPill(text: "All", isSelected: true)
                            MacPill(text: "Active now", isSelected: false)
                            MacPill(text: "Most active", isSelected: false)
                        }
                    }
                    VStack(spacing: 8) {
                        if appState.communityMembers.isEmpty {
                            Text("No members have joined this community yet.")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .padding(.vertical, 12)
                        } else {
                            ForEach(Array(filteredCommunityMembers.enumerated()), id: \.element.userId) { index, member in
                                memberRow(
                                    member.name,
                                    role: "Member" + (member.gender.map { " · \($0.capitalized)" } ?? ""),
                                    active: false,
                                    isHost: index == 0
                                )
                            }
                        }
                    }
                }
            }
            .task {
                if appState.isSignedIn, let community {
                    await appState.fetchCommunityMembers(id: community.id)
                }
            }
            .task(id: community?.id ?? "") {
                if appState.isSignedIn, let community {
                    await appState.fetchCommunityMembers(id: community.id)
                }
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
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

    private func navItem(_ title: String, icon: String, selected: Bool = false) -> some View {
        Label(title, systemImage: icon)
            .font(MacType.button)
            .foregroundStyle(selected ? MacPalette.accent : MacPalette.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? MacPalette.accentSoft.opacity(0.5) : .clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private func memberRow(_ name: String, role: String, active: Bool, isHost: Bool) -> some View {
        HStack(spacing: 12) {
            MacAvatar(initials: String(name.prefix(1)))
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(MacType.button)
                    if active {
                        Circle()
                            .fill(MacPalette.accent)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(role)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            Spacer()
            if isHost {
                MacPill(text: "Host", isSelected: true)
            } else {
                Text("...")
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.muted)
            }
        }
        .padding(8)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
    }

    // MARK: - 14. createEvent

    private var createEvent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Community-created events are coming soon.")
                .font(MacType.title)
                .foregroundStyle(MacPalette.ink)
            Text("Today, Likeminded schedules circle and community meetups for you. Member-hosted events are on the roadmap once the placement loop matures.")
                .font(MacType.body)
                .foregroundStyle(MacPalette.muted)
                .frame(maxWidth: 520, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    MacPill(text: "All", isSelected: true)
                    MacPill(text: "Unread", isSelected: false)
                    MacPill(text: "Mentions", isSelected: false)
                    Spacer()
                }
                if appState.notifications.isEmpty {
                    Text(appState.notificationError ?? "No backend notifications yet.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .padding(.vertical, 20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(appState.notifications) { item in
                            notificationRow(item)
                        }
                    }
                }
                Button("Mark all as read") {
                    appState.notifications = []
                }
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(MacPalette.accent)
                    .buttonStyle(.plain)
                    .underline()
                    .padding(.top, 8)
            }
            MacPanel(title: "Activity") {
                HStack(spacing: 8) {
                    MacPill(text: "All", isSelected: true)
                    MacPill(text: "Circles", isSelected: false)
                    MacPill(text: "Communities", isSelected: false)
                    Spacer()
                }
                VStack(spacing: 8) {
                    ForEach(appState.activityItems) { item in
                        activityRow(item)
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
                        Text("Enable notifications to never miss a vibe.")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                    }
                    Spacer()
                    Button("Enable") {
                        Task {
                            await appState.fetchNotifications()
                            notificationStatus = "Notifications refreshed"
                        }
                    }
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MacPalette.accent, in: Capsule())
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
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
                Divider()
                    .padding(.vertical, 6)
                Label("Your privacy, always — we never share your data without permission.", systemImage: "shield")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 300)
            MacPanel(title: "About you") {
                formLine("What should we call you?", value: profileInfo?.name ?? "Your name")
                formLine("Where are you based?", value: profileInfo?.city ?? "Not set")
                formLine("Gender", value: profileInfo?.gender.label ?? "Not set")
                Text("Pick your interests")
                    .font(MacType.small.weight(.semibold))
                tagWrap(profileInterests.isEmpty ? ["Add interests in your profile"] : profileInterests.map(\.label))
                Button("Continue") {
                    navigate?(.profileSignals)
                }
                    .font(MacType.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
            .frame(width: 450)
            MacOrb()
                .frame(width: 290, height: 310)
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
                    settingsItem("Account", icon: "person.circle", detail: "Current")
                    settingsItem("Privacy & safety", icon: "shield", detail: "Planned")
                    settingsItem("Notifications", icon: "bell", detail: "Planned")
                    settingsItem("Soulmate", icon: "heart.fill", selected: true)
                    settingsItem("Voice profile", icon: "waveform", detail: "Profile tab")
                    settingsItem("Connected apps", icon: "square.grid.2x2", detail: "Planned")
                    settingsItem("Appearance", icon: "sun.max", detail: "Planned")
                    settingsItem("Language", icon: "globe", detail: "Planned")
                    settingsItem("Help & support", icon: "questionmark.circle", detail: "Use iOS support")
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

    private func settingsItem(_ title: String, icon: String, selected: Bool = false, detail: String? = nil) -> some View {
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
        .foregroundStyle(selected ? MacPalette.accent : (detail == nil ? MacPalette.ink : MacPalette.muted))
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
                        eventRow(meeting.title, date: meeting.hostName)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func tagWrap(_ tags: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { MacPill(text: $0, isSelected: ["Jazz", "Essays", "Psychology"].contains($0)) }
        }
    }

    private func signalCard(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkle")
                .font(.title3)
                .foregroundStyle(MacPalette.accent)
            Text(title)
                .font(MacType.button)
            Text("Calm & steady")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private func messageBubble(_ text: String, mine: Bool) -> some View {
        HStack {
            if mine { Spacer() }
            Text(text)
                .font(MacType.body)
                .foregroundStyle(mine ? .white : MacPalette.ink)
                .padding(14)
                .background(mine ? MacPalette.accent : MacPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: 360, alignment: mine ? .trailing : .leading)
                .overlay(
                    !mine ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MacPalette.line, lineWidth: 1) : nil
                )
            if !mine { Spacer() }
        }
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
    @State private var text = ""
    @State private var isSending = false

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $text, axis: .vertical)
                .font(MacType.body)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(12)
                .background(MacPalette.surface, in: Capsule())
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? MacPalette.accent : MacPalette.muted)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(16)
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

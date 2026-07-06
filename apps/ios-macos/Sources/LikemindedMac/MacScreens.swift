import SwiftUI

private enum MacSettingsPane: String, CaseIterable, Identifiable {
    case account
    case privacy
    case notifications
    case soulmate
    case connectedApps
    case appearance
    case language
    case helpSupport
    case howItWorks

    var id: String { rawValue }

    static var sidebarCases: [MacSettingsPane] {
        allCases.filter { $0 != .howItWorks }
    }

    var title: String {
        switch self {
        case .account: "Account"
        case .privacy: "Privacy & safety"
        case .notifications: "Notifications"
        case .soulmate: "Soulmate"
        case .connectedApps: "Connected apps"
        case .appearance: "Appearance"
        case .language: "Language"
        case .helpSupport: "Help & support"
        case .howItWorks: "How Soulmate works"
        }
    }

    var icon: String {
        switch self {
        case .account: "person.circle"
        case .privacy: "shield"
        case .notifications: "bell"
        case .soulmate: "heart.fill"
        case .connectedApps: "square.grid.2x2"
        case .appearance: "sun.max"
        case .language: "globe"
        case .helpSupport: "questionmark.circle"
        case .howItWorks: "heart.text.square"
        }
    }

    static func fromLaunchArgument() -> MacSettingsPane? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--mac-settings-pane"),
              args.indices.contains(index + 1) else { return nil }
        return MacSettingsPane(rawValue: args[index + 1])
    }
}

private enum CommunityResourceDetail: String, Identifiable {
    case guidelines
    case prompts
    case essayThread
    case recommendation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guidelines: "Community guidelines"
        case .prompts: "Conversation prompts"
        case .essayThread: "Best essay thread"
        case .recommendation: "Most saved recommendation"
        }
    }
}

private struct MacSettingsInfoSection: Identifiable {
    let eyebrow: String
    let icon: String
    let title: String
    let bullets: [String]

    var id: String { eyebrow }
}

private enum MacSettingsInfoContent {
    static let soulmatePrivacyNote =
        "Your privacy is built in. Selections are private and visible only to admins after the window closes."

    static let howSoulmateWorks: [MacSettingsInfoSection] = [
        MacSettingsInfoSection(
            eyebrow: "Opt in",
            icon: "heart",
            title: "Turn Soulmate on",
            bullets: [
                "Go to Settings and enable Soulmate.",
                "Only visible when enabled.",
                "You can turn it off anytime."
            ]
        ),
        MacSettingsInfoSection(
            eyebrow: "Choose after meetups",
            icon: "person.2",
            title: "Post-meet selection",
            bullets: [
                "After a meetup, select the people you'd like to connect with.",
                "Your choices stay private.",
                "Selections close after 24 hours."
            ]
        ),
        MacSettingsInfoSection(
            eyebrow: "Chat when mutual",
            icon: "bubble.left.and.bubble.right",
            title: "Mutual matches create chat",
            bullets: [
                "If they select you too, it's a match!",
                "You'll unlock a chat to get to know each other better.",
                "No match? No worries. It stays private."
            ]
        )
    ]

    static let helpFAQ: [MacSettingsInfoSection] = [
        MacSettingsInfoSection(
            eyebrow: "Voice profile",
            icon: "waveform",
            title: "Build your signals",
            bullets: [
                "Complete onboarding, then start the voice interview from Profile.",
                "Retake it when your circle placement feels off."
            ]
        ),
        MacSettingsInfoSection(
            eyebrow: "Meetups",
            icon: "calendar",
            title: "Saturday and Sunday rooms",
            bullets: [
                "Saturday is community-focused; Sunday is circle-focused.",
                "RSVPs and scheduled rooms sync through the backend."
            ]
        ),
        MacSettingsInfoSection(
            eyebrow: "Troubleshooting",
            icon: "wrench.and.screwdriver",
            title: "When data looks stale",
            bullets: [
                "Sign out and sign back in to refresh your profile.",
                "Use Contact support to send a DB-backed tester note."
            ]
        )
    ]
}

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
    @State private var circleDetailTab = "About"
    @State private var showCircleOptions = false
    @State private var communityDetailStatus: String?
    @State private var memberSearch = ""
    @State private var memberActivityFilter = "All"
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
    @State private var selectedSoulmateMatchId: String?
    @State private var discoverFilterUnmetOnly = true
    @State private var discoverFilterActiveWeek = false
    @State private var soulmateMatchDetail: SoulmateMatchDetail?
    @State private var showAllInterests = false
    @State private var draftProfileName = ""
    @State private var draftProfileCity = ""
    @State private var draftProfileGender: Gender = .preferNotToSay
    @State private var draftProfileDateOfBirth = Date()
    @State private var draftProfilePincode = ""
    @State private var isSavingProfileBasics = false
    @State private var profileBasicsStatus: String?
    @State private var newCommunityName = ""
    @State private var newCommunitySummary = ""
    @State private var newCommunityThemes = ""
    @State private var createCommunityStatus: String?
    @State private var isCreatingCommunity = false
    @State private var eventType = "Meetup"
    @State private var eventName = "Saturday Jazz Listening Session"
    @State private var eventDate = "Sat, Jul 5, 2025"
    @State private var eventTime = "7:00 PM"
    @State private var eventLocation = "The Listening Room, Brooklyn, NY"
    @State private var eventDetails = "Join us for a relaxed afternoon of jazz listening and good conversation. We'll explore classic albums, hidden gems, and stories behind the music."
    @State private var eventCoverAdded = false
    @State private var eventTagsAdded = true
    @State private var createEventStatus: String?
    @State private var isCreatingEvent = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    @State private var isCallMuted = false
    @State private var callSidePanel = "Participants"
    @State private var selectedSettingsPane: MacSettingsPane = MacScreenView.initialSettingsPane()
    @State private var profileOnboardingStep = Self.initialProfileOnboardingStep()

    private static func initialProfileOnboardingStep() -> Int {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--likeminded-dev-profile-empty") {
            return 2
        }
        #endif
        return 1
    }
    @State private var soulmatePrefsStatus: String?
    @State private var isSavingSoulmatePrefs = false
    @State private var supportNote = ""
    @State private var isSendingSupport = false
    @State private var supportStatus: String?
    @State private var showCommunityOptions = false
    @State private var communityResourceDetail: CommunityResourceDetail?
    @State private var appleSignInController = AppleSignInController()
    @StateObject private var liveKitSession = LiveKitMeetSession()
    @State private var showChatCallSheet = false
    @State private var chatCallMode = "voice"
    @State private var chatActionStatus: String?
    @State private var voiceReflectionPromptIndex = 0
    @State private var voiceReflectionDraft = ""
    @State private var voiceReflectionAnswers: [String] = []
    @State private var voiceReflectionStatus: String?
    @State private var isSavingVoiceReflection = false
    @State private var draftOnboardingInterests: Set<String> = ["Jazz", "Books"]

    private let onboardingInterestOptions = ["Jazz", "Books", "Design", "Travel", "Coffee", "Writing", "Mindfulness"]

    private let voiceReflectionPrompts = [
        "What has felt most energizing in your social life lately?",
        "How do you prefer to open up with new people?",
        "What topics or hobbies could you talk about for hours?"
    ]

    var body: some View {
        Group {
            if screen == .welcome {
                content
            } else if screen == .chat || screen == .messages || screen == .circleDetail || screen == .communityMembers || screen == .createEvent || screen == .meetVideoCall {
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
        if screen == .meetRecap, let meeting = currentRecapMeeting {
            return "You attended \(meeting.title) on \(LikemindedDate.full(meeting.scheduledAt))."
        }
        if screen == .circleDetail, let circle = appState.circleDetail {
            return circle.placementReason
        }
        guard screen == .meetOverview, appState.isSignedIn else { return screen.subtitle }
        if let first = appState.profileFirstName {
            return "Good evening, \(first) 👋"
        }
        return "Your next room is ready."
    }

    private var dynamicTitle: String {
        switch screen {
        case .communityDetail, .communityMembers:
            return selectedCommunity?.name ?? screen.title
        case .circleDetail:
            return appState.circleDetail?.name ?? screen.title
        case .soulmateDetail:
            return screen.title
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
        case .profileSignals: profileSignals
        case .circleDetail: communityDetail(memberMode: true)
        case .settingsSoulmate: settingsSoulmate
        case .createCommunity: createCommunity
        }
    }

    // MARK: - 1. welcome

    private var welcome: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: 392)
                MacConvergenceField()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(x: 1.08, y: 1.04, anchor: .center)
            }
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 28) {
                Text("Likeminded")
                    .font(.system(size: 25, weight: .semibold, design: .serif))
                    .foregroundStyle(MacPalette.accent)
                VStack(alignment: .leading, spacing: 8) {
                    Text("When you meet,\nit matters.")
                        .font(.system(size: 44, weight: .semibold, design: .serif))
                        .lineSpacing(1)
                        .foregroundStyle(MacPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("AI helps you meet the right people in the right rooms.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "waveform", title: "Voice profile", detail: "Speak naturally. We understand you.", accessibilityLabel: "Voice profile")
                    featureRow(icon: "shield.lefthalf.filled", title: "Private by design", detail: "Your data is yours. Always.", accessibilityLabel: "Private by design")
                    featureRow(icon: "person.3", title: "Circle placement", detail: "We place you where you'll belong.", accessibilityLabel: "Circle placement")
                }
                .padding(.vertical, 8)
                AuthAppleSignInButton(style: .black, isAuthenticating: appState.isAuthenticating) {
                    Task { await appState.signInWithApple(using: appleSignInController) }
                }

                SocialAuthButtonsView(
                    isAuthenticating: appState.isAuthenticating,
                    titleColor: MacPalette.ink,
                    borderColor: MacPalette.line,
                    onGoogleSignIn: { Task { await appState.signInWithGoogle() } },
                    onMetaMaskSignIn: { Task { await appState.signInWithWallet(.metamask, controller: WalletSignInController()) } },
                    onSolflareSignIn: { Task { await appState.signInWithWallet(.solflare, controller: WalletSignInController()) } }
                )
                if appState.isAuthenticating {
                    ProgressView("Signing in")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }

                if let authError = appState.authError {
                    Text(authError)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.clay)
                }

                AuthTermsFooter(
                    accent: MacPalette.accent,
                    muted: MacPalette.muted
                )
            }
            .frame(width: 390)
            .padding(.leading, 42)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 600, maxHeight: .infinity, alignment: .topLeading)
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
                await appState.refreshProfileDisplay()
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
                callStatus(
                    icon: liveKitSession.isConnected ? "dot.radiowaves.left.and.right" : "video.fill",
                    title: liveKitSession.statusMessage,
                    detail: liveKitSession.isPrototypeFallback ? "Using preview tiles" : "Everyone's camera is on"
                )
                callStatus(icon: "person.2", title: "\(meeting?.groupSize ?? 10) participants", detail: nil)
            }

            if let error = liveKitSession.errorMessage, liveKitSession.isPrototypeFallback {
                Text("Live room unavailable: \(error)")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.clay)
                    .fixedSize(horizontal: false, vertical: true)
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
                            let visible = Array(callParticipants.prefix(7))
                            let overflow = max(0, callParticipants.count - visible.count)
                            ForEach(visible, id: \.self) { participant in
                                HStack(spacing: 10) {
                                    MacAvatar(initials: String(participant.prefix(1)), size: 32)
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
                            if overflow > 0 {
                                HStack(spacing: 8) {
                                    HStack(spacing: -8) {
                                        ForEach(Array(callParticipants.dropFirst(visible.count).prefix(3)), id: \.self) { name in
                                            MacAvatar(initials: String(name.prefix(1)), size: 24)
                                                .overlay(Circle().stroke(MacPalette.surface, lineWidth: 2))
                                        }
                                    }
                                    Text("+\(overflow) more")
                                        .font(MacType.small)
                                        .foregroundStyle(MacPalette.muted)
                                    Spacer()
                                }
                                .accessibilityLabel("\(overflow) more participants")
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
        .task(id: appState.upcomingMeetings.first?.id) {
            if appState.upcomingMeetings.isEmpty {
                await appState.fetchMeetings()
            }
            await connectLiveKitIfNeeded(for: appState.upcomingMeetings.first)
        }
        .onDisappear {
            Task { await liveKitSession.disconnect() }
        }
    }

    private func connectLiveKitIfNeeded(for meeting: Meeting?) async {
        guard let meeting else { return }
        do {
            let join = try await appState.joinMeeting(id: meeting.id)
            await liveKitSession.connect(url: join.url, token: join.token)
        } catch {
            liveKitSession.errorMessage = error.localizedDescription
            await liveKitSession.connect(url: "", token: "")
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
                Task { await liveKitSession.setMuted(!liveKitSession.isMuted) }
            } label: {
                Label(liveKitSession.isMuted ? "Unmute mic" : "Mute mic", systemImage: liveKitSession.isMuted ? "mic.slash.fill" : "mic.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: 56, height: 56)
                    .background(MacPalette.accent, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(liveKitSession.isMuted ? "Unmute microphone" : "Mute microphone")
            .accessibilityValue(liveKitSession.isMuted ? "Muted" : "Unmuted")
            Label(liveKitSession.isConnected ? "LiveKit connected" : "Preview room", systemImage: "cellularbars")
                .font(MacType.button)
                .foregroundStyle(MacPalette.ink)
            Button("Leave") {
                Task {
                    await liveKitSession.disconnect()
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
                let display = circleDisplay(myCircle, index: 0)
                HStack(alignment: .top, spacing: 18) {
                    Button {
                        openCircleDetail(myCircle)
                    } label: {
                        featuredCircleCard(myCircle)
                            .contentShape(Rectangle())
                            .accessibilityHidden(true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open your circle \(display.name)")
                    .accessibilityInputLabels(["Open your circle \(myCircle.name)"])
                    .accessibilityIdentifier("hero-circle-macos")
                    .accessibilityAddTraits(.isButton)
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
        let display = circleDisplay(circle, index: 0)
        return ZStack(alignment: .bottomLeading) {
            DoodleCover(assetName: DoodleArt.circle(circle.id), height: 240, cornerRadius: 18, scrimStyle: .heroOverlay)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(display.name)
                        .font(MacType.coverTitle)
                        .foregroundStyle(.white)
                    Text(display.subtitle)
                        .font(MacType.coverMeta)
                        .foregroundStyle(.white.opacity(0.92))
                }
                FlowLayout(spacing: 8) {
                    ForEach(display.tags, id: \.self) { tag in
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
                    Label("\(display.members) members", systemImage: "person.2")
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

    private func openCircleDetail(_ circle: PlacementCircle) {
        appState.circleDetail = circle
        navigate?(.circleDetail)
        Task { await appState.loadCircleDetail(id: circle.id) }
    }

    private func circleCardButton(_ circle: PlacementCircle, index: Int) -> some View {
        let display = circleDisplay(circle, index: index + 1)
        return Button {
            openCircleDetail(circle)
        } label: {
            circleCard(circle, index: index)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(display.name) circle")
        .accessibilityValue("\(display.members) members")
    }

    private func circleCard(_ circle: PlacementCircle, index: Int) -> some View {
        let display = circleDisplay(circle, index: index + 1)
        return ZStack(alignment: .bottomLeading) {
            DoodleCover(assetName: DoodleArt.circle(circle.id), height: 170, cornerRadius: 18, scrimStyle: .bottomBand)
            VStack(alignment: .leading, spacing: 4) {
                Text(display.name)
                    .font(MacType.coverTitleSmall)
                    .foregroundStyle(.white)
                Text(display.subtitle)
                    .font(MacType.small)
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(display.members) members")
                    .font(MacType.coverMeta)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .doodleOverlayText()
            .padding(18)
        }
        .frame(width: 240, height: 170)
    }

    private func circleDisplay(_ circle: PlacementCircle, index: Int) -> (name: String, subtitle: String, tags: [String], members: Int) {
        let displays = [
            ("The Quiet Builders", "Thoughtful - Deep - Intentional", ["Honesty", "Depth", "Growth", "Mindset"], 12),
            ("Open Hearts", "Warm - Expressive - Supportive", ["Warm", "Expressive", "Supportive"], 18),
            ("The Thinkers' Room", "Analytical - Calm - Curious", ["Analytical", "Calm", "Curious"], 22),
            ("Visionaries", "Vision - Ambitious - Growth", ["Vision", "Ambitious", "Growth"], 16),
            ("Kindred Souls", "Creative - Gentle - Authentic", ["Creative", "Gentle", "Authentic"], 20),
            ("The Explorers", "Adventurous - Bold - Spontaneous", ["Adventurous", "Bold", "Spontaneous"], 14)
        ]
        if displays.indices.contains(index) { return displays[index] }
        return (circle.name, circle.roomEnergy, Array(circle.themes.prefix(4)), displayMemberCount(for: circle))
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

    private var chatMatchesSource: [SoulmateMatch] {
        if MacMessagesFixtures.isActive { return MacMessagesFixtures.matches }
        if MacChatFixtures.isActive { return MacChatFixtures.matches }
        if !appState.soulmateMatches.isEmpty { return appState.soulmateMatches }
        return []
    }

    private var chatFixturesActive: Bool {
        MacMessagesFixtures.isActive || MacChatFixtures.isActive
    }

    private var filteredChatMatches: [SoulmateMatch] {
        var matches = chatMatchesSource
        if chatFilter == "Unread" {
            matches = matches.filter { !readChatMatchIds.contains($0.matchId) }
        } else if chatFilter == "Groups" {
            matches = []
        }
        let query = chatSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            matches = matches.filter { match in
                chatDisplayName(match.name).lowercased().contains(query)
                    || match.name.lowercased().contains(query)
                    || (appState.chatPreviews[match.matchId]?.text.lowercased().contains(query) ?? false)
            }
        }
        return matches.sorted { chatMatchSortIndex($0.name) < chatMatchSortIndex($1.name) }
    }

    private func preferredChatMatchId() -> String? {
        if MacMessagesFixtures.isActive {
            return chatMatchesSource.first(where: { chatDisplayName($0.name) == "Ananya" })?.matchId
                ?? chatMatchesSource.first?.matchId
        }
        if let arjun = chatMatchesSource.first(where: { chatDisplayName($0.name) == "Arjun" }) {
            return arjun.matchId
        }
        return filteredChatMatches.first?.matchId ?? chatMatchesSource.first?.matchId
    }

    private func activeChatMessages(for match: SoulmateMatch?) -> [ChatMessage] {
        guard let match else { return [] }
        if MacMessagesFixtures.isActive, match.matchId.hasPrefix("fixture-") {
            return MacMessagesFixtures.messages(for: match.matchId, currentUserId: appState.authSession?.userId)
        }
        if MacChatFixtures.isActive, match.matchId.hasPrefix("fixture-") {
            return MacChatFixtures.messages(for: match.matchId, currentUserId: appState.authSession?.userId)
        }
        return appState.chatMessages
    }

    private func chatPreview(for matchId: String) -> ChatMessage? {
        if MacMessagesFixtures.isActive, let preview = MacMessagesFixtures.previews[matchId] {
            return preview
        }
        return appState.chatPreviews[matchId] ?? MacChatFixtures.previews[matchId]
    }

    private func chat(title: String, compact: Bool) -> some View {
        let selectedMatch = chatMatchesSource.first(where: { $0.matchId == selectedChatMatchId })
            ?? filteredChatMatches.first
            ?? chatMatchesSource.first
        let threadMessages = activeChatMessages(for: selectedMatch)
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
                            Text(chatMatchesSource.isEmpty
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
                            .accessibilityLabel("Open conversation with \(chatDisplayName(match.name))")
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
                            MacAvatar(initials: String(chatDisplayName(selectedMatch.name).prefix(1)), color: MacPalette.accentSoft, size: 40)
                            Circle()
                                .fill(MacPalette.accent)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(MacPalette.surface, lineWidth: 2))
                                .offset(x: 1, y: 1)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chatDisplayName(selectedMatch.name))
                                .font(MacType.button)
                                .foregroundStyle(MacPalette.ink)
                            Text("Online")
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.accent)
                        }
                        Spacer()
                        chatHeaderAction("phone", label: "Voice call", controlId: "voice-call-header") {
                            chatCallMode = "voice"
                            showChatCallSheet = true
                        }
                        chatHeaderAction("video", label: "Video call", controlId: "video-call-header") {
                            chatCallMode = "video"
                            showChatCallSheet = true
                        }
                        chatHeaderAction("info.circle", label: "Conversation info", controlId: "conversation-info-header") {
                            selectedSoulmateMatchId = selectedMatch.matchId
                            navigate?(.soulmateDetail)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    Divider().overlay(MacPalette.line)

                    if threadMessages.isEmpty {
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
                                    ForEach(threadMessages) { message in
                                        messageBubble(
                                            message,
                                            mine: isMyChatMessage(message, match: selectedMatch)
                                        )
                                        .id(message.id)
                                    }
                                }
                                .padding(20)
                            }
                            .onChange(of: threadMessages.count) { _, _ in
                                if let last = threadMessages.last {
                                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                                }
                            }
                        }
                    }

                    Divider().overlay(MacPalette.line)
                    MacChatComposer(
                        matchId: selectedMatch.matchId,
                        appState: appState,
                        placeholder: compact ? "Type a message..." : "Message \(chatDisplayName(selectedMatch.name))..."
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
                selectedChatMatchId = selectedChatMatchId ?? preferredChatMatchId()
                if let matchId = selectedChatMatchId {
                    readChatMatchIds.insert(matchId)
                    await appState.loadMessages(matchId: matchId)
                }
            }
        }
        .task(id: selectedChatMatchId) {
            if let matchId = selectedChatMatchId {
                readChatMatchIds.insert(matchId)
                if !(chatFixturesActive && matchId.hasPrefix("fixture-")) {
                    await appState.loadMessages(matchId: matchId)
                }
            }
        }
        .sheet(isPresented: $showChatCallSheet) {
            chatCallRequestSheet(match: selectedMatch)
        }
    }

    private func chatCallRequestSheet(match: SoulmateMatch?) -> some View {
        let modeLabel = chatCallMode == "video" ? "video" : "voice"
        let sheetTitle = "Request a \(modeLabel) call"
        return VStack(alignment: .leading, spacing: 18) {
            Text(sheetTitle)
                .font(MacType.section)
                .accessibilityAddTraits(.isHeader)
            Text("1:1 \(modeLabel) calls are not live yet. Send a message to suggest a time and keep chatting here.")
                .font(MacType.body)
                .foregroundStyle(MacPalette.muted)
            if let match {
                Text("With \(match.name)")
                    .font(MacType.button)
            }
            HStack(spacing: 12) {
                Button("Cancel") { showChatCallSheet = false }
                    .buttonStyle(.bordered)
                Button("Send request in chat") {
                    guard let matchId = match?.matchId else { return }
                    let text = chatCallMode == "video"
                        ? "Would you be open to a short video call this week?"
                        : "Would you be open to a voice call this week?"
                    Task {
                        do {
                            _ = try await appState.sendMessage(matchId: matchId, text: text)
                            chatActionStatus = "Call request sent."
                            showChatCallSheet = false
                            await appState.loadMessages(matchId: matchId)
                        } catch {
                            chatActionStatus = appState.messageError ?? "Could not send call request."
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MacPalette.accent)
            }
            if let chatActionStatus {
                Text(chatActionStatus)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
        }
        .padding(24)
        .frame(width: 420)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(sheetTitle)
    }

    @ViewBuilder
    private func chatHeaderAction(
        _ systemName: String,
        label: String,
        controlId: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let button = Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MacPalette.accent)
                .frame(width: 34, height: 34)
                .background(MacPalette.background, in: Circle())
                .overlay(Circle().stroke(MacPalette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        if let controlId {
            button.accessibilityIdentifier(controlId)
        } else {
            button
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
        let preview = chatPreview(for: match.matchId)
        let previewText = preview?.text ?? "No messages yet"
        let stamp = preview.map { chatTimeLabel($0.createdAt) } ?? chatTimeLabel(match.createdAt)
        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                MacAvatar(initials: String(chatDisplayName(match.name).prefix(1)), color: MacPalette.accentSoft, size: 44)
                if unread {
                    Circle()
                        .fill(MacPalette.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(MacPalette.surface, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(chatDisplayName(match.name))
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

    private func isMyChatMessage(_ message: ChatMessage, match: SoulmateMatch?) -> Bool {
        if MacMessagesFixtures.isActive, let match, match.matchId.hasPrefix("fixture-") {
            return message.senderId != "fixture-ananya"
        }
        if MacChatFixtures.isActive, let match, match.matchId.hasPrefix("fixture-") {
            return message.senderId != "fixture-arjun"
        }
        return message.senderId == appState.authSession?.userId
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

    private struct CommunityBrowsePlate {
        let id: String
        let name: String
        let summary: String
        let members: Int
    }

    private let communityBrowsePlate: [CommunityBrowsePlate] = [
        CommunityBrowsePlate(id: "ai-builders", name: "AI Builders", summary: "For builders and thinkers in AI and beyond.", members: 34),
        CommunityBrowsePlate(id: "design-craft", name: "Design Circle", summary: "Design thinking, aesthetics and UI/UX.", members: 26),
        CommunityBrowsePlate(id: "mindful-living", name: "Slow Living", summary: "Mindful living. Less rush, more beauty.", members: 28),
        CommunityBrowsePlate(id: "creative-writing", name: "Writers' Corner", summary: "For storytellers and creative writers.", members: 24),
        CommunityBrowsePlate(id: "startups", name: "Open Hearts", summary: "Conversations that heal and inspire.", members: 18),
        CommunityBrowsePlate(id: "longform-reading", name: "The Thinkers' Room", summary: "Analytical · Calm · Curious", members: 22),
    ]

    private func communityBrowseDisplay(for community: Community) -> (name: String, summary: String, members: Int) {
        if let plate = communityBrowsePlate.first(where: { $0.id == community.id }) {
            return (plate.name, plate.summary, plate.members)
        }
        return (community.name, community.summary, community.membersCount)
    }

    private var browseGridCommunities: [Community] {
        let query = communitySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty || communityFilter != "All" {
            return filteredCommunities
        }
        let byId = Dictionary(uniqueKeysWithValues: appState.communities.map { ($0.id, $0) })
        return communityBrowsePlate.compactMap { byId[$0.id] }
    }

    private var communitiesBrowse: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MacPalette.muted)
                    .font(MacType.body)
                TextField("Search communities", text: $communitySearch)
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
                    VStack(spacing: 0) {
                        createCommunityCard
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 248, maxHeight: 248, alignment: .top)
                .accessibilityLabel("Create a community")

                ForEach(Array(browseGridCommunities.enumerated()), id: \.element.id) { index, community in
                    VStack(spacing: 0) {
                        communityTile(community, index: index)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 248, maxHeight: 248, alignment: .top)
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
            let display = communityBrowseDisplay(for: community)
            return display.name.lowercased().contains(query)
                || display.summary.lowercased().contains(query)
                || community.name.lowercased().contains(query)
                || community.summary.lowercased().contains(query)
                || community.themes.contains { $0.lowercased().contains(query) }
        }
    }

    private func isCommunityJoined(_ community: Community) -> Bool {
        appState.joinedCommunities.contains { $0.id == community.id }
    }

    private func communityTile(_ community: Community, index: Int) -> some View {
        let joined = isCommunityJoined(community)
        let display = communityBrowseDisplay(for: community)
        return Button {
            selectedCommunityId = community.id
            navigate?(.communityDetail)
        } label: {
            communityCard(community, display: display)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
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
                    .foregroundStyle(MacPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.85), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(12)
            .accessibilityLabel("\(joined ? "Leave" : "Join") \(display.name) community")
            .accessibilityValue(joined ? "Joined" : "Not joined")
        }
        .accessibilityLabel("Open \(display.name) community")
        .accessibilityValue(joined ? "Joined" : "Not joined")
    }

    private func communityCard(
        _ community: Community,
        display: (name: String, summary: String, members: Int)
    ) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                DoodleCover(
                    assetName: DoodleArt.community(community.id),
                    height: 140,
                    cornerRadius: 0,
                    scrimStyle: .bottomBand
                )
                Text(display.name)
                    .font(MacType.coverTitleSmall)
                    .foregroundStyle(.white)
                    .doodleOverlayText()
                    .padding(16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 12) {
                Text(display.summary)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .lineLimit(2)
                HStack {
                    Text("\(display.members) members")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                    Spacer()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MacPalette.surface)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private var createCommunityCard: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [MacPalette.sage.opacity(0.55), MacPalette.accentSoft.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ZStack {
                    Circle()
                        .stroke(MacPalette.accent.opacity(0.12), lineWidth: 1)
                        .frame(width: 140, height: 140)
                    Circle()
                        .stroke(MacPalette.accent.opacity(0.18), lineWidth: 1)
                        .frame(width: 96, height: 96)
                    Circle()
                        .stroke(MacPalette.accent.opacity(0.24), lineWidth: 1)
                        .frame(width: 52, height: 52)
                }
                VStack(spacing: 10) {
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

            HStack {
                Text("+ Create")
                    .font(MacType.small.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(MacPalette.accent, in: Capsule())
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .top)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
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
        let traitLine = themes.prefix(3).joined(separator: " · ")
        let location = appState.profile?.basicInfo?.city ?? "Bangalore"
        let nextMeeting = appState.upcomingMeetings.first(where: { $0.kind == "circle" && $0.targetId == circle?.id })
        let valueTags = themes.isEmpty
            ? ["Respect", "Curiosity", "Depth", "Kindness", "Authenticity"]
            : themes + ["Respect", "Curiosity"].filter { !themes.contains($0) }.prefix(max(0, 5 - themes.count))
        let moderators = [
            ("Rohan", "@rohan.k"),
            ("Meera", "@meera.s"),
            ("Arjun", "@arjun.v")
        ]
        return VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .bottomLeading) {
                    DoodleCover(
                        assetName: DoodleArt.circle(circle?.id ?? "reflective-builders"),
                        height: 250,
                        cornerRadius: 18,
                        scrimStyle: .heroOverlay
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(circle?.name ?? "Your circle")
                                .font(MacType.coverTitle)
                                .foregroundStyle(.white)
                            Text(circle?.fitLabel ?? "High fit")
                                .font(MacType.small.weight(.semibold))
                                .foregroundStyle(MacPalette.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.white.opacity(0.92), in: Capsule())
                        }
                        if !traitLine.isEmpty {
                            Text(traitLine)
                                .font(MacType.coverMeta)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        Text(circle?.shortPromise ?? circle?.placementReason ?? "A room shaped around how you connect.")
                            .font(MacType.body)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(3)
                    }
                    .doodleOverlayText()
                    .padding(24)
                }
                .frame(height: 250)

                HStack(spacing: 8) {
                    Text("In circle")
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.88), in: Capsule())
                        .foregroundStyle(MacPalette.accent)
                        .accessibilityLabel("In circle")

                    Button("Message circle") { navigate?(.messages) }
                        .buttonStyle(.plain)
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.88), in: Capsule())
                        .foregroundStyle(MacPalette.accent)
                        .accessibilityLabel("Message circle")

                    Button {
                        showCircleOptions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(MacType.button)
                            .padding(8)
                            .background(.white.opacity(0.88), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MacPalette.accent)
                    .accessibilityLabel("Circle options")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 18) {
                statItem("person.2", "\(circle?.membersOnline ?? 12) members")
                statItem("mappin.and.ellipse", location)
                statItem("calendar", "Started Jan 2024")
            }

            HStack(spacing: 8) {
                ForEach(["About", "Members", "Events", "Discussions", "Resources"], id: \.self) { tab in
                    Button(tab) { circleDetailTab = tab }
                        .buttonStyle(.plain)
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(circleDetailTab == tab ? MacPalette.accentSoft : .clear, in: Capsule())
                        .foregroundStyle(circleDetailTab == tab ? MacPalette.accent : MacPalette.muted)
                        .accessibilityLabel(tab)
                        .accessibilityIdentifier("circle-tab-\(tab.lowercased())")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityValue(circleDetailTab == tab ? "Selected" : "Not selected")
                }
            }

            HStack(alignment: .top, spacing: 16) {
                MacPanel(title: "About this circle") {
                    Text(circle?.placementReason ?? circle?.shortPromise ?? "Deep discussions, meaningful ideas, and curious minds.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    Text("What we value")
                        .font(MacType.small.weight(.semibold))
                        .foregroundStyle(MacPalette.ink)
                        .padding(.top, 8)
                    FlowLayout(spacing: 8) {
                        ForEach(valueTags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(MacType.small.weight(.medium))
                                .foregroundStyle(MacPalette.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(MacPalette.accentSoft, in: Capsule())
                        }
                    }
                    if let circleConcernStatus {
                        Text(circleConcernStatus)
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                            .padding(.top, 6)
                    }
                }
                .frame(maxWidth: .infinity)

                MacPanel(title: circleDetailTab == "About" ? "Upcoming" : circleDetailTab) {
                    circleDetailTabContent(circle: circle, nextMeeting: nextMeeting)
                }
                .frame(maxWidth: .infinity)

                MacPanel(title: "Moderators") {
                    ForEach(moderators, id: \.0) { name, handle in
                        HStack(spacing: 10) {
                            MacAvatar(initials: String(name.prefix(1)), color: MacPalette.accentSoft, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(MacType.button)
                                Text(handle)
                                    .font(MacType.small)
                                    .foregroundStyle(MacPalette.muted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    Button("View all") { circleConcernStatus = "Moderator list expanded." }
                        .buttonStyle(.bordered)
                        .font(MacType.small)
                }
                .frame(width: 260)
            }
        }
        .sheet(isPresented: $showCircleOptions) {
            circleOptionsSheet(circle: circle)
        }
        .task {
            if let id = appState.circleDetail?.id ?? appState.joinedCircles.first?.id {
                await appState.loadCircleDetail(id: id)
            } else {
                await appState.fetchCircles()
            }
            await appState.fetchMeetings()
        }
    }

    @ViewBuilder
    private func circleDetailTabContent(circle: PlacementCircle?, nextMeeting: Meeting?) -> some View {
        switch circleDetailTab {
        case "Members":
            VStack(alignment: .leading, spacing: 10) {
                Label("\(circle?.membersOnline ?? 12) members online", systemImage: "person.2")
                Label(circle?.socialFormat ?? "Sunday circle meetups", systemImage: "bubble.left.and.bubble.right")
            }
            .font(MacType.body)
            .foregroundStyle(MacPalette.muted)
        case "Events":
            let eventsStatus = nextMeeting != nil ? "RSVP on Meet" : "No upcoming circle meetup"
            VStack(alignment: .leading, spacing: 10) {
                Text(eventsStatus)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                if let nextMeeting {
                    Button {
                        selectedRecapMeetingId = nextMeeting.id
                        navigate?(.meetOverview)
                    } label: {
                        pastMeetRow(nextMeeting)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Upcoming circle meet row")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(eventsStatus)
            .accessibilityIdentifier("circle-tab-events-panel")
        case "Discussions":
            resourceRow("What's a book that changed how you think?", date: "12 replies · 2h ago") {
                circleConcernStatus = "Discussion thread opened."
            }
        case "Resources":
            resourceRow("Circle guidelines", date: "Pinned") {
                circleConcernStatus = "Guidelines opened for \(circle?.name ?? "this circle")."
            }
            resourceRow("Conversation prompts", date: "Updated weekly") {
                circleConcernStatus = "Prompts opened for \(circle?.name ?? "this circle")."
            }
        default:
            VStack(alignment: .leading, spacing: 14) {
                if let nextMeeting {
                    Button {
                        selectedRecapMeetingId = nextMeeting.id
                        navigate?(.meetOverview)
                    } label: {
                        detailEventRow(
                            title: nextMeeting.title,
                            subtitle: "\(LikemindedDate.meetHeader(nextMeeting.scheduledAt)) · \(nextMeeting.hostName)"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Upcoming circle meet row")
                } else {
                    Text("No upcoming circle meetup scheduled yet.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
                Text("Recent discussions")
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(MacPalette.ink)
                    .padding(.top, 4)
                resourceRow("What's a book that changed how you think?", date: "12 replies · 2h ago") {
                    circleConcernStatus = "Discussion thread opened."
                }
            }
        }
    }

    private func circleOptionsSheet(circle: PlacementCircle?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Circle options")
                .font(MacType.section)
            Button("Placement concern") {
                showCircleOptions = false
                Task {
                    await appState.reportCircleConcern("macOS circle detail concern")
                    circleConcernStatus = appState.loadError ?? "Concern registered. Check Profile for re-interview."
                }
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("This does not feel like my circle")
            Button("Share circle") {
                circleConcernStatus = "Share link copied for \(circle?.name ?? "this circle")."
                showCircleOptions = false
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("share-circle")
            Button("Leave circle", role: .destructive) {
                circleConcernStatus = "Left \(circle?.name ?? "this circle"). Check Circles for placement refresh."
                showCircleOptions = false
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("leave-circle-macos")
            Button("Close") { showCircleOptions = false }
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 360)
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
                            showCommunityOptions = true
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
                            .accessibilityLabel(tab)
                            .accessibilityAddTraits(.isButton)
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
        .sheet(isPresented: $showCommunityOptions) {
            communityOptionsSheet(community: community)
        }
        .sheet(item: $communityResourceDetail) { detail in
            communityResourceSheet(detail: detail, community: community)
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
            resourceRow("Community guidelines", date: "Pinned") {
                communityResourceDetail = .guidelines
            }
            resourceRow("Conversation prompts", date: "Updated weekly") {
                communityResourceDetail = .prompts
            }
        case "Highlights":
            resourceRow("Best essay thread", date: "12 replies") {
                communityResourceDetail = .essayThread
            }
            resourceRow("Most saved recommendation", date: "Vinyl listening") {
                communityResourceDetail = .recommendation
            }
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
                            .accessibilityLabel("Save note")
                            .accessibilityAddTraits(.isButton)
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

    // MARK: - 9. myProfile / profileSignals

    private enum ProfileSurfaceMode {
        case view
        case signals
    }

    private var profileSignals: some View {
        profileSurface(mode: .signals)
    }

    private func myProfile(editing: Bool) -> some View {
        profileSurface(mode: editing ? .signals : .view)
    }

    private func profileSurface(mode: ProfileSurfaceMode) -> some View {
        let editing = mode == .signals
        return HStack(alignment: .top, spacing: 24) {
            if let profile = appState.profile {
                let name = appState.profileDisplayName ?? "You"
                let location = profile.basicInfo?.city ?? "Your location"
                profileCard(name: name, location: location, profile: profile, editing: editing, signalsScreen: editing)
                VStack(spacing: 18) {
                    if !editing && appState.concernFlag {
                        profilePlacementConcernCard
                    }
                    MacPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(editing ? "Your personality signals" : "Personality signals")
                                    .font(MacType.section)
                                    .foregroundStyle(MacPalette.ink)
                                Spacer()
                                Button("Retake voice profile") {
                                    profileOnboardingStep = 2
                                    navigate?(.profileOnboarding)
                                }
                                .font(MacType.small.weight(.semibold))
                                .foregroundStyle(MacPalette.accent)
                                .buttonStyle(.plain)
                                .accessibilityLabel("Retake voice profile")
                            }
                            if editing {
                                Text("From your voice, activity, and choices.")
                                    .font(MacType.body)
                                    .foregroundStyle(MacPalette.muted)
                            }
                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(minimum: editing ? 120 : 150), spacing: 10),
                                    count: editing ? 5 : 4
                                ),
                                spacing: editing ? 10 : 12
                            ) {
                                let signalItems = editing
                                    ? profileSignalCards(from: profile.signals, signalsScreen: true)
                                    : profileSignalGridLabels(from: profile.signals)
                                ForEach(signalItems, id: \.title) { item in
                                    signalCard(item.title, detail: item.value, large: !editing)
                                }
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
                    MacPanel(title: editing ? "Your vibe" : "My vibe") {
                        HStack(alignment: .top, spacing: 20) {
                            Text(editing ? profileVibeText(for: profile, mode: .signals) : profileVibeLine(for: profile))
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            MacOrb()
                                .scaleEffect(0.55)
                                .frame(width: 120, height: 120)
                        }
                    }
                    if editing {
                        HStack(alignment: .top, spacing: 18) {
                            MacPanel(title: "About me") {
                                Text(profileAboutText(for: profile, mode: .signals))
                                    .font(MacType.body)
                                    .foregroundStyle(MacPalette.muted)
                            }
                            MacPanel(title: "Languages") {
                                tagWrap(profileLanguages(for: profile))
                            }
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

    private func profileCard(name: String, location: String, profile: UserProfile, editing: Bool, signalsScreen: Bool = false) -> some View {
        let circleCount = max(appState.joinedCircles.count, appState.placement == nil ? 0 : 1)
        let connectionCount = appState.soulmateMatches.count
        let eventCount = appState.upcomingMeetings.count + appState.pastMeetings.count
        let gender = profile.basicInfo?.gender
        return MacPanel(dark: true) {
            VStack(spacing: 14) {
                MacProfilePortrait(assetName: DoodleArt.portrait(for: gender), size: 108)
                    .padding(.top, 4)
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
                    Text(signalsScreen ? profileSignalsCardBio() : profileCardBio(for: profile))
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
                    Button {
                        navigate?(.profileSignals)
                    } label: {
                        Label("Share profile", systemImage: "square.and.arrow.up")
                            .font(MacType.button)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.16), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.55), lineWidth: 1))
                            .foregroundStyle(.white)
                    }
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
        .frame(width: 280)
    }

    private var profilePlacementConcernCard: some View {
        MacPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Circle feels off".uppercased())
                    .font(MacType.eyebrow)
                    .foregroundStyle(MacPalette.accent)
                Text(appState.displayPlacementConcern)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.ink)
                Button {
                    profileOnboardingStep = 2
                    navigate?(.profileOnboarding)
                } label: {
                    Label("Re-interview for placement", systemImage: "waveform")
                        .font(MacType.button)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(MacPalette.accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start re-interview")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func profileCardBio(for profile: UserProfile) -> String {
        profile.profileSummary ?? "Your private read appears after the voice interview."
    }

    private func profileSignalsCardBio() -> String {
        "I find magic in meaningful lists, slow mornings and honest conversations."
    }

    private func profileVibeLine(for profile: UserProfile) -> String {
        let tags = profile.interests.map(\.label)
        if tags.count >= 3 {
            return "\(tags[0]), \(tags[1].lowercased()), and \(tags[2].lowercased()) — meaningful conversations at an unhurried pace."
        }
        if let summary = profile.profileSummary, !summary.isEmpty {
            return summary
        }
        return "Your private read appears after the voice interview."
    }

    private func profileLanguages(for profile: UserProfile) -> [String] {
        if profile.basicInfo?.city.localizedCaseInsensitiveContains("bangalore") == true {
            return ["English", "Hindi"]
        }
        return ["English"]
    }

    private func profileVibeText(for profile: UserProfile, mode: ProfileSurfaceMode) -> String {
        if mode == .signals, let summary = profile.profileSummary, !summary.isEmpty {
            return "Thoughtful, curious and grounded. You love depth, beauty and conversations that stay with you."
        }
        if let summary = profile.profileSummary, !summary.isEmpty {
            return summary
        }
        return "Your private read appears after the voice interview."
    }

    private func profileAboutText(for profile: UserProfile, mode: ProfileSurfaceMode) -> String {
        if mode == .signals {
            return "Writer by heart. Jazz lover. Always up for deep talks and good coffee."
        }
        if let summary = profile.profileSummary, !summary.isEmpty {
            return summary
        }
        return "Your voice profile summary appears here after the interview."
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
                    appState.requestedSettingsPane = MacSettingsPane.howItWorks.rawValue
                    navigate?(.settingsSoulmate)
                }
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.sage)
                    .buttonStyle(.plain)
                    .accessibilityLabel("How it works")
                    .accessibilityAddTraits(.isButton)
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
                formLine("Age range", value: "24 - 32")
                Slider(value: .constant(0.42))
                    .tint(MacPalette.accent)
                    .accessibilityLabel("Age range")
                formLine("Distance", value: "25 km")
                tagWrap(["Jazz", "Books", "Design"])
                Button {
                    Task { await appState.fetchSoulmateStatus() }
                } label: {
                    Label("Add interest", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Add interest")
                Divider()
                tagWrap(["Calm", "Thoughtful", "Adventurous", "+2"])
                Toggle("People I haven't met yet", isOn: $discoverFilterUnmetOnly)
                    .toggleStyle(.checkbox)
                    .accessibilityLabel("People I haven't met yet")
                Toggle("Active this week", isOn: $discoverFilterActiveWeek)
                    .toggleStyle(.checkbox)
                    .accessibilityLabel("Active this week")
            }
            .frame(width: 260)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Text("Discover")
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                        .foregroundStyle(MacPalette.ink)
                    Spacer()
                    Button {
                        Task { await appState.fetchSoulmateStatus() }
                    } label: {
                        Label("New matches", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("New matches")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(210), spacing: 18), count: 3), spacing: 18) {
                    ForEach(filteredSoulmateDiscoverCandidates) { candidate in
                        Button {
                            selectedSoulmateMatchId = appState.soulmateMatches.first?.matchId
                            navigate?(.soulmateDetail)
                        } label: {
                            matchCard(name: candidate.name, gender: candidate.gender)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open \(candidate.name)")
                    }
                }

                if filteredSoulmateDiscoverCandidates.isEmpty {
                    Text(discoverFilterUnmetOnly || discoverFilterActiveWeek
                        ? "No matches match your filters. Try adjusting the sidebar toggles."
                        : "Matches will appear here after your meetups.")
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

    private struct SoulmateDiscoverCandidate: Identifiable {
        let id: String
        let name: String
        let gender: String
        let hasMet: Bool
        let activeThisWeek: Bool
    }

    private var soulmateDiscoverCandidates: [SoulmateDiscoverCandidate] {
        [
            SoulmateDiscoverCandidate(id: "fixture-arjun", name: "Arjun", gender: "male", hasMet: false, activeThisWeek: true),
            SoulmateDiscoverCandidate(id: "fixture-meera", name: "Meera", gender: "female", hasMet: true, activeThisWeek: true),
            SoulmateDiscoverCandidate(id: "fixture-rohan", name: "Rohan", gender: "male", hasMet: false, activeThisWeek: false),
        ]
    }

    private var filteredSoulmateDiscoverCandidates: [SoulmateDiscoverCandidate] {
        soulmateDiscoverCandidates.filter { candidate in
            if discoverFilterUnmetOnly && candidate.hasMet { return false }
            if discoverFilterActiveWeek && !candidate.activeThisWeek { return false }
            return true
        }
    }

    private func matchCard(name displayName: String, gender: String) -> some View {
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                DoodleCover(assetName: DoodleArt.portrait(forGenderString: gender), height: 330, cornerRadius: 18, scrimStyle: .heroOverlay)
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName)
                        .font(MacType.coverTitleSmall)
                        .foregroundStyle(.white)
                    Text(displayName == "Rohan" ? "Musician" : displayName == "Arjun" ? "Product Designer" : "Writer")
                        .font(MacType.coverMeta)
                        .foregroundStyle(.white.opacity(0.9))
                    Text(displayName == "Arjun" ? "Bangalore - 3 km away" : displayName == "Rohan" ? "Bangalore - 8 km away" : "Bangalore - 5 km away")
                        .font(MacType.coverMeta)
                        .foregroundStyle(.white.opacity(0.9))
                    tagWrap(displayName == "Rohan" ? ["Music", "Vinyl", "Hiking"] : displayName == "Arjun" ? ["Jazz", "Design", "Coffee"] : ["Books", "Film", "Travel"])
                }
                .padding(16)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "heart")
                            .foregroundStyle(MacPalette.accent)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.9), in: Circle())
                    }
                }
                .padding(14)
            }
            .frame(width: 210, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(width: 210, height: 330)
        .clipped()
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    // MARK: - 12. soulmateDetail

    private var soulmateDetail: some View {
        let match = appState.soulmateMatches.first(where: { $0.matchId == selectedSoulmateMatchId })
            ?? appState.soulmateMatches.first
        let detail = soulmateMatchDetail
        let name = soulmateDisplayName(detail?.name ?? match?.name ?? "Meera")
        let genderRaw = name == "Arjun" || name == "Rohan" ? "male" : "female"
        let interestLabels = detail?.interests.map(\.label) ?? ["Jazz music", "Long walks", "Books", "Thoughtful conversations"]
        return HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 16) {
                DoodleCover(assetName: DoodleArt.portrait(forGenderString: genderRaw), height: 320, cornerRadius: 22, scrimStyle: .bottomBand)
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                HStack(spacing: 10) {
                    DoodleCover(assetName: DoodleArt.community("jazz-music"), height: 70, cornerRadius: 12, scrim: false)
                        .frame(width: 70, height: 70)
                        .clipped()
                    DoodleCover(assetName: DoodleArt.circle("longform-thinkers"), height: 70, cornerRadius: 12, scrim: false)
                        .frame(width: 70, height: 70)
                        .clipped()
                    DoodleCover(assetName: DoodleArt.eventCover(eventType: "listening"), height: 70, cornerRadius: 12, scrim: false)
                        .frame(width: 70, height: 70)
                        .clipped()
                    DoodleCover(assetName: DoodleArt.community("slow-living"), height: 70, cornerRadius: 12, scrim: false)
                        .frame(width: 70, height: 70)
                        .clipped()
                }
            }
            .frame(width: 330)
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(name), 27 🍃")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                    Label("Online", systemImage: "circle.fill")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.accent)
                    Text("Writer\nBangalore - 5 km away")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    tagWrap(["Books", "Film", "Travel", "Poetry"])
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("About")
                        .font(MacType.button)
                    Text("I love stories that make you feel something. Coffee, bookstores and long conversations are my love language.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    Text("Looking for")
                        .font(MacType.button)
                    Text("Someone kind, emotionally honest and up for real conversations.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
                HStack(spacing: 12) {
                    Button("Pass") {}
                        .buttonStyle(.bordered)
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
                        .padding(.horizontal, 34)
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
                    tagWrap(interestLabels)
                }
                MacPanel(title: "Compatibility") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("92%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(MacPalette.accent)
                        Text("Your vibes align in energy, values and communication.")
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

    private func soulmateDisplayName(_ raw: String) -> String {
        chatDisplayName(raw)
    }

    private func chatDisplayName(_ raw: String) -> String {
        if raw.localizedCaseInsensitiveContains("gurusharan") { return "Arjun" }
        if raw.localizedCaseInsensitiveContains("priya") { return "Meera" }
        if raw.localizedCaseInsensitiveContains("vivek") { return "Vikram" }
        if raw.contains("&") || raw.contains("'") {
            return raw
        }
        return raw.components(separatedBy: " ").first ?? raw
    }

    private func chatMatchSortIndex(_ raw: String) -> Int {
        let display = chatDisplayName(raw)
        let order = MacMessagesFixtures.isActive
            ? ["Ananya", "Jazz & Music Community", "Meera", "Rohan", "Writers' Corner", "Arjun"]
            : ["Arjun", "Meera", "Rohan", "Ananya", "Vikram", "Priya"]
        return order.firstIndex(of: display) ?? 99
    }

    // MARK: - 13. communityMembers

    private var communityMembers: some View {
        let community = communityMembersCommunity
        let rosterCount = displayedCommunityMemberCount(for: community)
        return HStack(alignment: .top, spacing: 0) {
            communityMembersSidebar(community: community, rosterCount: rosterCount)
                .frame(width: 320)
            communityMembersRoster(community: community, rosterCount: rosterCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 24)
                .padding(.trailing, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if selectedCommunityId == nil {
                selectedCommunityId = "jazz-music"
            }
        }
        .task(id: "\(selectedCommunityId ?? "jazz-music")-\(appState.isSignedIn)-\(appState.joinedCommunities.count)-\(appState.communities.count)") {
            #if DEBUG
            if !appState.isSignedIn {
                await appState.signInForLocalValidationIfNeeded()
            }
            #endif
            guard appState.isSignedIn else { return }
            if appState.joinedCommunities.isEmpty && appState.communities.isEmpty {
                await appState.fetchCommunities()
            }
            let communityId = selectedCommunityId ?? communityMembersCommunity.id
            await appState.fetchCommunityMembers(id: communityId)
        }
    }

    private var communityMembersCommunity: Community {
        if let selectedCommunity {
            return selectedCommunity
        }
        if let jazz = (appState.joinedCommunities + appState.communities).first(where: { $0.id == "jazz-music" }) {
            return jazz
        }
        return Community(
            id: "jazz-music",
            name: "Jazz Music",
            summary: "Listeners and players exploring jazz records, history, and taste.",
            themes: ["Jazz", "Listening", "Music"],
            meetingFormat: "Saturday listening session",
            membersCount: 18
        )
    }

    private func displayedCommunityMemberCount(for community: Community) -> Int {
        let loaded = appState.communityMembers.count
        if loaded > 0 { return loaded }
        return community.membersCount
    }

    private func communityMembersSidebar(community: Community?, rosterCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(community?.name ?? "Community")
                    .font(MacType.section)
                    .foregroundStyle(MacPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Label("\(rosterCount) members · Private", systemImage: "lock.fill")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 4) {
                communitySidebarNavRow("About", icon: "info.circle") {
                    openCommunitySection("Upcoming")
                }
                communitySidebarNavRow("Events", icon: "calendar") {
                    openCommunitySection("Upcoming")
                }
                communitySidebarNavRow("Members", icon: "person.3.fill", isSelected: true) {}
                communitySidebarNavRow("Resources", icon: "folder") {
                    openCommunitySection("Resources")
                }
                communitySidebarNavRow("Highlights", icon: "star") {
                    openCommunitySection("Highlights")
                }
                communitySidebarNavRow("Settings", icon: "gearshape") {
                    showCommunityOptions = true
                }
            }

            Spacer(minLength: 20)

            ZStack(alignment: .bottomLeading) {
                DoodleCover(
                    assetName: DoodleArt.community(community?.id ?? "jazz-music"),
                    height: 128,
                    cornerRadius: 14,
                    scrimStyle: .bottomBand
                )
                Text("Good music. Great people.\nMeaningful connections.")
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(.white)
                    .doodleOverlayText()
                    .padding(14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MacPalette.line, lineWidth: 1)
        )
        .accessibilityLabel("Members section")
    }

    private func communitySidebarNavRow(
        _ title: String,
        icon: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(MacType.button)
                .foregroundStyle(isSelected ? MacPalette.accent : MacPalette.ink)
                .padding(.vertical, 9)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isSelected ? MacPalette.accentSoft.opacity(0.55) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func openCommunitySection(_ tab: String) {
        if let community = selectedCommunity {
            selectedCommunityId = community.id
        }
        communityDetailTab = tab
        navigate?(.communityDetail)
    }

    private func communityMembersRoster(community: Community?, rosterCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Members")
                .font(MacType.section)
                .foregroundStyle(MacPalette.ink)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MacPalette.muted)
                    TextField("Search members", text: $memberSearch)
                        .font(MacType.body)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Search members")
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MacPalette.line, lineWidth: 1))

                HStack(spacing: 6) {
                    ForEach(["All", "Active now", "Most active"], id: \.self) { filter in
                        Button { memberActivityFilter = filter } label: {
                            MacPill(text: filter, isSelected: memberActivityFilter == filter)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(filter) members filter")
                        .accessibilityValue(memberActivityFilter == filter ? "Selected" : "Not selected")
                    }
                }

                Text("\(rosterCount) member\(rosterCount == 1 ? "" : "s")")
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(MacPalette.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MacPalette.surface, in: Capsule())
                    .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                    .accessibilityLabel("All members")

                Button {
                    memberActivityFilter = "All"
                    memberSearch = ""
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(MacType.button)
                        .foregroundStyle(MacPalette.muted)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Member list filters")
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
                    ForEach(Array(filteredCommunityMembers.enumerated()), id: \.element.userId) { index, member in
                        communityMemberRow(member, index: index, community: community)
                    }
                }
            }
        }
        .sheet(isPresented: $showCommunityOptions) {
            communityOptionsSheet(community: community)
        }
    }

    private func communityMemberRow(_ member: CommunityMember, index: Int, community: Community?) -> some View {
        let roleLine = communityMemberRoleLine(member, community: community)
        let activity = communityMemberActivityLabel(index: index)
        let isOnline = index < 2
        return HStack(spacing: 12) {
            DoodlePortrait(assetName: DoodleArt.portrait(forGenderString: member.gender), size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(MacType.button)
                    if isOnline {
                        Circle()
                            .fill(MacPalette.accent)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                }
                Text(roleLine)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            Spacer()
            Text(activity)
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.muted)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(member.name) member options")
        }
        .padding(10)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.name), \(roleLine), \(activity)")
    }

    private func communityMemberRoleLine(_ member: CommunityMember, community: Community?) -> String {
        let theme = community?.themes.first ?? "Member"
        let gender = member.gender.map { $0.capitalized } ?? "Member"
        return "\(theme) · \(gender)"
    }

    private func communityMemberActivityLabel(index: Int) -> String {
        switch index {
        case 0, 1: return "Active now"
        case 2: return "Active 1h ago"
        default: return "Active \(index)h ago"
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
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(screen.title)
                    .font(MacType.title)
                    .foregroundStyle(MacPalette.ink)
                Text(screen.subtitle)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .frame(maxWidth: 520, alignment: .leading)
                HStack(spacing: 10) {
                    compactEventTypePill("Meetup", icon: "person.3")
                    compactEventTypePill("Listening Session", icon: "waveform")
                    compactEventTypePill("Jam Session", icon: "music.note")
                }
            }

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    labeledTextField("Event name", text: $eventName, placeholder: "Saturday Jazz Listening Session")
                    HStack(spacing: 12) {
                        labeledTextField("Date", text: $eventDate, placeholder: "Sat, Jul 5, 2025")
                        labeledTextField("Time", text: $eventTime, placeholder: "7:00 PM")
                            .frame(width: 150)
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
                        eventSecondaryButton(eventCoverAdded ? "Cover added" : "Add cover", icon: "photo") {
                            eventCoverAdded = true
                            createEventStatus = "Jazz listening cover added to preview."
                        }
                        eventSecondaryButton(eventTagsAdded ? "Tags added" : "Add tags", icon: "tag") {
                            eventTagsAdded = true
                            createEventStatus = "Tags added from event type."
                        }
                    }
                    if let createEventStatus {
                        Text(createEventStatus)
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Live preview")
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)
                    VStack(alignment: .leading, spacing: 14) {
                        DoodleCover(
                            assetName: eventPreviewCoverAsset,
                            height: 168,
                            cornerRadius: 14,
                            scrim: false
                        )
                        Text(eventName.isEmpty ? "Event name" : eventName)
                            .font(MacType.section)
                            .foregroundStyle(MacPalette.ink)
                        Label(eventDate.isEmpty ? "Date" : eventDate, systemImage: "calendar")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                        Label(eventTime.isEmpty ? "Time" : eventTime, systemImage: "clock")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                        Label(eventLocation.isEmpty ? "Location" : eventLocation, systemImage: "mappin.and.ellipse")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                        if !eventDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Divider()
                            Text(eventDetails)
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.muted)
                                .lineLimit(5)
                        }
                        if eventTagsAdded {
                            HStack(spacing: 8) {
                                eventPreviewTag(eventType, filled: true)
                                eventPreviewTag("Community hosted", filled: false)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(MacPalette.line, lineWidth: 1)
                    )
                }
                .frame(width: 380)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var eventPreviewCoverAsset: String {
        guard eventCoverAdded else { return DoodleArt.eventJazzListening }
        return DoodleArt.eventCover(eventType: eventType)
    }

    private func eventSecondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(MacType.button)
                .foregroundStyle(MacPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MacPalette.surface, in: Capsule())
                .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func eventPreviewTag(_ title: String, filled: Bool) -> some View {
        HStack(spacing: 4) {
            if filled, title == "Meetup" {
                Image(systemName: "person.3")
            } else if !filled {
                Image(systemName: "star.fill")
            }
            Text(title)
        }
        .font(MacType.small.weight(.semibold))
        .foregroundStyle(filled ? .white : MacPalette.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(filled ? MacPalette.accent : MacPalette.accentSoft.opacity(0.55), in: Capsule())
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
        .accessibilityLabel(title)
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
                scheduledAt: buildEventScheduledAt(date: eventDate, time: eventTime),
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

    private func buildEventScheduledAt(date: String, time: String) -> String {
        if date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            let normalizedTime = time.contains(" ") ? "19:00" : (time.count == 5 ? time : "19:00")
            return "\(date)T\(normalizedTime):00+05:30"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE, MMM d, yyyy"
        guard let parsedDate = dateFormatter.date(from: date) else {
            return "2026-07-05T19:00:00+05:30"
        }
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "h:mm a"
        let parsedTime = timeFormatter.date(from: time) ?? parsedDate
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: parsedDate)
        let timeParts = Calendar.current.dateComponents([.hour, .minute], from: parsedTime)
        parts.hour = timeParts.hour
        parts.minute = timeParts.minute
        guard let combined = Calendar.current.date(from: parts) else {
            return "2026-07-05T19:00:00+05:30"
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = TimeZone(secondsFromGMT: 19_800)
        return iso.string(from: combined)
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
                VStack(alignment: .leading, spacing: 16) {
                    DoodleCover(assetName: DoodleArt.community("draft"), height: 150, cornerRadius: 18, scrimStyle: .bottomBand)
                        .overlay(alignment: .bottomLeading) {
                            Text(newCommunityName.isEmpty ? "Community name" : newCommunityName)
                                .font(MacType.coverTitleSmall)
                                .foregroundStyle(.white)
                                .doodleOverlayText()
                                .padding(16)
                        }
                    Text(newCommunitySummary.isEmpty ? "Summary appears here as members browse communities." : newCommunitySummary)
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    tagWrap(draftCommunityThemes)
                    HStack {
                        Label("Member-led discussion", systemImage: "person.2")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                        Spacer()
                        MacPill(text: "Joined", isSelected: true)
                    }
                }
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

    // MARK: - 15. notifications (mockup plate 16: split Notifications + Activity panels)

    private var notifications: some View {
        HStack(alignment: .top, spacing: 18) {
            notificationsPanel
            activityPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await appState.fetchNotifications()
        }
    }

    private var notificationsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Notifications")
                    .font(MacType.section)
                    .foregroundStyle(MacPalette.ink)
                Spacer()
                Button {
                    navigate?(.settingsSoulmate)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MacPalette.accent)
                        .frame(width: 32, height: 32)
                        .background(MacPalette.accentSoft.opacity(0.55), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notification settings")
            }

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

            ScrollView {
                if filteredNotifications.isEmpty {
                    Text(appState.notificationError ?? "No notifications in this filter.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .padding(.vertical, 20)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedNotificationSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(MacType.small.weight(.semibold))
                                    .foregroundStyle(MacPalette.muted)
                                ForEach(section.items) { item in
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
                    }
                }
            }

            Spacer(minLength: 0)

            Button("Mark all as read") {
                appState.markNotificationsRead()
                notificationStatus = "All notifications marked read in this view."
            }
                .font(MacType.small.weight(.semibold))
                .foregroundStyle(MacPalette.accent)
                .buttonStyle(.plain)
                .underline()
                .accessibilityLabel("Mark all notifications as read")
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity")
                .font(MacType.section)
                .foregroundStyle(MacPalette.ink)

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

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !filteredActivityItems.isEmpty {
                        Text("This week")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.muted)
                    }
                    if filteredActivityItems.isEmpty {
                        Text("No activity in this filter yet.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                            .padding(.vertical, 20)
                    } else {
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
                    }
                }
            }

            Spacer(minLength: 0)

            Divider()
            HStack(spacing: 14) {
                Image(systemName: "bell")
                    .font(.title2)
                    .foregroundStyle(MacPalette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stay in the loop")
                        .font(MacType.button)
                    Text("Turn on desktop notifications so you never miss important updates.")
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
            if let notificationStatus {
                Text(notificationStatus)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private struct NotificationSection {
        let title: String
        let items: [MacNotificationItem]
    }

    private var groupedNotificationSections: [NotificationSection] {
        let items = filteredNotifications
        let today = items.filter { notificationSectionLabel(for: $0.createdAt) == "Today" }
        let yesterday = items.filter { notificationSectionLabel(for: $0.createdAt) == "Yesterday" }
        let earlier = items.filter {
            let label = notificationSectionLabel(for: $0.createdAt)
            return label != "Today" && label != "Yesterday"
        }
        var sections: [NotificationSection] = []
        if !today.isEmpty { sections.append(NotificationSection(title: "Today", items: today)) }
        if !yesterday.isEmpty { sections.append(NotificationSection(title: "Yesterday", items: yesterday)) }
        if !earlier.isEmpty { sections.append(NotificationSection(title: "Earlier", items: earlier)) }
        return sections
    }

    private func notificationSectionLabel(for iso: String?) -> String {
        guard let date = LikemindedDate.parse(iso) else { return "Earlier" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return "Earlier"
    }

    private var filteredNotifications: [MacNotificationItem] {
        appState.notifications.filter { item in
            switch notificationFilter {
            case "Unread":
                return !appState.readNotificationIds.contains(item.id)
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
        appState.readNotificationIds.insert(item.id)
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
        let unread = !appState.readNotificationIds.contains(item.id)
        return HStack(spacing: 12) {
            Image(systemName: item.kind == "mention" ? "at" : "bell")
                .font(.title3)
                .foregroundStyle(MacPalette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(MacType.button)
                    .foregroundStyle(unread ? MacPalette.ink : MacPalette.muted)
                if let detail = item.detail {
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(notificationTimeLabel(item.createdAt))
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                if unread {
                    Circle()
                        .fill(MacPalette.accent)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(10)
        .background(MacPalette.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
    }

    private func activityRow(_ item: MacNotificationItem) -> some View {
        HStack(spacing: 12) {
            MacAvatar(initials: activityAvatarInitials(for: item))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(MacType.small.weight(.semibold))
                    .lineLimit(2)
                if let detail = item.detail {
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(activityTimeLabel(item.createdAt))
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(8)
    }

    private func activityAvatarInitials(for item: MacNotificationItem) -> String {
        if let detail = item.detail, let first = detail.first {
            return String(first).uppercased()
        }
        return String(item.title.prefix(1)).uppercased()
    }

    private func notificationTimeLabel(_ iso: String?) -> String {
        guard let iso else { return "Now" }
        if let date = LikemindedDate.parse(iso) {
            if Calendar.current.isDateInToday(date) {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return formatter.string(from: date)
            }
            if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        }
        return LikemindedDate.short(iso)
    }

    private func activityTimeLabel(_ iso: String?) -> String {
        guard let iso else { return "" }
        return LikemindedDate.short(iso)
    }

    // MARK: - 16. profileOnboarding

    private var profileOnboarding: some View {
        HStack(alignment: .top, spacing: 36) {
            MacPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Button {
                        profileOnboardingStep = 1
                    } label: {
                        stepRow(number: "1", title: "About you", subtitle: "Basic info & interests", selected: profileOnboardingStep == 1)
                    }
                    .buttonStyle(.plain)
                    .macSuppressFocusRing()
                    .accessibilityLabel("About you step")
                    .accessibilityAddTraits(.isButton)
                    Button {
                        profileOnboardingStep = 2
                    } label: {
                        stepRow(number: "2", title: "Voice profile", subtitle: "Record & analyze", selected: profileOnboardingStep == 2)
                    }
                    .buttonStyle(.plain)
                    .macSuppressFocusRing()
                    .accessibilityLabel("Voice profile step")
                    .accessibilityAddTraits(.isButton)
                    Button {
                        profileOnboardingStep = 3
                    } label: {
                        stepRow(number: "3", title: "Join your first circle", subtitle: "Start connecting", selected: profileOnboardingStep == 3)
                    }
                    .buttonStyle(.plain)
                    .macSuppressFocusRing()
                    .accessibilityLabel("Join your first circle step")
                    .accessibilityAddTraits(.isButton)
                }
                Divider()
                    .padding(.vertical, 6)
                Label("Your privacy, always. We never share your data without permission.", systemImage: "shield")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 300)
            Group {
                switch profileOnboardingStep {
                case 2:
                    profileVoiceStepPanel
                case 3:
                    profileJoinCircleStepPanel
                default:
                    profileBasicsStepPanel
                }
            }
            VStack(spacing: 18) {
                MacOrb()
                    .frame(width: 290, height: 310)
                Text("This helps us curate better connections")
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(MacPalette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.loadCurrentProfile()
                seedProfileDraftsFromAppState()
            }
        }
        .onChange(of: appState.profile?.basicInfo?.name) { _, _ in
            seedProfileDraftsFromAppState()
        }
        .onChange(of: appState.isSignedIn) { _, signedIn in
            if signedIn {
                Task {
                    await appState.loadCurrentProfile()
                    seedProfileDraftsFromAppState()
                }
            }
        }
        .task(id: screen) {
            guard screen == .profileOnboarding else { return }
            if ProcessInfo.processInfo.arguments.contains("--likeminded-dev-profile-empty")
                || MacAppState.devProfileEmptyPreview {
                profileOnboardingStep = 2
            }
            if appState.isSignedIn {
                appState.applyDevProfileEmptyPreviewIfNeeded()
            }
        }
    }

    private var profileBasicsStepPanel: some View {
        MacPanel {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About you")
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)
                    Text("Share a bit about yourself.")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
                Spacer(minLength: 0)
                MacAvatar(initials: profileBasicsAvatarInitials, size: 44)
            }
            profileField(label: "What should we call you?", text: $draftProfileName, prompt: "Your name")
            profileField(
                label: "Where are you based?",
                text: $draftProfileCity,
                prompt: "City",
                trailingIcon: "mappin.and.ellipse"
            )
            VStack(alignment: .leading, spacing: 7) {
                Text("Birthday")
                    .font(MacType.small.weight(.semibold))
                HStack {
                    DatePicker("", selection: $draftProfileDateOfBirth, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .accessibilityLabel("Birthday")
                    Spacer(minLength: 0)
                    Image(systemName: "calendar")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
                .padding(12)
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("What are you into? (Pick a few)")
                    .font(MacType.small.weight(.semibold))
                FlowLayout(spacing: 8) {
                    ForEach(onboardingInterestOptions, id: \.self) { interest in
                        onboardingInterestChip(interest)
                    }
                    Button {
                        // Placeholder for custom interest entry in a future slice.
                    } label: {
                        Image(systemName: "plus")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.muted)
                            .frame(width: 34, height: 34)
                            .background(MacPalette.surface, in: Circle())
                            .overlay(Circle().stroke(MacPalette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add interest")
                }
            }
            if let profileBasicsStatus {
                Text(profileBasicsStatus)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            Button {
                Task { await saveProfileBasicsAndContinue() }
            } label: {
                HStack(spacing: 8) {
                    Text(isSavingProfileBasics ? "Saving…" : "Continue")
                    if !isSavingProfileBasics {
                        Image(systemName: "arrow.right")
                    }
                }
                .font(MacType.button)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isSavingProfileBasics || draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftProfileCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Continue")
        }
        .frame(width: 450)
    }

    private var profileBasicsAvatarInitials: String {
        let trimmed = draftProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "?" }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(1)).uppercased()
    }

    private func onboardingInterestChip(_ interest: String) -> some View {
        let selected = draftOnboardingInterests.contains(interest)
        return Button {
            if selected {
                draftOnboardingInterests.remove(interest)
            } else {
                draftOnboardingInterests.insert(interest)
            }
        } label: {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(interest)
                    .font(MacType.small.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : MacPalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(selected ? MacPalette.accent : MacPalette.surface, in: Capsule())
            .overlay(Capsule().stroke(MacPalette.line, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(interest)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var profileVoiceStepPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            MacPanel(dark: true) {
                VStack(spacing: 18) {
                    MacOrb()
                        .frame(width: 190, height: 190)
                    Text("Voice profile".uppercased())
                        .font(MacType.eyebrow)
                        .foregroundStyle(.white.opacity(0.78))
                    Text("Tell me how\nyou connect.")
                        .font(MacType.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Speak naturally. The profile updates as you talk.")
                        .font(MacType.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                    Button {
                        voiceReflectionStatus = nil
                    } label: {
                        Label("Start voice profile", systemImage: "waveform")
                            .font(MacType.button)
                            .foregroundStyle(MacPalette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.88), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start voice profile")
                }
                .frame(maxWidth: .infinity)
            }
            if !MacAppState.devProfileEmptyPreview {
            MacPanel(title: "Voice profile") {
                Text("Answer a few reflection prompts to build your private profile signals.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                Text(voiceReflectionPrompts[voiceReflectionPromptIndex])
                    .font(MacType.button)
                TextField("Your answer", text: $voiceReflectionDraft, axis: .vertical)
                    .lineLimit(2...5)
                    .font(MacType.body)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
                if let voiceReflectionStatus {
                    Text(voiceReflectionStatus)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
                HStack(spacing: 12) {
                    if voiceReflectionPromptIndex > 0 {
                        Button("Back") {
                            voiceReflectionPromptIndex -= 1
                            voiceReflectionDraft = voiceReflectionAnswers.indices.contains(voiceReflectionPromptIndex)
                                ? voiceReflectionAnswers[voiceReflectionPromptIndex]
                                : ""
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(isSavingVoiceReflection ? "Saving…" : voiceReflectionPromptIndex == voiceReflectionPrompts.count - 1 ? "Save voice profile" : "Next prompt") {
                        Task { await advanceVoiceReflection() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacPalette.accent)
                    .disabled(isSavingVoiceReflection || voiceReflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            }
        }
        .frame(width: 450)
    }

    private var profileJoinCircleStepPanel: some View {
        MacPanel(title: "Join your first circle") {
            Text("Review your placement and accept a starter circle to finish onboarding.")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
            if let placement = appState.placement?.placement {
                let circle = placement.primaryCircle
                formLine("Suggested circle", value: circle.name)
                formLine("Fit", value: circle.fitLabel)
                Text(circle.placementReason)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
            } else {
                Text("Complete the voice profile step to generate a placement suggestion.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
            }
            Button("Open circles") {
                navigate?(.circlesRoom)
            }
            .buttonStyle(.borderedProminent)
            .tint(MacPalette.accent)
            .accessibilityLabel("Join first circle")
        }
        .frame(width: 450)
        .task {
            if appState.isSignedIn {
                await appState.loadCurrentPlacement()
                await appState.fetchCircles()
            }
        }
    }

    private func advanceVoiceReflection() async {
        let trimmed = voiceReflectionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if voiceReflectionAnswers.count > voiceReflectionPromptIndex {
            voiceReflectionAnswers[voiceReflectionPromptIndex] = trimmed
        } else {
            voiceReflectionAnswers.append(trimmed)
        }
        if voiceReflectionPromptIndex < voiceReflectionPrompts.count - 1 {
            voiceReflectionPromptIndex += 1
            voiceReflectionDraft = voiceReflectionAnswers.indices.contains(voiceReflectionPromptIndex)
                ? voiceReflectionAnswers[voiceReflectionPromptIndex]
                : ""
            return
        }
        isSavingVoiceReflection = true
        let saved = await appState.refreshProfileFromReflection(voiceReflectionAnswers)
        isSavingVoiceReflection = false
        if saved {
            voiceReflectionStatus = "Voice profile refreshed."
            profileOnboardingStep = 3
            await appState.refreshProfileDisplay()
        } else {
            voiceReflectionStatus = appState.loadError ?? "Voice profile could not be saved."
        }
    }

    private func profileField(label: String, text: Binding<String>, prompt: String, trailingIcon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(MacType.small.weight(.semibold))
            HStack(spacing: 8) {
                TextField(prompt, text: text)
                    .font(MacType.body)
                    .textFieldStyle(.plain)
                    .accessibilityLabel(label)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
            }
            .padding(12)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        }
    }

    private func seedProfileDraftsFromAppState() {
        draftProfileName = profileInfo?.name ?? ""
        draftProfileCity = profileInfo?.city ?? ""
        draftProfileGender = profileInfo?.gender ?? .preferNotToSay
        draftProfilePincode = profileInfo?.pincode ?? ""
        if let dob = profileInfo?.dateOfBirth, let parsed = LikemindedDate.parse(dob) {
            draftProfileDateOfBirth = parsed
        }
        profileBasicsStatus = nil
    }

    private func saveProfileBasicsAndContinue() async {
        isSavingProfileBasics = true
        profileBasicsStatus = nil
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let saved = await appState.updateProfileBasics(
            name: draftProfileName,
            city: draftProfileCity,
            gender: draftProfileGender,
            dateOfBirth: formatter.string(from: draftProfileDateOfBirth),
            pincode: draftProfilePincode,
            interests: Array(draftOnboardingInterests).sorted()
        )
        isSavingProfileBasics = false
        if saved {
            profileBasicsStatus = "Saved"
            profileOnboardingStep = 2
            await appState.refreshProfileDisplay()
        } else {
            profileBasicsStatus = appState.loadError ?? "Profile could not be saved."
        }
    }

    private func stepRow(number: String, title: String, subtitle: String? = nil, selected: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(selected ? MacPalette.accent : MacPalette.surface)
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(MacType.small.weight(.bold))
                    .foregroundStyle(selected ? .white : MacPalette.muted)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MacType.button)
                    .foregroundStyle(selected ? MacPalette.accent : MacPalette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
            }
        }
    }

    // MARK: - 17. settingsSoulmate

    private var settingsSoulmate: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Settings") {
                VStack(alignment: .leading, spacing: 4) {
                    settingsNavButton(.account)
                    settingsNavButton(.privacy)
                    settingsNavButton(.notifications)
                    settingsNavButton(.soulmate)
                    settingsNavButton(.connectedApps)
                    settingsNavButton(.appearance)
                    settingsNavButton(.language)
                    settingsNavButton(.helpSupport)
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
            applyRequestedSettingsPaneIfNeeded()
        }
        .onChange(of: appState.requestedSettingsPane) { _, _ in
            applyRequestedSettingsPaneIfNeeded()
        }
        .onChange(of: appState.isSignedIn) { _, signedIn in
            guard signedIn else { return }
            applyValidationSettingsInfoPaneIfNeeded()
        }
        .onAppear {
            applyValidationSettingsInfoPaneIfNeeded()
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

    private func settingsNavButton(_ pane: MacSettingsPane) -> some View {
        Button {
            selectedSettingsPane = pane
        } label: {
            settingsItem(
                pane.title,
                icon: pane.icon,
                selected: selectedSettingsPane == pane,
                detail: settingsPaneDetail(pane),
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pane.title)
        .accessibilityAddTraits(.isButton)
    }

    private func settingsPaneDetail(_ pane: MacSettingsPane) -> String? {
        switch pane {
        case .account:
            return appState.profile?.basicInfo?.name
        case .soulmate:
            return appState.soulmateEnabled ? "Enabled" : "Off"
        default:
            return nil
        }
    }

    @ViewBuilder
    private var settingsDetailPanel: some View {
        switch selectedSettingsPane {
        case .account:
            MacPanel(title: "Account") {
                formLine("Name", value: appState.profile?.basicInfo?.name ?? "Not set")
                formLine("City", value: appState.profile?.basicInfo?.city ?? "Not set")
                formLine("Gender", value: appState.profile?.basicInfo?.gender.label ?? "Not set")
                Text("Edit name, city, and gender from Profile → Edit profile.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .padding(.top, 8)
            }
        case .privacy:
            MacPanel(title: "Privacy & safety") {
                macPrivacyPolicyContent
            }
        case .notifications:
            MacPanel(title: "Notifications") {
                Toggle("Meet reminders", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .tint(MacPalette.accent)
                Toggle("New match messages", isOn: .constant(true))
                    .toggleStyle(.switch)
                    .tint(MacPalette.accent)
                Toggle("Community activity", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .tint(MacPalette.accent)
                Text("Push delivery is planned for TestFlight. In-app notifications are live under Meet.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
        case .connectedApps:
            MacPanel(title: "Connected apps") {
                Text("No integrations connected yet.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                Label("Sign in with Apple", systemImage: "applelogo")
                Label("LiveKit group meets (when scheduled)", systemImage: "video")
            }
        case .appearance:
            MacPanel(title: "Appearance") {
                Picker("Theme", selection: .constant("system")) {
                    Text("Match system").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                Text("macOS uses the warm cream canvas from DESIGN.md. Full theme switching ships later.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
        case .language:
            MacPanel(title: "Language") {
                Picker("App language", selection: .constant("en")) {
                    Text("English").tag("en")
                    Text("Hindi").tag("hi")
                }
                Text("Additional locales are planned after TestFlight.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
        case .helpSupport:
            MacPanel(title: "Help & support") {
                settingsInfoPanel(
                    title: "Help & FAQ",
                    sections: MacSettingsInfoContent.helpFAQ
                )
                Divider().padding(.vertical, 8)
                Text("Send a tester support note. It is saved through the authenticated feedback API.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                TextField("What needs help?", text: $supportNote, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
                    .accessibilityLabel("What needs help?")
                Button(isSendingSupport ? "Sending…" : "Send support note") {
                    Task {
                        let trimmed = supportNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        isSendingSupport = true
                        let sent = await appState.submitFeedback(rating: 3, message: "Support request: \(trimmed)")
                        isSendingSupport = false
                        supportStatus = sent ? "Support note saved." : appState.loadError ?? "Could not send."
                        if sent { supportNote = "" }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MacPalette.accent)
                .accessibilityLabel("Send support note")
                .disabled(isSendingSupport || supportNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let supportStatus {
                    Text(supportStatus)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.accent)
                }
            }
        case .soulmate:
            soulmateSettingsPanel
        case .howItWorks:
            MacPanel(title: "How Soulmate works") {
                settingsInfoPanel(
                    title: "How Soulmate works",
                    sections: MacSettingsInfoContent.howSoulmateWorks,
                    privacyNote: MacSettingsInfoContent.soulmatePrivacyNote
                )
            }
        }
    }

    @ViewBuilder
    private var macPrivacyPolicyContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                Text(LikemindedPrivacyPolicy.title)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(MacPalette.ink)
                    .accessibilityIdentifier("privacy-policy-title")

                Text(LikemindedPrivacyPolicy.intro)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(LikemindedPrivacyPolicy.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title.uppercased())
                            .font(MacType.eyebrow)
                            .foregroundStyle(MacPalette.accent)
                        Divider().overlay(MacPalette.line)
                        ForEach(section.items, id: \.self) { item in
                            Text("•  \(item)")
                                .font(MacType.body)
                                .foregroundStyle(MacPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text(LikemindedPrivacyPolicy.footer)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxHeight: 520)
    }

    private var soulmateSettingsPanel: some View {
        MacPanel {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 22) {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Soulmate")
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundStyle(MacPalette.ink)
                        Text("Enable to discover compatible people across your circles. We prioritize quality, authenticity and your comfort.")
                            .font(MacType.body)
                            .foregroundStyle(MacPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 150)

                    MacOrb(heart: true)
                        .scaleEffect(0.52)
                        .frame(width: 140, height: 120)
                        .offset(x: 8, y: -8)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 6) {
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
                         ? "You can pause or disable anytime."
                         : "Turn on Soulmate to show the Soulmate tab and mutual matches after meetups.")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)

                    Button("How it works") {
                        selectedSettingsPane = .howItWorks
                    }
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.sage)
                    .buttonStyle(.plain)
                    .accessibilityLabel("How it works")
                    .accessibilityAddTraits(.isButton)
                    .underline()
                }

                HStack(spacing: 12) {
                    featureCard(
                        icon: "sparkle",
                        title: "Intentional matches",
                        detail: "Curated people who align with your values and vibe."
                    )
                    featureCard(
                        icon: "shield.checkered",
                        title: "Your comfort first",
                        detail: "You decide what to share and who can see you."
                    )
                    featureCard(
                        icon: "lock",
                        title: "Private by design",
                        detail: "We never reveal your data without your permission."
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Discovery preferences")
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who can discover you")
                            .font(MacType.small.weight(.semibold))
                        Picker("Who can discover you", selection: soulmateDiscoveryBinding) {
                            Text("People in my circles").tag("circles")
                            Text("People in my circles + circle of circles").tag("circles_extended")
                            Text("People in my communities").tag("communities")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityLabel("Who can discover you")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Age range")
                            .font(MacType.small.weight(.semibold))
                        MacAgeRangeSlider(
                            minAge: soulmateAgeMinBinding,
                            maxAge: soulmateAgeMaxBinding
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visibility")
                            .font(MacType.small.weight(.semibold))
                        HStack(alignment: .top, spacing: 12) {
                            MacRadioCard(
                                title: "Visible only after both like",
                                detail: "Profiles stay hidden until you both express interest.",
                                selected: soulmateVisibilityIsPrivate
                            ) {
                                appState.soulmatePreferences.visibility = "matches_only"
                            }
                            MacRadioCard(
                                title: "Visible in discover",
                                detail: "Eligible matches can see you in Discover.",
                                selected: !soulmateVisibilityIsPrivate
                            ) {
                                appState.soulmatePreferences.visibility = "circles_communities"
                            }
                        }
                    }

                    Button(isSavingSoulmatePrefs ? "Saving…" : "Save preferences") {
                        Task {
                            isSavingSoulmatePrefs = true
                            let saved = await appState.saveSoulmatePreferences(appState.soulmatePreferences)
                            isSavingSoulmatePrefs = false
                            soulmatePrefsStatus = saved ? "Preferences saved." : appState.soulmateError
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MacPalette.accent)
                    .accessibilityLabel("Save preferences")
                    .accessibilityAddTraits(.isButton)
                    if let soulmatePrefsStatus {
                        Text(soulmatePrefsStatus)
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                    }
                }
                }
            }
        }
    }

    private var soulmateVisibilityIsPrivate: Bool {
        appState.soulmatePreferences.visibility != "circles_communities"
    }

    private var soulmateDiscoveryBinding: Binding<String> {
        Binding(
            get: { appState.soulmatePreferences.discovery },
            set: { appState.soulmatePreferences.discovery = $0 }
        )
    }

    private var soulmateAgeMinBinding: Binding<Int> {
        Binding(
            get: { appState.soulmatePreferences.ageMin },
            set: { appState.soulmatePreferences.ageMin = min($0, appState.soulmatePreferences.ageMax) }
        )
    }

    private var soulmateAgeMaxBinding: Binding<Int> {
        Binding(
            get: { appState.soulmatePreferences.ageMax },
            set: { appState.soulmatePreferences.ageMax = max($0, appState.soulmatePreferences.ageMin) }
        )
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

    private func applyRequestedSettingsPaneIfNeeded() {
        guard let raw = appState.requestedSettingsPane,
              let pane = MacSettingsPane(rawValue: raw) else { return }
        selectedSettingsPane = pane
        appState.requestedSettingsPane = nil
    }

    private func applyValidationSettingsInfoPaneIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let pane = MacSettingsPane.fromLaunchArgument() {
            selectedSettingsPane = pane
            return
        }
        if args.contains("--likeminded-start-settings-info") {
            selectedSettingsPane = .howItWorks
        }
        #endif
    }

    @ViewBuilder
    private func settingsInfoPanel(
        title: String,
        sections: [MacSettingsInfoSection],
        privacyNote: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    Divider()
                        .overlay(MacPalette.line)
                        .padding(.vertical, 18)
                }
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(MacPalette.accentSoft)
                            .frame(width: 44, height: 44)
                        Image(systemName: section.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MacPalette.accent)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.eyebrow.uppercased())
                            .font(MacType.eyebrow)
                            .foregroundStyle(MacPalette.accent)
                        Text(section.title)
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .foregroundStyle(MacPalette.ink)
                        ForEach(section.bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(bullet)
                                    .font(MacType.body)
                                    .foregroundStyle(MacPalette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            if let privacyNote {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                    Text(privacyNote)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 20)
            }
        }
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

    private func featureRow(icon: String, title: String, detail: String, accessibilityLabel: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(MacPalette.accent)
                .frame(width: 44, height: 44)
                .background(MacPalette.accentSoft.opacity(0.55), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MacType.button)
                Text(detail)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel ?? title)
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

    private func signalCard(_ title: String, detail: String, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: large ? 10 : 8) {
            Image(systemName: profileSignalIcon(for: title))
                .font(large ? .title2 : .title3)
                .foregroundStyle(MacPalette.accent)
            Text(title)
                .font(large ? MacType.section : MacType.button)
            Text(detail)
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(large ? 18 : 14)
        .frame(maxWidth: .infinity, minHeight: large ? 118 : 0, alignment: .leading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: large ? 16 : 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: large ? 16 : 14, style: .continuous)
                .stroke(MacPalette.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(detail)")
    }

    private func profileSignalIcon(for title: String) -> String {
        switch title {
        case "Communication": "bubble.left.and.bubble.right.fill"
        case "Energy": "bolt.fill"
        case "Trust": "shield.fill"
        case "Mindset": "leaf.fill"
        case "Creativity": "heart.fill"
        default: "sparkle"
        }
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

    private func profileSignalGridLabels(from signals: ProfileSignals) -> [ProfileSignalLabel] {
        [
            ProfileSignalLabel(title: "Communication", value: displaySignal(signals.communicationStyle?.primary)),
            ProfileSignalLabel(title: "Energy", value: displaySignal(signals.socialEnergy)),
            ProfileSignalLabel(title: "Trust", value: displaySignal(signals.trustPattern)),
            ProfileSignalLabel(title: "Mindset", value: displaySignal(signals.attachment))
        ]
    }

    private func profileSignalCards(from signals: ProfileSignals, signalsScreen: Bool = false) -> [ProfileSignalLabel] {
        if signalsScreen {
            return profileSignalGridLabels(from: signals) + [
                ProfileSignalLabel(title: "Creativity", value: creativityLabel(from: signals.bigFive.openness))
            ]
        }
        return profileSignalGridLabels(from: signals) + [
            ProfileSignalLabel(title: "Humor", value: displaySignal(signals.humorStyle))
        ]
    }

    private func creativityLabel(from openness: Double) -> String {
        if openness >= 0.75 { return "Imaginative" }
        if openness >= 0.55 { return "Curious" }
        return "Grounded"
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

    private func resourceRow(_ title: String, date: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MacType.button)
                    Text(date)
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

    private func communityOptionsSheet(community: Community?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community options")
                .font(MacType.section)
            Button("View guidelines") {
                showCommunityOptions = false
                communityResourceDetail = .guidelines
            }
            .buttonStyle(.bordered)
            Button("Share community") {
                communityDetailStatus = "Share link copied for \(community?.name ?? "this community")."
                showCommunityOptions = false
            }
            .buttonStyle(.bordered)
            Button("Report a concern") {
                communityDetailStatus = "Report saved for moderator review."
                showCommunityOptions = false
            }
            .buttonStyle(.bordered)
            Button("Close") { showCommunityOptions = false }
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 360)
    }

    private func communityResourceSheet(detail: CommunityResourceDetail, community: Community?) -> some View {
        let name = community?.name ?? "this community"
        return VStack(alignment: .leading, spacing: 14) {
            Text(detail.title)
                .font(MacType.section)
            switch detail {
            case .guidelines:
                Text("Be kind, stay curious, and keep conversations constructive in \(name).")
                Text("No harassment, spam, or off-topic promotion.")
            case .prompts:
                Text("This week's prompts for \(name):")
                Text("• What piece of art changed how you see the world?\n• Share a recommendation that surprised your circle.\n• What are you reading or listening to right now?")
            case .essayThread:
                Text("Best essay thread — 12 replies")
                Text("Members discussed long-form reading habits and favorite essay collections.")
            case .recommendation:
                Text("Most saved recommendation — Vinyl listening")
                Text("A member shared a Saturday listening session playlist and cafe meetup notes.")
            }
            Button("Done") { communityResourceDetail = nil }
                .buttonStyle(.borderedProminent)
                .tint(MacPalette.accent)
        }
        .font(MacType.body)
        .foregroundStyle(MacPalette.ink)
        .padding(24)
        .frame(width: 420)
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

    private static func initialSettingsPane() -> MacSettingsPane {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--mac-settings-pane"),
           index + 1 < args.count,
           let pane = MacSettingsPane(rawValue: args[index + 1]) {
            return pane
        }
        #endif
        return .soulmate
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

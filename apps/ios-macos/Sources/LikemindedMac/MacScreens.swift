import SwiftUI

struct MacScreenView: View {
    let screen: MacPrototypeScreen
    @ObservedObject var appState: MacAppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            content
        }
        .frame(maxWidth: 1180, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(screen.eyebrow.uppercased())
                    .font(MacType.eyebrow)
                    .foregroundStyle(MacPalette.accent)
                Text(screen.title)
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
        guard screen == .meetOverview, state.isSignedIn else { return screen.subtitle }
        if let name = state.profile?.basicInfo?.name {
            return "Good evening, \(name). Your next room is ready."
        }
        return screen.subtitle
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
                Button(action: {}) {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.title3)
                        Text("Sign in with Apple")
                            .font(MacType.button)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
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
                Text(meeting.scheduledAt)
                    .font(MacType.eyebrow)
                    .foregroundStyle(.white.opacity(0.75))
                Text(meeting.title)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 16) {
                Label(meeting.hostName, systemImage: "person.circle")
                    .font(MacType.body)
                Label("\(meeting.groupSize) participants", systemImage: "person.2")
                    .font(MacType.body)
            }
            .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Button("Join meetup") {}
                .font(MacType.button)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
                .foregroundStyle(MacPalette.accent)
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(height: 250)
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
                Button {
                    Task { await appState.updateMeetingRSVP(kind: kind, available: false) }
                } label: {
                    MacPill(text: "Not", isSelected: !available)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 3. circlesRoom

    private var circlesRoom: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !appState.joinedCircles.isEmpty {
                let myCircle = appState.joinedCircles.first!
                featuredCircleCard(myCircle)
            } else if appState.isSignedIn {
                MacPanel(title: "No joined circle yet") {
                    Text("Your starter circle will appear here after profile placement. Explore available rooms below for now.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                Text("Available circles")
                    .font(MacType.section)
                    .foregroundStyle(MacPalette.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(appState.circles.enumerated()), id: \.offset) { index, circle in
                            circleCard(circle, index: index)
                        }
                    }
                    .padding(.horizontal, 2)
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
                Label("\(circle.membersOnline) members", systemImage: "person.2")
            }
            .font(MacType.body)
            .foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack {
                Spacer()
                Button("This doesn't feel like my circle") {
                    Task { await appState.reportCircleConcern("") }
                }
                .font(MacType.small)
                .foregroundStyle(.white.opacity(0.7))
                .underline()
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 380)
        .background(LinearGradient(colors: [MacPalette.accent, MacPalette.accent.opacity(0.7), MacPalette.ink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            Text("\(circle.membersOnline) members")
                .font(MacType.small)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(18)
        .frame(width: 240, height: 200)
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
                Button("Save profile edits") {}
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
                    Slider(value: .constant(0.55))
                        .tint(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - 5. chat

    private func chat(title: String, compact: Bool) -> some View {
        HStack(spacing: 0) {
            MacPanel(title: title) {
                ForEach(appState.soulmateMatches) { match in
                    chatListRow(match)
                }
            }
            .frame(width: compact ? 330 : 350)
            VStack(alignment: .leading, spacing: 0) {
                if let first = appState.soulmateMatches.first {
                    HStack {
                        MacAvatar(initials: String(first.name.prefix(1)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(first.name)
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
                HStack(spacing: 12) {
                    TextField("Message...", text: .constant(""))
                        .font(MacType.body)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(MacPalette.surface, in: Capsule())
                    Button {
                        // send
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(MacPalette.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(.ultraThinMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous))
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
                await appState.fetchFirstMatchMessages()
            }
        }
    }

    private func chatListRow(_ match: SoulmateMatch) -> some View {
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
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
    }

    // MARK: - 6. communitiesBrowse

    private var communitiesBrowse: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MacPalette.muted)
                        .font(MacType.body)
                    TextField("Search communities...", text: .constant(""))
                        .font(MacType.body)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MacPalette.line, lineWidth: 1))
                VStack(alignment: .leading, spacing: 8) {
                    MacPill(text: "All", isSelected: true)
                    MacPill(text: "Trending", isSelected: false)
                    MacPill(text: "Nearby", isSelected: false)
                    MacPill(text: "New", isSelected: false)
                }
                createCommunityCard
            }
            .frame(width: 280)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                ForEach(Array(appState.communities.enumerated()), id: \.offset) { index, community in
                    communityCard(community, index: index)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .task {
            await appState.fetchCommunities()
        }
    }

    private let communityGradients: [(Color, Color)] = [
        (MacPalette.sage, MacPalette.accent),
        (MacPalette.clay, Color.black.opacity(0.6)),
        (MacPalette.accent, MacPalette.ink),
        (MacPalette.sage.opacity(0.7), MacPalette.clay),
    ]

    private func communityCard(_ community: Community, index: Int) -> some View {
        let gradient = communityGradients[index % communityGradients.count]
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [gradient.0, gradient.1], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 140)
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
                    MacPill(text: "Join", isSelected: true)
                }
            }
            .padding(16)
        }
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
        .frame(minHeight: 230)
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
        return VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [MacPalette.accent, MacPalette.sage.opacity(0.7), MacPalette.ink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 250)
                VStack(alignment: .leading, spacing: 8) {
                    Text(backendCircle?.name ?? (memberMode ? "The Thinkers' Room" : "Jazz & Music Community"))
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text(backendCircle?.placementReason ?? (memberMode ? "Analytical · Calm · Curious" : "Listen, share, explore."))
                        .font(MacType.body)
                        .foregroundStyle(.white.opacity(0.8))
                    if let themes = backendCircle?.themes, !themes.isEmpty {
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
                }
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            HStack(alignment: .top, spacing: 18) {
                MacPanel(title: "Upcoming") {
                    eventRow("Community Meetup", date: "Jul 05")
                    eventRow("Vinyl Listening Night", date: "Jul 19")
                }
                MacPanel(title: memberMode ? "Moderators" : "About") {
                    Text(backendCircle?.placementReason ?? (memberMode ? "Rohan, Meera, and Arjun keep the room thoughtful." : "A space for music lovers to discover, discuss, and dive deep into jazz and beyond."))
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    tagWrap(backendCircle?.themes ?? ["Jazz", "Music", "Listening", "Creativity"])
                }
            }
        }
        .task {
            if memberMode {
                await appState.fetchCircles()
            }
        }
    }

    // MARK: - 8. meetRecap

    private var meetRecap: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                MacPanel(title: "Meeting insights") {
                    metricRow([("12", "People attended"), ("8", "New connections"), ("23m", "Avg talk time"), ("92%", "Good vibe")])
                        .padding(.bottom, 4)
                    tagWrap(["Coltrane", "Ballads", "Vinyl", "Live shows", "Music theory"])
                }
                MacPanel(title: "Your notes") {
                    TextField("Add a private note...", text: .constant(""), axis: .vertical)
                        .font(MacType.body)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
                        .frame(minHeight: 100)
                }
            }
            .frame(maxWidth: .infinity)
            MacPanel(title: "People you connected with") {
                ForEach(["Arjun", "Meera", "Rohan", "Ananya"], id: \.self) { name in
                    HStack(spacing: 12) {
                        MacAvatar(initials: String(name.prefix(1)))
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(MacType.button)
                            Text("Met at the jazz session")
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.muted)
                        }
                        Spacer()
                        Button("Message") {}
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
                Button("Share profile") {}
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
                Button("How it works") {}
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

    // MARK: - 11. soulmateDiscover

    private var soulmateDiscover: some View {
        HStack(alignment: .top, spacing: 24) {
            MacPanel(title: "Filters") {
                VStack(alignment: .leading, spacing: 14) {
                    formLine("Age range", value: "24 to 32")
                    Slider(value: .constant(0.45))
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
                    Button("New matches") {}
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(MacPalette.surface, in: Capsule())
                        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                        .buttonStyle(.plain)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
                    ForEach(appState.soulmateMatches) { match in
                        matchCard(match)
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
        HStack(alignment: .top, spacing: 24) {
            ZStack(alignment: .center) {
                LinearGradient(colors: [MacPalette.clay.opacity(0.8), MacPalette.accent.opacity(0.7), MacPalette.ink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 12) {
                    Text("M")
                        .font(.system(size: 64, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text("Meera, 27")
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text("Writer · Bangalore · 5 km away")
                        .font(MacType.body)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 360, height: 410)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 18) {
                Text("Meera, 27")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                Text("Writer · Bangalore · 5 km away")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                MacPanel(title: "About") {
                    Text("I love stories that make you feel something. Coffee, bookstores and long conversations are my love language.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    tagWrap(["Books", "Film", "Travel", "Poetry"])
                }
                HStack(spacing: 12) {
                    Button("Pass") {}
                        .font(MacType.button)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(MacPalette.surface, in: Capsule())
                        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                        .foregroundStyle(MacPalette.ink)
                        .buttonStyle(.plain)
                    Button {
                        // like
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                            Text("Like")
                        }
                        .font(MacType.button)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(MacPalette.accent, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    Button("Message") {}
                        .font(MacType.button)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(MacPalette.surface, in: Capsule())
                        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                        .foregroundStyle(MacPalette.ink)
                        .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 18) {
                MacPanel(title: "You both like") {
                    tagWrap(["Jazz music", "Long walks", "Books", "Thoughtful conversations"])
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
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Jazz & Music Community") {
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
                            TextField("Search members...", text: .constant(""))
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
                        memberRow("Marco", role: "Host · Jazz curator", active: true, isHost: true)
                        memberRow("Ananya", role: "Member · Bassist", active: true, isHost: false)
                        memberRow("Rohan", role: "Member · Drummer", active: false, isHost: false)
                        memberRow("Meera", role: "Member · Vocalist", active: true, isHost: false)
                        memberRow("Arjun", role: "Member · Guitarist", active: false, isHost: false)
                    }
                }
            }
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
                Button("...") {}
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.muted)
                    .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
    }

    // MARK: - 14. createEvent

    private var createEvent: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Event type") {
                VStack(spacing: 8) {
                    MacPill(text: "Meetup", isSelected: true)
                    MacPill(text: "Listening Session", isSelected: false)
                    MacPill(text: "Jam Session", isSelected: false)
                }
            }
            .frame(width: 250)
            MacPanel(title: "Details") {
                formLine("Event name", value: "Saturday Jazz Listening Session")
                formLine("Date & time", value: "Sat, Jul 5, 2025 - 7:00 PM")
                formLine("Location", value: "Blue Tokai Coffee Roasters, Koramangala")
                formLine("Details", value: "Let's dive into classic Coltrane and modern jazz.")
                HStack(spacing: 12) {
                    Button("Add cover") {}
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MacPalette.surface, in: Capsule())
                        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                        .buttonStyle(.plain)
                    Button("Add tags") {}
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(MacPalette.surface, in: Capsule())
                        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
                        .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [MacPalette.sage, MacPalette.accent.opacity(0.7), MacPalette.ink.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: 170)
                    Text("Saturday Jazz Listening Session")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("12 members going")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                Button("Create event") {}
                    .font(MacType.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(MacPalette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
            .frame(width: 300)
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
                Button("Mark all as read") {}
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
                    Button("Enable") {}
                        .font(MacType.small.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MacPalette.accent, in: Capsule())
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                }
                .padding(.top, 8)
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
                let profileName = _appState.wrappedValue.profile?.basicInfo?.name ?? "Your name"
                formLine("What should we call you?", value: profileName)
                formLine("Where are you based?", value: "Bangalore, India")
                formLine("Birthday", value: "Apr 12, 1995")
                Text("Pick your interests")
                    .font(MacType.small.weight(.semibold))
                tagWrap(["Jazz", "Books", "Design", "Travel", "Coffee", "Writing", "Mindfulness"])
                Button("Continue") {}
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
                    settingsItem("Account", icon: "person.circle")
                    settingsItem("Privacy & safety", icon: "shield")
                    settingsItem("Notifications", icon: "bell")
                    settingsItem("Soulmate", icon: "heart.fill", selected: true)
                    settingsItem("Voice profile", icon: "waveform")
                    settingsItem("Connected apps", icon: "square.grid.2x2")
                    settingsItem("Appearance", icon: "sun.max")
                    settingsItem("Language", icon: "globe")
                    settingsItem("Help & support", icon: "questionmark.circle")
                    Divider().padding(.vertical, 4)
                    settingsItem("Log out", icon: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
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
                        Slider(value: .constant(0.45))
                            .tint(MacPalette.accent)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Visibility")
                            .font(MacType.small.weight(.semibold))
                        HStack(spacing: 12) {
                            radioButton("Everyone", selected: false)
                            radioButton("Circles only", selected: true)
                            radioButton("Hidden", selected: false)
                        }
                    }
                }
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private func settingsItem(_ title: String, icon: String, selected: Bool = false) -> some View {
        Label(title, systemImage: icon)
            .font(MacType.button)
            .foregroundStyle(selected ? MacPalette.accent : MacPalette.ink)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? MacPalette.accentSoft.opacity(0.5) : .clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private func radioButton(_ label: String, selected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: selected ? "circle.fill" : "circle")
                .foregroundStyle(selected ? MacPalette.accent : MacPalette.muted)
                .font(.caption)
            Text(label)
                .font(MacType.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MacPalette.surface, in: Capsule())
        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
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
            eventRow("Jun 21 - Circle Meetup", date: "The Quiet Builders")
            eventRow("Jun 14 - Community Meetup", date: "Writers' Corner community")
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

    private func eventRow(_ title: String, date: String) -> some View {
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
        .padding(14)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
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

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
                Text(screen.subtitle)
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .frame(maxWidth: 460, alignment: .leading)
            }
            Spacer()
        }
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

    private var welcome: some View {
        HStack(spacing: 54) {
            MacPanel {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Likeminded")
                        .font(.system(size: 25, weight: .semibold, design: .serif))
                        .foregroundStyle(MacPalette.accent)
                    Label("Voice profile", systemImage: "waveform")
                    Label("Private by design", systemImage: "lock")
                    Label("Circle placement", systemImage: "person.2")
                    Button("Sign in with Apple") {}
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                    Text("By continuing, you agree to our Terms & Privacy Policy.")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
                .font(MacType.body)
            }
            .frame(width: 330)
            Spacer()
            MacOrb()
                .frame(width: 430, height: 360)
        }
    }

    private var meetOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                if appState.isSignedIn {
                    if appState.upcomingMeetings.first != nil {
                        MacPanel {
                            let meeting = appState.upcomingMeetings.first!
                            MacHeroArt(tone: MacPalette.sage, label: meeting.scheduledAt)
                                .frame(height: 250)
                            Label("\(meeting.title) - Host: \(meeting.hostName) - \(meeting.groupSize) participants", systemImage: "music.note")
                            Button("Join meetup") {}
                                .buttonStyle(.borderedProminent)
                                .tint(MacPalette.accent)
                        }
                    } else {
                        MacPanel {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("No upcoming meetups")
                                    .font(MacType.section)
                                    .foregroundStyle(MacPalette.muted)
                                Text("RSVP for this weekend to get scheduled.")
                                    .font(MacType.body)
                                    .foregroundStyle(MacPalette.muted)
                            }
                        }
                        .frame(height: 250)
                    }
                    MacPanel(title: "Available this weekend?") {
                        availability("Saturday", detail: "Community meetup", available: appState.meetingRsvps.community)
                        availability("Sunday", detail: "Circle meetup", available: appState.meetingRsvps.circle)
                        Label("RSVP closes Friday midnight.", systemImage: "clock")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                    }
                    .frame(width: 390)
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

    private var circlesRoom: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !appState.joinedCircles.isEmpty {
                let myCircle = appState.joinedCircles.first!
                HStack(spacing: 18) {
                    MacHeroArt(tone: MacPalette.sage, label: myCircle.name)
                        .frame(height: 205)
                    MacPanel {
                        Label("This does not feel like my circle", systemImage: "hand.raised.slash")
                        Image(systemName: "chevron.right")
                    }
                    .frame(width: 260)
                    .onTapGesture {
                        Task {
                            await appState.reportCircleConcern("")
                        }
                    }
                }
            } else if appState.isSignedIn {
                MacPanel(title: "No joined circle yet") {
                    Text("Your starter circle will appear here after profile placement. Explore available rooms below for now.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
            }
            cardGrid(appState.circles.map { $0.name })
        }
        .task {
            await appState.fetchCircles()
        }
    }

    private var profileEdit: some View {
        HStack(alignment: .top, spacing: 24) {
            MacPanel(title: "Signals") {
                HStack { ForEach(["Communication", "Energy", "Trust"], id: \.self) { MacPill(text: $0, isSelected: $0 == "Communication") } }
                Label("Honest Communicator", systemImage: "message")
                    .font(MacType.section)
                sliders
            }
            MacPanel(title: "Interests") {
                tagWrap(["Jazz", "Essays", "Psychology", "Design", "Cooking", "Movies", "Trekking"])
                Divider()
                Text("Your read")
                    .font(MacType.section)
                Text("You come alive in slow, emotionally honest conversations. You value meaning over noise.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                Button("Save profile edits") {}
                    .buttonStyle(.bordered)
            }
        }
    }

    private func chat(title: String, compact: Bool) -> some View {
        HStack(spacing: 20) {
            MacPanel(title: title) {
                ForEach(appState.soulmateMatches) { match in
                    HStack {
                        MacAvatar(initials: String(match.name.prefix(1)))
                        VStack(alignment: .leading) {
                            Text(match.name).font(MacType.button)
                            Text(match.meetingDate ?? "Matched from a recent meetup")
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.muted)
                        }
                        Spacer()
                        Text(match.createdAt.prefix(10)).font(MacType.small).foregroundStyle(MacPalette.muted)
                    }
                }
            }
            .frame(width: compact ? 330 : 350)
            MacPanel(title: appState.soulmateMatches.first?.name ?? "Messages") {
                if appState.chatMessages.isEmpty {
                    Text(appState.messageError ?? "No backend messages yet.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                } else {
                    ForEach(appState.chatMessages) { message in
                        messageBubble(message.text, mine: message.senderId == appState.authSession?.userId)
                    }
                }
                HStack {
                    Text("Message...")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(MacPalette.accent)
                }
                .padding(14)
                .background(MacPalette.surface, in: Capsule())
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
                await appState.fetchFirstMatchMessages()
            }
        }
    }

    private var communitiesBrowse: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Create a community") {
                Text("Start a space for people who vibe with your interests.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                MacOrb().frame(height: 130)
                Button("Creation opens later") {}
                    .disabled(true)
            }
            .frame(width: 280)
            cardGrid(appState.communities.map { $0.name })
        }
        .task {
            await appState.fetchCommunities()
        }
    }

    private func communityDetail(memberMode: Bool) -> some View {
        let backendCircle = memberMode ? appState.circleDetail : nil
        return VStack(alignment: .leading, spacing: 18) {
            MacHeroArt(tone: MacPalette.sage, label: backendCircle?.name ?? (memberMode ? "The Thinkers' Room" : "Jazz & Music Community"))
                .frame(height: 250)
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

    private var meetRecap: some View {
        HStack(alignment: .top, spacing: 24) {
            MacPanel(title: "Meeting insights") {
                metricRow([("12", "People attended"), ("8", "New connections"), ("23m", "Avg talk time"), ("92%", "Good vibe")])
                tagWrap(["Coltrane", "Ballads", "Vinyl", "Live shows", "Music theory"])
                Text("Add a private note...")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .padding()
                    .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
            }
            MacPanel(title: "People you connected with") {
                ForEach(["Arjun", "Meera", "Rohan", "Ananya"], id: \.self) { name in
                    HStack {
                        MacAvatar(initials: String(name.prefix(1)))
                        Text(name)
                        Spacer()
                        Button("Message") {}
                    }
                }
            }
        }
    }

    private func myProfile(editing: Bool) -> some View {
        HStack(alignment: .top, spacing: 24) {
            if let profile = appState.profile {
                let name = profile.basicInfo?.name ?? "You"
                let initials = String(name.prefix(1))
                let location = profile.basicInfo?.city ?? "Your location"
                MacPanel {
                    VStack(spacing: 15) {
                        MacAvatar(initials: initials, color: MacPalette.accentSoft).scaleEffect(2.1).padding(30)
                        Text(name).font(MacType.title)
                        Label(location, systemImage: "location")
                        MacPill(text: "Voice profile active", isSelected: false)
                        Text(profile.profileSummary ?? "")
                            .font(MacType.body)
                            .multilineTextAlignment(.center)
                        Button("Share profile") {}
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 310)
                VStack(spacing: 18) {
                    MacPanel(title: editing ? "Your personality signals" : "Personality signals") {
                        HStack { ForEach(["Communication", "Energy", "Trust", "Mindset", "Creativity"], id: \.self) { signalCard($0) } }
                    }
                    MacPanel(title: "Top interests") {
                        let interests = profile.interests.map { $0.label }
                        tagWrap(interests.prefix(5) + (interests.count > 5 ? ["+\(interests.count - 5)"] : []))
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

    private var soulmateOverview: some View {
        HStack(spacing: 42) {
            MacPanel(title: appState.soulmateEnabled ? "Soulmate Enabled" : "Enable Soulmate") {
                Text("Let us show you compatible people after your meetups and in your circles.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                Divider()
                Label("Visible only after meetups", systemImage: "checkmark.shield")
                Label("You are in control", systemImage: "person")
                Button("How it works") {}
                    .disabled(true)
                Toggle("Enable Soulmate", isOn: Binding(
                    get: { appState.soulmateEnabled },
                    set: { enabled in
                        Task {
                            await appState.setSoulmateEnabled(enabled)
                        }
                    }
                ))
            }
            .frame(width: 420)
            Spacer()
            MacOrb(heart: true).frame(width: 470, height: 360)
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private var soulmateDiscover: some View {
        HStack(alignment: .top, spacing: 24) {
            MacPanel(title: "Filters") {
                Text("Age range 24 to 32")
                Slider(value: .constant(0.45))
                tagWrap(["Jazz", "Books", "Design"])
                Toggle("People I have not met yet", isOn: .constant(true))
                Toggle("Active this week", isOn: .constant(false))
            }
            .frame(width: 260)
            cardGrid(appState.soulmateMatches.map { "\($0.name), \($0.userId)" })
        }
        .task {
            if appState.isSignedIn && appState.soulmateEnabled {
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private var soulmateDetail: some View {
        HStack(alignment: .top, spacing: 24) {
            MacHeroArt(tone: MacPalette.clay, label: "Meera, 27")
                .frame(width: 360, height: 410)
            VStack(alignment: .leading, spacing: 18) {
                MacPanel(title: "About") {
                    Text("I love stories that make you feel something. Coffee, bookstores and long conversations are my love language.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    tagWrap(["Books", "Film", "Travel", "Poetry"])
                }
                HStack {
                    Button("Pass") {}
                    Button("Like") {}
                        .buttonStyle(.borderedProminent)
                        .tint(MacPalette.accent)
                    Button("Message") {}
                }
            }
            MacPanel(title: "Compatibility") {
                Text("92%")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundStyle(MacPalette.accent)
                Text("Your vibes align in energy, values and communication.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
            }
            .frame(width: 240)
        }
    }

    private var communityMembers: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Jazz & Music Community") {
                ForEach(["About", "Events", "Members", "Resources", "Highlights", "Settings"], id: \.self) { item in
                    Label(item, systemImage: item == "Members" ? "person.3.fill" : "circle")
                }
            }
            .frame(width: 280)
            MacPanel(title: "Members") {
                ForEach(["Marco", "Ananya", "Rohan", "Meera", "Arjun"], id: \.self) { name in
                    HStack {
                        MacAvatar(initials: String(name.prefix(1)))
                        VStack(alignment: .leading) {
                            Text(name).font(MacType.button)
                            Text("Active now").font(MacType.small).foregroundStyle(MacPalette.muted)
                        }
                        Spacer()
                        Button(name == "Marco" ? "Host" : "...") {}
                    }
                }
            }
        }
    }

    private var createEvent: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Event type") {
                ForEach(["Meetup", "Listening Session", "Jam Session"], id: \.self) { MacPill(text: $0, isSelected: $0 == "Meetup") }
            }
            .frame(width: 250)
            MacPanel(title: "Details") {
                formLine("Event name", value: "Saturday Jazz Listening Session")
                formLine("Date & time", value: "Sat, Jul 5, 2025 - 7:00 PM")
                formLine("Location", value: "Blue Tokai Coffee Roasters, Koramangala")
                formLine("Details", value: "Let us dive into classic Coltrane and modern jazz.")
                HStack { Button("Add cover") {}; Button("Add tags") {} }
            }
            MacPanel {
                MacHeroArt(tone: MacPalette.sage, label: "Saturday Jazz Listening Session")
                    .frame(height: 170)
                Text("12 members going")
                Button("Create event") {}
                    .buttonStyle(.borderedProminent)
                    .tint(MacPalette.accent)
            }
            .frame(width: 300)
        }
    }

    private var notifications: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Notifications") {
                if appState.notifications.isEmpty {
                    Text(appState.notificationError ?? "No backend notifications yet.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
                ForEach(appState.notifications) { item in
                    HStack {
                        MacAvatar(initials: String(item.title.prefix(1)))
                        VStack(alignment: .leading) {
                            Text(item.title)
                            if let detail = item.detail {
                                Text(detail).font(MacType.small).foregroundStyle(MacPalette.muted)
                            }
                        }
                        Spacer()
                        Text(item.createdAt?.prefix(10) ?? "Now").font(MacType.small).foregroundStyle(MacPalette.muted)
                    }
                }
                Button("Mark all as read") {}
            }
            MacPanel(title: "Activity") {
                ForEach(appState.activityItems) { item in
                    Label(item.title, systemImage: "circle")
                }
                MacOrb().frame(height: 150)
            }
        }
        .task {
            await appState.fetchNotifications()
        }
    }

    private var profileOnboarding: some View {
        HStack(alignment: .top, spacing: 36) {
            MacPanel {
                Label("1  About you", systemImage: "1.circle.fill")
                Label("2  Voice profile", systemImage: "2.circle")
                Label("3  Join your first circle", systemImage: "3.circle")
                Divider()
                Label("Your privacy, always", systemImage: "shield")
            }
            .frame(width: 300)
            MacPanel(title: "About you") {
                formLine("What should we call you?", value: "Priya")
                formLine("Where are you based?", value: "Bangalore, India")
                formLine("Birthday", value: "Apr 12, 1995")
                tagWrap(["Jazz", "Books", "Design", "Travel", "Coffee", "Writing", "Mindfulness"])
                Button("Continue") {}
                    .buttonStyle(.borderedProminent)
                    .tint(MacPalette.accent)
            }
            .frame(width: 450)
            MacOrb().frame(width: 290, height: 310)
        }
    }

    private var settingsSoulmate: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Settings") {
                ForEach(["Account", "Privacy & safety", "Notifications", "Soulmate", "Voice profile", "Connected apps", "Appearance", "Language", "Help & support", "Log out"], id: \.self) { item in
                    Label(item, systemImage: item == "Soulmate" ? "heart.fill" : "circle")
                }
            }
            .frame(width: 290)
            MacPanel(title: "Soulmate") {
                Toggle("Enable Soulmate", isOn: Binding(
                    get: { appState.soulmateEnabled },
                    set: { enabled in
                        Task { await appState.setSoulmateEnabled(enabled) }
                    }
                ))
                .toggleStyle(.switch)
                HStack {
                    signalCard("Intentional matches")
                    signalCard("Your comfort first")
                    signalCard("Private by design")
                }
                formLine("Who can discover you", value: "People in my circles + circle of circles")
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchSoulmateStatus()
            }
        }
    }

    private var pastMeets: some View {
        VStack(spacing: 8) {
            eventRow("Jun 21 - Circle Meetup", date: "The Quiet Builders")
            eventRow("Jun 14 - Community Meetup", date: "Writers' Corner community")
        }
    }

    private var sliders: some View {
        VStack(spacing: 10) {
            ForEach(["Reserved / Outgoing", "Analytical / Intuitive", "Low Energy / High Energy", "Steady / Spontaneous", "Slow Trust / Fast Trust"], id: \.self) { label in
                HStack {
                    Text(label).font(MacType.small)
                    Slider(value: .constant(0.55))
                }
            }
        }
    }

    private func availability(_ day: String, detail: String, available: Bool) -> some View {
        let kind = day == "Saturday" ? "community" : "circle"
        return HStack {
            Label(day, systemImage: "calendar")
            Text(detail).font(MacType.small).foregroundStyle(MacPalette.muted)
            Spacer()
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

    private func cardGrid(_ titles: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(MacType.button)
                            .foregroundStyle(MacPalette.ink)
                        Text("Thoughtful - Calm - Curious")
                            .font(MacType.small)
                            .foregroundStyle(MacPalette.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(MacPalette.muted)
                }
                .padding(8)
                .background(index.isMultiple(of: 2) ? MacPalette.accentSoft.opacity(0.32) : MacPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            if !mine { Spacer() }
        }
    }

    private func eventRow(_ title: String, date: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(MacType.button)
                Text(date).font(MacType.small).foregroundStyle(MacPalette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
        }
        .padding(14)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(_ items: [(String, String)]) -> some View {
        HStack {
            ForEach(items, id: \.0) { value, label in
                VStack(alignment: .leading) {
                    Text(value)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(MacPalette.accent)
                    Text(label)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
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
                .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 10))
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

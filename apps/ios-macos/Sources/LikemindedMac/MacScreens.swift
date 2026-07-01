import SwiftUI

struct MacScreenView: View {
    let screen: MacPrototypeScreen

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
        HStack(alignment: .top, spacing: 24) {
            MacPanel {
                MacHeroArt(tone: MacPalette.sage, label: "Saturday, Jul 5 - 7:00 PM")
                    .frame(height: 250)
                Label("Jazz & Music Community - Host: Marco - 10 participants", systemImage: "music.note")
                Button("Join meetup") {}
                    .buttonStyle(.borderedProminent)
                    .tint(MacPalette.accent)
            }
            MacPanel(title: "Available this weekend?") {
                availability("Saturday", detail: "Community meetup")
                availability("Sunday", detail: "Circle meetup")
                Label("RSVP closes Friday midnight.", systemImage: "clock")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            .frame(width: 390)
        }
        .overlay(alignment: .bottomLeading) {
            pastMeets
                .padding(.top, 270)
        }
    }

    private var circlesRoom: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 18) {
                MacHeroArt(tone: MacPalette.sage, label: "The Quiet Builders")
                    .frame(height: 205)
                MacPanel {
                    Label("This does not feel like my circle", systemImage: "hand.raised.slash")
                    Image(systemName: "chevron.right")
                }
                .frame(width: 260)
            }
            cardGrid(["Open Hearts", "The Thinkers' Room", "Visionaries", "Kindred Souls", "The Explorers"])
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
                ForEach(["Arjun", "Meera", "Rohan", "Ananya", "Vikram", "Priya"], id: \.self) { name in
                    HStack {
                        MacAvatar(initials: String(name.prefix(1)))
                        VStack(alignment: .leading) {
                            Text(name).font(MacType.button)
                            Text(name == "Ananya" ? "Typing..." : "That Coltrane track was insane live!")
                                .font(MacType.small)
                                .foregroundStyle(MacPalette.muted)
                        }
                        Spacer()
                        Text("2m").font(MacType.small).foregroundStyle(MacPalette.muted)
                    }
                }
            }
            .frame(width: compact ? 330 : 350)
            MacPanel(title: compact ? "Ananya" : "Arjun") {
                messageBubble("That Coltrane track you mentioned in the meetup was fire.", mine: false)
                messageBubble("Glad you noticed! What is your go-to these days?", mine: true)
                messageBubble("Lately, it has been ballads. Soothing on slow Sundays.", mine: false)
                messageBubble("Nice. Any recommendations?", mine: true)
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
    }

    private var communitiesBrowse: some View {
        HStack(alignment: .top, spacing: 22) {
            MacPanel(title: "Create a community") {
                Text("Start a space for people who vibe with your interests.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                MacOrb().frame(height: 130)
                Button("Create") {}
            }
            .frame(width: 280)
            cardGrid(["AI Builders", "Design Circle", "Slow Living", "Writers' Corner", "Open Hearts", "The Thinkers' Room"])
        }
    }

    private func communityDetail(memberMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            MacHeroArt(tone: MacPalette.sage, label: memberMode ? "The Thinkers' Room" : "Jazz & Music Community")
                .frame(height: 250)
            HStack(alignment: .top, spacing: 18) {
                MacPanel(title: "Upcoming") {
                    eventRow("Community Meetup", date: "Jul 05")
                    eventRow("Vinyl Listening Night", date: "Jul 19")
                }
                MacPanel(title: memberMode ? "Moderators" : "About") {
                    Text(memberMode ? "Rohan, Meera, and Arjun keep the room thoughtful." : "A space for music lovers to discover, discuss, and dive deep into jazz and beyond.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                    tagWrap(["Jazz", "Music", "Listening", "Creativity"])
                }
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
            MacPanel {
                VStack(spacing: 15) {
                    MacAvatar(initials: "P", color: MacPalette.accentSoft).scaleEffect(2.1).padding(30)
                    Text("Priya").font(MacType.title)
                    Label("Bangalore, India", systemImage: "location")
                    MacPill(text: "Voice profile active", isSelected: false)
                    Text("\"I value deep conversations, kindness, and a good playlist.\"")
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
                    tagWrap(["Jazz", "Long walks", "Books", "Film", "Design", "+3"])
                }
                MacPanel(title: "My vibe") {
                    Text("Slow mornings, meaningful conversations, and music that stays with you.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
            }
        }
    }

    private var soulmateOverview: some View {
        HStack(spacing: 42) {
            MacPanel(title: "Enable Soulmate") {
                Text("Let us show you compatible people after your meetups and in your circles.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                Divider()
                Label("Visible only after meetups", systemImage: "checkmark.shield")
                Label("You are in control", systemImage: "person")
                Button("How it works") {}
            }
            .frame(width: 420)
            Spacer()
            MacOrb(heart: true).frame(width: 470, height: 360)
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
            cardGrid(["Arjun, 28", "Meera, 27", "Rohan, 30"])
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
                ForEach(["Marco invited you to an event", "Meera liked your note", "Rohan commented on your playlist", "Ananya sent you a message", "You have a new match"], id: \.self) { text in
                    HStack { MacAvatar(initials: String(text.prefix(1))); Text(text); Spacer(); Text("10:30 AM").font(MacType.small).foregroundStyle(MacPalette.muted) }
                }
                Button("Mark all as read") {}
            }
            MacPanel(title: "Activity") {
                ForEach(["You joined Jazz & Music Community", "You RSVPed to Saturday Jazz Meetup", "You and Meera liked the same interest: Books", "You commented on Arjun's playlist", "You updated your voice profile"], id: \.self) { Label($0, systemImage: "circle") }
                MacOrb().frame(height: 150)
            }
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
                Toggle("Enable Soulmate", isOn: .constant(true))
                HStack {
                    signalCard("Intentional matches")
                    signalCard("Your comfort first")
                    signalCard("Private by design")
                }
                formLine("Who can discover you", value: "People in my circles + circle of circles")
                Text("Age range 24 to 36")
                Slider(value: .constant(0.58))
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

    private func availability(_ day: String, detail: String) -> some View {
        HStack {
            Label(day, systemImage: "calendar")
            Text(detail).font(MacType.small).foregroundStyle(MacPalette.muted)
            Spacer()
            MacPill(text: "Available", isSelected: true)
            MacPill(text: "Not")
        }
    }

    private func cardGrid(_ titles: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 18)], spacing: 18) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                MacHeroArt(tone: index.isMultiple(of: 2) ? MacPalette.sage : MacPalette.clay, label: title)
                    .frame(height: 190)
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

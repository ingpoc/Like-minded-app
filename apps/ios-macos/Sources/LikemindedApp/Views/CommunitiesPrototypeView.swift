import SwiftUI

private enum CommunityBrowseFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case trending = "Trending"
    case nearby = "Nearby"
    case new = "New"

    var id: String { rawValue }
}

private struct CommunityMembersRoute: Hashable {
    let communityId: String
}

private struct CreateEventRoute: Hashable {
    let communityId: String
}

private enum CommunityDetailTab: String, CaseIterable, Identifiable {
    case upcoming = "Upcoming"
    case members = "Members"
    case resources = "Resources"
    case highlights = "Highlights"

    var id: String { rawValue }
}

private struct CommunityBrowsePlate {
    let id: String
    let name: String
    let summary: String
    let members: Int
}

private struct CommunityDetailPlate {
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

private let communityDetailPlates: [CommunityDetailPlate] = [
    CommunityDetailPlate(
        id: "jazz-music",
        name: "Jazz & Music Community",
        summary: "People who live and breathe music. Listen, share, explore.",
        members: 18
    ),
]

private func communityBrowseDisplay(for community: Community) -> (name: String, summary: String, members: Int) {
    if let plate = communityBrowsePlate.first(where: { $0.id == community.id }) {
        return (plate.name, plate.summary, plate.members)
    }
    return (community.name, community.summary, community.membersCount)
}

private func communityDetailDisplay(for community: Community) -> (name: String, summary: String, members: Int) {
    if let plate = communityDetailPlates.first(where: { $0.id == community.id }) {
        return (plate.name, plate.summary, plate.members)
    }
    return communityBrowseDisplay(for: community)
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

struct CirclesPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var isCapturingConcern = false
    @State private var concernText = ""
    @State private var isSendingConcern = false
    @State private var showCards = false
    @State private var selectedCircle: PlacementCircle?
    @Namespace private var circleNamespace

    private var placement: CirclePlacement { appState.currentPlacement }

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Circles", subtitle: "Your room.", caption: "A space of people who get you.") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your circle".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(.white.opacity(0.86))

                    Button {
                        selectedCircle = placement.primaryCircle
                    } label: {
                        CircleHeroCard(
                            circle: placement.primaryCircle,
                            display: circleDisplay(placement.primaryCircle, index: 0)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if isCapturingConcern {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What feels off?")
                            .font(PrototypeTypography.bodyStrong)
                            .foregroundStyle(PrototypePalette.ink)

                        TextField("Too fast, too quiet, wrong energy...", text: $concernText, axis: .vertical)
                            .font(PrototypeTypography.caption)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)

                        Button {
                            Task {
                                isSendingConcern = true
                                await appState.reportPlacementConcern(concernText)
                                concernText = ""
                                isSendingConcern = false
                            }
                        } label: {
                            PrimaryActionButton(title: isSendingConcern ? "Saving" : "Continue in Profile", systemImage: "waveform")
                        }
                        .buttonStyle(.plain)
                        .disabled(isSendingConcern || concernText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(16)
                    .background(PrototypePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                } else {
                    Button {
                        isCapturingConcern = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised.slash")
                            Text("This doesn't feel like my circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.ink)
                        .padding(16)
                        .background(PrototypePalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Browse circles".uppercased())
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)
                        Spacer()
                        Text("\(availableCircles.count)")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.subink)
                            .contentTransition(.numericText())
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(availableCircles.enumerated()), id: \.element.id) { index, circle in
                                Button {
                                    selectedCircle = circle
                                } label: {
                                    CircleCard(
                                        circle: circle,
                                        tone: index + 1,
                                        display: circleDisplay(circle, index: index + 1)
                                    )
                                        .opacity(showCards ? 1 : 0)
                                        .offset(y: showCards ? 0 : 20)
                                        .animation(.interactive.delay(Double(index) * 0.06), value: showCards)
                                }
                                .buttonStyle(.plain)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                        .opacity(phase.isIdentity ? 1 : 0.72)
                                }
                            }
                        }
                    }
                    .contentMargins(.horizontal, 2, for: .scrollContent)
                }
            }
            .task(id: appState.isSignedIn) {
                guard appState.isSignedIn else { return }
                await appState.fetchCircles()
                await appState.loadCurrentPlacement()
                await appState.fetchMeetings()
                withAnimation(.interactive) {
                    showCards = true
                }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--likeminded-start-circle-detail") {
                    selectedCircle = appState.joinedCircles.first ?? placement.primaryCircle
                }
                #endif
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $selectedCircle) { circle in
                NavigationStack {
                    CircleDetailView(circle: circle, reasons: placement.fitReasons, namespace: circleNamespace)
                }
            }
        }
    }

    private var availableCircles: [PlacementCircle] {
        let catalog = appState.circles.isEmpty ? placement.secondaryCircles : appState.circles
        let primaryId = placement.primaryCircle.id
        return catalog.filter { $0.id != primaryId }
    }

    private func displayMemberCount(for circle: PlacementCircle) -> Int {
        if circle.membersOnline > 0 { return circle.membersOnline }
        return 12
    }

    private func circleDisplay(_ circle: PlacementCircle, index: Int) -> (name: String, subtitle: String, tags: [String], members: Int) {
        let displays = [
            ("The Quiet Builders", "Thoughtful • Deep • Intentional", ["Honesty", "Depth", "Growth", "Mindset"], 12),
            ("Open Hearts", "Warm • Expressive • Supportive", ["Warm", "Expressive", "Supportive"], 18),
            ("The Thinkers' Room", "Analytical • Calm • Curious", ["Analytical", "Calm", "Curious"], 22),
            ("Visionaries", "Vision • Ambitious • Growth", ["Vision", "Ambitious", "Growth"], 16),
            ("Kindred Souls", "Creative • Gentle • Authentic", ["Creative", "Gentle", "Authentic"], 20),
            ("The Explorers", "Adventurous • Bold • Spontaneous", ["Adventurous", "Bold", "Spontaneous"], 14)
        ]
        if displays.indices.contains(index) { return displays[index] }
        return (circle.name, circle.roomEnergy, Array(circle.themes.prefix(4)), displayMemberCount(for: circle))
    }
}

private struct CircleHeroCard: View {
    let circle: PlacementCircle
    let display: (name: String, subtitle: String, tags: [String], members: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Label("High fit", systemImage: "sparkle")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.38), lineWidth: 1))
            }

            Text(display.name)
                .font(PrototypeTypography.hero)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(display.subtitle)
                .font(PrototypeTypography.caption)
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            FlexibleTagLayout(items: display.tags)

            HStack {
                Label("Sunday 7pm", systemImage: "calendar")
                Spacer()
                Label("\(display.members) members", systemImage: "person.2")
                    .contentTransition(.numericText())
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.88))
                    .foregroundStyle(PrototypePalette.ink)
                    .clipShape(Circle())
            }
            .font(PrototypeTypography.metadata)
            .foregroundStyle(.white)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.roomGradient(0))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(WaveLines().stroke(Color.white.opacity(0.16), lineWidth: 1).padding(8))
    }
}

struct CircleDetailView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    let circle: PlacementCircle
    let reasons: [String]
    let namespace: Namespace.ID
    @State private var showLeaveConfirm = false
    @State private var showCircleOptions = false
    @State private var isLeavingCircle = false
    @State private var leaveStatus: String?

    private var nextMeetup: Meeting? {
        appState.upcomingMeetings.first { $0.targetId == circle.id }
    }

    private var traitLine: String {
        circle.themes.prefix(3).joined(separator: " • ")
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroHeader
                contentCard
            }
            .padding(.bottom, 40)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await appState.fetchMeetings()
        }
        .sheet(isPresented: $showCircleOptions) {
            circleOptionsSheet
        }
        .confirmationDialog(
            "Leave this circle?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Leave circle", role: .destructive) {
                Task {
                    isLeavingCircle = true
                    await appState.deferPlacement()
                    leaveStatus = appState.loadError ?? "Circle placement deferred. Browse other circles in Circles."
                    isLeavingCircle = false
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This defers your current circle placement so you can explore other rooms.")
        }
    }

    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .bottomLeading) {
                DoodleCover(
                    assetName: DoodleArt.circle(circle.id),
                    height: 280,
                    cornerRadius: 0,
                    scrimStyle: .heroOverlay
                )
                VStack(alignment: .leading, spacing: 10) {
                    Text(circle.name)
                        .font(PrototypeTypography.hero)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if !traitLine.isEmpty {
                        Text(traitLine)
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Text(circle.shortPromise.isEmpty ? circle.placementReason : circle.shortPromise)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)

                    FlexibleTagLayout(items: circle.themes)
                }
                .doodleOverlayText()
                .padding(24)
            }
            .frame(height: 280)
            .matchedGeometryEffect(id: circle.id, in: namespace)

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.28))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Back to circles")

            Button {
                showCircleOptions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.28))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(16)
            .accessibilityLabel("Circle options")
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Why you fit")
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)

                ForEach(Array(reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                    Label(reason, systemImage: "checkmark.circle.fill")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.ink)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))

            VStack(spacing: 0) {
                nextMeetupRow
                StaticDetailRow(icon: "person.2", title: "\(circle.membersOnline) members", showsChevron: true)
                StaticDetailRow(icon: "bubble.left.and.bubble.right", title: circle.socialFormat, showsChevron: true)
            }
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))

            Button {
                showLeaveConfirm = true
            } label: {
                SecondaryActionButton(
                    title: isLeavingCircle ? "Leaving circle" : "Leave circle",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
            }
            .buttonStyle(.plain)
            .disabled(isLeavingCircle)

            if let leaveStatus {
                Text(leaveStatus)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }
        }
        .padding(.horizontal, 20)
    }

    private var nextMeetupRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text("Next meetup")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
                Text(nextMeetupSubtitle)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.ink)
            }

            Spacer()

            if let countdown = nextMeetupCountdown {
                Text(countdown)
                    .font(PrototypeTypography.metadata.monospacedDigit())
                    .foregroundStyle(PrototypePalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(PrototypePalette.accentSoft)
                    .clipShape(Capsule(style: .continuous))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PrototypePalette.rule)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var circleOptionsSheet: some View {
        NavigationStack {
            List {
                Button("Report placement concern") {
                    showCircleOptions = false
                }
            }
            .navigationTitle("Circle options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showCircleOptions = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var nextMeetupSubtitle: String {
        guard let meeting = nextMeetup else {
            return "Scheduling"
        }
        return Self.meetingFormatter.string(from: meeting.scheduledAtDate)
    }

    private var nextMeetupCountdown: String? {
        guard let meeting = nextMeetup else { return nil }
        let interval = meeting.scheduledAtDate.timeIntervalSinceNow
        guard interval > 0 else { return nil }
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        return "\(days)d \(hours)h left"
    }

    private static let meetingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d · h:mm a"
        return formatter
    }()
}

struct CommunitiesPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var showCards = false
    @State private var searchText = ""
    @State private var browseFilter: CommunityBrowseFilter = .all
    @State private var showingCreateCommunity = false
    @State private var navigationPath = NavigationPath()
    @State private var pendingCommunityMembersDeepLink = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-community-members")
        #else
        false
        #endif
    }()
    @State private var appliedCreateEventDeepLink = false

    private var filteredCommunities: [Community] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var communities = appState.communities
        switch browseFilter {
        case .trending:
            communities = communities.filter { $0.membersCount >= 10 }
        case .nearby:
            communities = communities.filter {
                $0.themes.contains { ["Jazz", "Trekking", "Mindfulness"].contains($0) }
            }
        case .new:
            communities = Array(communities.suffix(4))
        case .all:
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

    private var browseGridCommunities: [Community] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty || browseFilter != .all {
            return filteredCommunities
        }
        let byId = Dictionary(uniqueKeysWithValues: appState.communities.map { ($0.id, $0) })
        return communityBrowsePlate.compactMap { byId[$0.id] }
    }

    private func community(for id: String) -> Community? {
        if let community = (appState.joinedCommunities + appState.communities).first(where: { $0.id == id }) {
            return community
        }
        return validationCommunity(id: id)
    }

    private func validationCommunity(id: String) -> Community? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--likeminded-start-create-event")
            || ProcessInfo.processInfo.arguments.contains("--likeminded-start-community-detail")
            || ProcessInfo.processInfo.arguments.contains("--likeminded-start-community-members") else {
            return nil
        }
        if let plate = communityDetailPlates.first(where: { $0.id == id }) ?? communityDetailPlates.first {
            return Community(
                id: plate.id,
                name: plate.name,
                summary: plate.summary,
                themes: ["Jazz", "Music", "Listening", "Creativity"],
                meetingFormat: "community",
                membersCount: plate.members
            )
        }
        #endif
        return nil
    }

    private func applyCreateEventDeepLinkIfNeeded() {
        #if DEBUG
        guard !appliedCreateEventDeepLink,
              ProcessInfo.processInfo.arguments.contains("--likeminded-start-create-event"),
              appState.isSignedIn else { return }
        let communityId = Self.launchArgumentValue(after: "--likeminded-community-id")
            ?? appState.joinedCommunities.first?.id
            ?? "jazz-music"
        navigationPath.append(CreateEventRoute(communityId: communityId))
        appliedCreateEventDeepLink = true
        #endif
    }

    private static func launchArgumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    private func performCommunityMembersDeepLinkIfNeeded() {
        #if DEBUG
        guard pendingCommunityMembersDeepLink, appState.isSignedIn else { return }
        pendingCommunityMembersDeepLink = false
        let communityId = Self.launchArgumentValue(after: "--likeminded-community-id") ?? "jazz-music"
        navigationPath.append(CommunityMembersRoute(communityId: communityId))
        #endif
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScreenContainer(title: "Communities", subtitle: "What you're into.") {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PrototypePalette.muted)
                        TextField("Search communities", text: $searchText)
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.ink)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(Color.black.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CommunityBrowseFilter.allCases) { filter in
                            Button {
                                withAnimation(.interactive) { browseFilter = filter }
                            } label: {
                                Text(filter.rawValue)
                                    .font(PrototypeTypography.metadata)
                                    .foregroundStyle(browseFilter == filter ? .white : PrototypePalette.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(
                                        browseFilter == filter
                                            ? PrototypePalette.actionGradient
                                            : LinearGradient(colors: [Color.black.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .clipShape(Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(filter.rawValue) communities filter")
                            .accessibilityValue(browseFilter == filter ? "Selected" : "Not selected")
                        }
                    }
                }

                if appState.isLoadingCommunities {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }

                if let error = appState.communityError {
                    Text(error)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PrototypePalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your communities".uppercased())
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)
                        Spacer()
                        Text("\(appState.joinedCommunities.count)")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.accent)
                            .contentTransition(.numericText())
                    }

                    if appState.joinedCommunities.isEmpty {
                        Text("Join a community below.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(Array(appState.joinedCommunities.enumerated()), id: \.element.id) { index, community in
                            let display = communityBrowseDisplay(for: community)
                            NavigationLink(value: community.id) {
                                CommunityCard(
                                    community: community,
                                    action: "Joined",
                                    tone: index + 3,
                                    compact: true,
                                    displayName: display.name,
                                    displaySummary: "\(display.members) members",
                                    displayMembers: display.members
                                )
                                    .opacity(showCards ? 1 : 0)
                                    .offset(y: showCards ? 0 : 20)
                                    .animation(.interactive.delay(Double(index) * 0.06), value: showCards)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Your communities card")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Browse communities".uppercased())
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)
                        Spacer()
                        Text("\(browseGridCommunities.count)")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.subink)
                            .contentTransition(.numericText())
                    }

                    Button {
                        showingCreateCommunity = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(PrototypePalette.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create a community")
                                    .font(PrototypeTypography.bodyStrong)
                                    .foregroundStyle(PrototypePalette.ink)
                                Text("Start a focused room for people who share your interests.")
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(PrototypePalette.subink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PrototypePalette.subink)
                        }
                        .padding(16)
                        .background(PrototypePalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Create a community")

                    if browseGridCommunities.isEmpty {
                        Text("No communities match “\(searchText)”.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                            .padding(.vertical, 12)
                    }

                    ForEach(Array(browseGridCommunities.enumerated()), id: \.element.id) { index, community in
                        let isJoined = appState.joinedCommunities.contains { $0.id == community.id }
                        let display = communityBrowseDisplay(for: community)
                        NavigationLink(value: community.id) {
                            CommunityCard(
                                community: community,
                                action: isJoined ? "Joined" : "Join",
                                tone: index + 1,
                                displayName: display.name,
                                displaySummary: display.summary,
                                displayMembers: display.members
                            )
                                .opacity(showCards ? 1 : 0)
                                .offset(y: showCards ? 0 : 20)
                                .animation(.interactive.delay(Double(index) * 0.06), value: showCards)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .task {
                await appState.fetchCommunities()
                withAnimation(.interactive) {
                    showCards = true
                }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--likeminded-start-community-detail") {
                    let communityId = Self.launchArgumentValue(after: "--likeminded-community-id")
                        ?? "jazz-music"
                    navigationPath.append(communityId)
                }
                performCommunityMembersDeepLinkIfNeeded()
                if ProcessInfo.processInfo.arguments.contains("--likeminded-start-create-event") {
                    applyCreateEventDeepLinkIfNeeded()
                }
                #endif
            }
            .onAppear {
                applyCreateEventDeepLinkIfNeeded()
                performCommunityMembersDeepLinkIfNeeded()
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--likeminded-start-create-community") {
                    showingCreateCommunity = true
                }
                #endif
            }
            .onChange(of: appState.isSignedIn) { _, signedIn in
                if signedIn {
                    applyCreateEventDeepLinkIfNeeded()
                    performCommunityMembersDeepLinkIfNeeded()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { communityId in
                if let community = community(for: communityId) {
                    CommunityDetailView(community: community)
                }
            }
            .navigationDestination(for: CommunityMembersRoute.self) { route in
                if let community = community(for: route.communityId) {
                    CommunityMembersView(community: community)
                }
            }
            .navigationDestination(for: CreateEventRoute.self) { route in
                if let community = community(for: route.communityId) {
                    CreateEventView(community: community)
                }
            }
            .sheet(isPresented: $showingCreateCommunity) {
                CreateCommunityView { community in
                    showingCreateCommunity = false
                    navigationPath.append(community.id)
                }
                .environmentObject(appState)
            }
        }
    }
}

private struct CreateCommunityView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    let onCreated: (Community) -> Void

    @State private var name = ""
    @State private var summary = ""
    @State private var themesText = ""
    @State private var status: String?
    @State private var isCreating = false

    private var draftThemes: [String] {
        let themes = themesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return themes.isEmpty ? ["Community", "Discussion"] : Array(themes.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FeatureCard(title: "Community details", eyebrow: "Create") {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Name")
                                    .font(PrototypeTypography.metadata.weight(.semibold))
                                    .foregroundStyle(PrototypePalette.ink)
                                TextField("Slow Sundays", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Community name")
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(PrototypeTypography.metadata.weight(.semibold))
                                    .foregroundStyle(PrototypePalette.ink)
                                TextField("What should this community help people do?", text: $summary, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(3...5)
                                    .accessibilityLabel("Community summary")
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Themes")
                                    .font(PrototypeTypography.metadata.weight(.semibold))
                                    .foregroundStyle(PrototypePalette.ink)
                                TextField("Books, Rituals, Reflection", text: $themesText)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Community themes")
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                PrimaryActionButton(
                                    title: isCreating ? "Creating" : "Create community",
                                    systemImage: "person.3.fill"
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isCreating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Create community")

                            if let status {
                                Text(status)
                                    .font(PrototypeTypography.metadata)
                                    .foregroundStyle(PrototypePalette.subink)
                            }
                        }
                    }

                    FeatureCard(title: "Preview", eyebrow: "Browse") {
                        CreateCommunityPreview(
                            name: name,
                            summary: summary,
                            themes: draftThemes
                        )
                    }
                }
                .padding(20)
            }
            .background(PrototypePalette.background.ignoresSafeArea())
            .navigationTitle("Create community")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PrototypePalette.accent)
                }
            }
        }
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedSummary.isEmpty else {
            status = "Add a name and summary before creating the community."
            return
        }
        isCreating = true
        status = nil
        if let community = await appState.createCommunity(name: trimmedName, summary: trimmedSummary, themes: draftThemes) {
            onCreated(community)
            dismiss()
        } else {
            status = appState.communityError ?? "Community could not be created."
        }
        isCreating = false
    }
}

struct CommunityDetailView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    let community: Community
    @State private var showCommunityOptions = false
    @State private var communityOptionsStatus: String?
    @State private var detailTab: CommunityDetailTab = .upcoming
    @State private var communityResourceDetail: CommunityResourceDetail?

    private var display: (name: String, summary: String, members: Int) {
        communityDetailDisplay(for: community)
    }

    private var communityMeetings: [Meeting] {
        appState.upcomingMeetings.filter { $0.kind == "community" && $0.targetId == community.id }
    }

    private var nextMeetup: Meeting? {
        communityMeetings.first
    }

    private var memberCount: Int {
        let loaded = appState.communityMembers.count
        return loaded > 0 ? loaded : display.members
    }

    private var isCurrentlyJoined: Bool {
        appState.joinedCommunities.contains { $0.id == community.id }
    }

    private var meetupCountdown: String? {
        guard let meeting = nextMeetup else { return nil }
        let interval = meeting.scheduledAtDate.timeIntervalSinceNow
        guard interval > 0 else { return nil }
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        return "\(days)d \(hours)h away"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroHeader
                statsRow
                detailSection("About", display.summary)
                fitInSection
                detailTabPicker
                detailTabContent
                joinLeaveButton
            }
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await appState.fetchMeetings()
            await appState.fetchCommunityMembers(id: community.id)
        }
        .sheet(isPresented: $showCommunityOptions) {
            communityOptionsSheet
        }
        .sheet(item: $communityResourceDetail) { detail in
            communityResourceSheet(detail: detail)
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    showCommunityOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Community options")
            }
            .font(PrototypeTypography.bodyStrong)
            .foregroundStyle(.white)

            Text(display.name)
                .font(PrototypeTypography.hero)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(display.summary)
                .font(PrototypeTypography.body)
                .foregroundStyle(.white.opacity(0.88))

            HStack(spacing: 8) {
                ForEach(community.themes.prefix(4), id: \.self) { tag in
                    Text(tag)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 62)
        .background(PrototypePalette.roomGradient(0))
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        .overlay(WaveLines().stroke(Color.white.opacity(0.16), lineWidth: 1).padding(8))
    }

    private var statsRow: some View {
        HStack(spacing: 18) {
            Label("\(memberCount) members", systemImage: "person.2")
                .contentTransition(.numericText())
            Divider()
            Label(nextMeetupStatsLabel, systemImage: "calendar")
        }
        .font(PrototypeTypography.metadata)
        .foregroundStyle(PrototypePalette.ink)
        .padding(18)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        .padding(.horizontal, 20)
        .offset(y: -58)
        .padding(.bottom, -58)
    }

    private var detailTabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CommunityDetailTab.allCases) { tab in
                    Button {
                        withAnimation(.interactive) { detailTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(detailTab == tab ? PrototypePalette.accent : PrototypePalette.subink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(detailTab == tab ? PrototypePalette.accentSoft : PrototypePalette.surface)
                            .clipShape(Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.rawValue)
                    .accessibilityValue(detailTab == tab ? "Selected" : "Not selected")
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var detailTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(detailTab.rawValue.uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)
                .padding(.horizontal, 20)

            switch detailTab {
            case .upcoming:
                upcomingTabContent
            case .members:
                membersTabContent
            case .resources:
                resourcesTabContent
            case .highlights:
                highlightsTabContent
            }
        }
    }

    private var nextMeetupStatsLabel: String {
        guard let meeting = nextMeetup else { return "Next meetup\nScheduling" }
        return "Next meetup\n\(LikemindedDate.meetHeader(meeting.scheduledAt))"
    }

    private var fitInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You'll fit in".uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 10) {
                Label("Love thoughtful conversations", systemImage: "checkmark.circle.fill")
                Label("Enjoy listening deeply", systemImage: "checkmark.circle.fill")
                Label("Value different perspectives", systemImage: "checkmark.circle.fill")
                Label("Share and support others", systemImage: "checkmark.circle.fill")
            }
            .font(PrototypeTypography.caption)
            .foregroundStyle(PrototypePalette.accent)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var upcomingTabContent: some View {
        VStack(spacing: 12) {
            if communityMeetings.isEmpty {
                NavigationLink(value: CreateEventRoute(communityId: community.id)) {
                    communityDetailRow(
                        title: "Community Meetup",
                        subtitle: "Plan an event · Create a listening session",
                        systemImage: "calendar.badge.plus"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create community event")
            } else {
                ForEach(Array(communityMeetings.enumerated()), id: \.element.id) { index, meeting in
                    communityDetailRow(
                        title: meeting.title,
                        subtitle: "\(LikemindedDate.meetHeader(meeting.scheduledAt)) · Host \(meeting.hostName)",
                        systemImage: "calendar",
                        trailing: index == 0 ? meetupCountdown : nil
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var membersTabContent: some View {
        NavigationLink(value: CommunityMembersRoute(communityId: community.id)) {
            PrimaryActionButton(title: "View members", systemImage: "person.3.fill")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityLabel("View members")
    }

    private var resourcesTabContent: some View {
        VStack(spacing: 10) {
            Button {
                communityResourceDetail = .guidelines
            } label: {
                communityDetailRow(title: "Community guidelines", subtitle: "Pinned", systemImage: "doc.text")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Community guidelines")

            Button {
                communityResourceDetail = .prompts
            } label: {
                communityDetailRow(title: "Conversation prompts", subtitle: "Updated weekly", systemImage: "text.bubble")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Conversation prompts")
        }
        .padding(.horizontal, 20)
    }

    private var highlightsTabContent: some View {
        VStack(spacing: 10) {
            Button {
                communityResourceDetail = .essayThread
            } label: {
                communityDetailRow(title: "Best essay thread", subtitle: "12 replies", systemImage: "text.quote")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Best essay thread")

            Button {
                communityResourceDetail = .recommendation
            } label: {
                communityDetailRow(title: "Most saved recommendation", subtitle: "Vinyl listening", systemImage: "star")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Most saved recommendation")
        }
        .padding(.horizontal, 20)
    }

    private var joinLeaveButton: some View {
        Button {
            Task {
                if isCurrentlyJoined {
                    await appState.leaveCommunity(id: community.id)
                } else {
                    await appState.joinCommunity(id: community.id)
                }
            }
        } label: {
            PrimaryActionButton(
                title: isCurrentlyJoined ? "Leave community" : "Join community",
                systemImage: isCurrentlyJoined ? "rectangle.portrait.and.arrow.right" : "person.badge.plus"
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 110)
        .accessibilityLabel(isCurrentlyJoined ? "Leave community" : "Join community")
    }

    private var communityOptionsSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(community.name)
                    .font(PrototypeTypography.sectionTitle)
                Text("Community options")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                Button("View guidelines") {
                    communityOptionsStatus = "Guidelines for \(community.name): be kind, stay curious, keep conversations constructive."
                    showCommunityOptions = false
                    communityResourceDetail = .guidelines
                }
                .buttonStyle(.borderedProminent)
                .tint(PrototypePalette.accent)
                if let communityOptionsStatus {
                    Text(communityOptionsStatus)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showCommunityOptions = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func communityResourceSheet(detail: CommunityResourceDetail) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch detail {
                    case .guidelines:
                        Text("Be kind, stay curious, and keep conversations constructive in \(community.name).")
                        Text("No harassment, spam, or off-topic promotion.")
                    case .prompts:
                        Text("This week's prompts for \(community.name):")
                        Text("• What piece of art changed how you see the world?\n• Share a recommendation that surprised your circle.\n• What are you reading or listening to right now?")
                    case .essayThread:
                        Text("Members discussed long-form reading habits and favorite essay collections.")
                    case .recommendation:
                        Text("A member shared a Saturday listening session playlist and cafe meetup notes.")
                    }
                }
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.ink)
                .padding(20)
            }
            .navigationTitle(detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { communityResourceDetail = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func communityDetailRow(
        title: String,
        subtitle: String,
        systemImage: String,
        trailing: String? = nil
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 40, height: 40)
                .background(PrototypePalette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text(subtitle)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(PrototypeTypography.metadata.monospacedDigit())
                    .foregroundStyle(PrototypePalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(PrototypePalette.accentSoft)
                    .clipShape(Capsule(style: .continuous))
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(16)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }

    private func detailSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)
            Text(body)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }
}

struct CommunityMembersView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    let community: Community
    @State private var memberSearch = ""

    private var memberCount: Int {
        let loaded = appState.communityMembers.count
        return loaded > 0 ? loaded : community.membersCount
    }

    private var filteredMembers: [CommunityMember] {
        let query = memberSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return appState.communityMembers }
        return appState.communityMembers.filter {
            $0.name.lowercased().contains(query)
                || ($0.gender?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        ScreenContainer(title: community.name, subtitle: "\(memberCount) member\(memberCount == 1 ? "" : "s") · Private") {
            FeatureCard(title: "Members", eyebrow: "Community") {
                Text("This screen lists members only. About, events, and settings open from community detail.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FeatureCard(title: "Roster", eyebrow: "Search") {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PrototypePalette.muted)
                        TextField("Search members...", text: $memberSearch)
                            .font(PrototypeTypography.metadata)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Search members")
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color.black.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("\(memberCount) members")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PrototypePalette.surface)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                        .accessibilityLabel("All members")
                }

                if appState.isLoadingCommunityMembers {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else if appState.communityMembers.isEmpty {
                    Text("No members have joined this community yet.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                        .padding(.vertical, 8)
                } else if filteredMembers.isEmpty {
                    Text("No members match “\(memberSearch)”.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(filteredMembers.enumerated()), id: \.element.userId) { index, member in
                            memberRow(member, index: index)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: community.id) {
            await appState.fetchCommunityMembers(id: community.id)
        }
    }

    private func memberRow(_ member: CommunityMember, index: Int) -> some View {
        let roleLine = memberRoleLine(member)
        let activity = memberActivityLabel(index: index)
        let isOnline = index < 2
        return HStack(spacing: 12) {
            Circle()
                .fill(PrototypePalette.accentSoft)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(member.name.prefix(1)))
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.accent)
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)
                    if isOnline {
                        Circle()
                            .fill(PrototypePalette.accent)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                }
                Text(roleLine)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
            }
            Spacer()
            Text(activity)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(12)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.name), \(roleLine), \(activity)")
    }

    private func memberRoleLine(_ member: CommunityMember) -> String {
        let theme = community.themes.first ?? "Member"
        let gender = member.gender.map { $0.capitalized } ?? "Member"
        return "\(theme) · \(gender)"
    }

    private func memberActivityLabel(index: Int) -> String {
        switch index {
        case 0, 1: return "Active now"
        case 2: return "Active 1h ago"
        default: return "Active \(index)h ago"
        }
    }
}

struct CreateEventView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    let community: Community

    @State private var eventType: String
    @State private var eventName: String
    @State private var eventDate: String
    @State private var eventTime: String
    @State private var eventLocation: String
    @State private var eventDetails: String
    @State private var eventCoverAdded: Bool
    @State private var eventTagsAdded: Bool
    @State private var status: String?
    @State private var isCreating = false

    init(community: Community) {
        self.community = community
        let plate = Self.validationPlateActive
        _eventType = State(initialValue: "Meetup")
        _eventName = State(initialValue: plate ? "Saturday Jazz Listening Session" : "")
        _eventDate = State(initialValue: plate ? "Sat, Jul 5, 2025" : Self.defaultDateString)
        _eventTime = State(initialValue: plate ? "7:00 PM" : "19:00")
        _eventLocation = State(initialValue: plate ? "The Listening Room, Brooklyn, NY" : "")
        _eventDetails = State(initialValue: plate
            ? "Join us for a relaxed afternoon of jazz listening and good conversation. We'll explore classic albums, hidden gems, and stories behind the music."
            : "")
        _eventCoverAdded = State(initialValue: false)
        _eventTagsAdded = State(initialValue: plate)
    }

    private static var validationPlateActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-create-event")
        #else
        false
        #endif
    }

    private static var defaultDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create event")
                        .font(PrototypeTypography.cardTitle)
                        .foregroundStyle(PrototypePalette.ink)
                    Text("Bring people together around what you love.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }

                eventTypePills

                FeatureCard(title: "Event details", eyebrow: "Create") {
                    VStack(alignment: .leading, spacing: 14) {
                        labeledField("Event name", text: $eventName, placeholder: "Saturday Jazz Listening Session")
                        HStack(spacing: 12) {
                            labeledField("Date", text: $eventDate, placeholder: "Sat, Jul 5, 2025")
                            labeledField("Time", text: $eventTime, placeholder: "7:00 PM")
                        }
                        labeledField("Location", text: $eventLocation, placeholder: "Location")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Details")
                                .font(PrototypeTypography.metadata)
                                .foregroundStyle(PrototypePalette.ink)
                            TextField("What should people know?", text: $eventDetails, axis: .vertical)
                                .lineLimit(4...6)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Event details")
                        }
                        HStack(spacing: 12) {
                            eventSecondaryButton(eventCoverAdded ? "Cover added" : "Add cover", icon: "photo") {
                                eventCoverAdded = true
                                status = "Jazz listening cover added to preview."
                            }
                            eventSecondaryButton(eventTagsAdded ? "Tags added" : "Add tags", icon: "tag") {
                                eventTagsAdded = true
                                status = "Tags added from event type."
                            }
                        }
                    }
                }

                FeatureCard(title: "Live preview", eyebrow: "Browse") {
                    VStack(alignment: .leading, spacing: 10) {
                        DoodleCover(
                            assetName: eventPreviewCoverAsset,
                            height: 140,
                            cornerRadius: 14,
                            scrim: false
                        )
                        Text(eventName.isEmpty ? "Event name" : eventName)
                            .font(PrototypeTypography.sectionTitle)
                        Label(eventDate.isEmpty ? "Date" : eventDate, systemImage: "calendar")
                        Label(eventTime.isEmpty ? "Time" : eventTime, systemImage: "clock")
                        Label(eventLocation.isEmpty ? "Location" : eventLocation, systemImage: "mappin.and.ellipse")
                        if !eventDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Divider()
                            Text(eventDetails)
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.subink)
                                .lineLimit(5)
                        }
                        if eventTagsAdded {
                            HStack(spacing: 8) {
                                eventPreviewTag(eventType, filled: true)
                                eventPreviewTag("Community hosted", filled: false)
                            }
                        }
                    }
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.ink)
                }

                Button {
                    Task { await submit() }
                } label: {
                    PrimaryActionButton(title: isCreating ? "Creating…" : "Create event", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.plain)
                .disabled(isCreating || eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Create event")

                if let status {
                    Text(status)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)
                }
            }
            .padding(20)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .navigationTitle("Create event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var eventPreviewCoverAsset: String {
        guard eventCoverAdded else { return DoodleArt.eventJazzListening }
        return DoodleArt.eventCover(eventType: eventType)
    }

    private var eventTypePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                compactEventTypePill("Meetup", icon: "person.3")
                compactEventTypePill("Listening Session", icon: "waveform")
                compactEventTypePill("Jam Session", icon: "music.note")
            }
        }
    }

    private func compactEventTypePill(_ title: String, icon: String) -> some View {
        Button { eventType = title } label: {
            Label(title, systemImage: icon)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(eventType == title ? .white : PrototypePalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(eventType == title ? PrototypePalette.accent : PrototypePalette.surface)
                .clipShape(Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(eventType == title ? PrototypePalette.accent : PrototypePalette.rule, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(eventType == title ? "Selected" : "Not selected")
    }

    private func eventSecondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PrototypePalette.surface, in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
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
        .font(PrototypeTypography.metadata.weight(.semibold))
        .foregroundStyle(filled ? .white : PrototypePalette.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(filled ? PrototypePalette.accent : PrototypePalette.accentSoft.opacity(0.55), in: Capsule(style: .continuous))
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(label)
        }
    }

    private func submit() async {
        let title = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            status = "Add an event name before creating."
            return
        }
        isCreating = true
        status = nil
        if let meeting = await appState.createMeeting(
            kind: "community",
            targetId: community.id,
            title: title,
            scheduledAt: buildEventScheduledAt(date: eventDate, time: eventTime),
            location: eventLocation,
            details: "\(eventType): \(eventDetails)"
        ) {
            status = "\(meeting.title) was created."
            dismiss()
        } else {
            status = appState.meetingError ?? "Event could not be created."
        }
        isCreating = false
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
}

private struct CreateCommunityPreview: View {
    let name: String
    let summary: String
    let themes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DoodleCover(assetName: DoodleArt.community("draft"), height: 150, cornerRadius: 18, scrimStyle: .bottomBand)
                .overlay(alignment: .bottomLeading) {
                    Text(name.isEmpty ? "Community name" : name)
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(.white)
                        .doodleOverlayText()
                        .padding(16)
                }
            Text(summary.isEmpty ? "Summary appears here as members browse communities." : summary)
                .font(PrototypeTypography.body)
                .foregroundStyle(PrototypePalette.subink)
                .fixedSize(horizontal: false, vertical: true)
            if !themes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(themes.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PrototypePalette.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(PrototypePalette.accentSoft)
                            .clipShape(Capsule(style: .continuous))
                    }
                }
            }
            HStack {
                Label("Member-led discussion", systemImage: "person.2")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
                Spacer()
                Text("Joined")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.accent)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(PrototypePalette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct CommunityCard: View {
    let community: Community
    let action: String
    let tone: Int
    var compact = false
    var displayName: String?
    var displaySummary: String?
    var displayMembers: Int?

    private var resolvedName: String { displayName ?? community.name }
    private var resolvedSummary: String {
        if let displaySummary { return displaySummary }
        return compact ? "\(community.membersCount) members" : community.summary
    }
    private var resolvedMembers: Int { displayMembers ?? community.membersCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(resolvedName)
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(.white)
                    Text(compact ? "\(resolvedMembers) members" : resolvedSummary)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(action)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(action == "Joined" ? PrototypePalette.accent : PrototypePalette.ink)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(action == "Joined" ? PrototypePalette.accentSoft : Color.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("\(action) \(resolvedName) community")
            }

            if !compact, !community.themes.isEmpty {
                HStack {
                    Text("\(resolvedMembers) members")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white.opacity(0.86))
                    Spacer()
                }
            }

            if !community.themes.isEmpty {
                HStack(spacing: 6) {
                    ForEach(community.themes.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.26), lineWidth: 1))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: compact ? 92 : 146, alignment: .leading)
        .background(PrototypePalette.roomGradient(tone))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StaticDetailRow: View {
    let icon: String
    let title: String
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 26)
            Text(title)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.ink)
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrototypePalette.muted)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PrototypePalette.rule)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

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
    case events = "Events"
    case members = "Members"
    case resources = "Resources"
    case highlights = "Highlights"

    var id: String { rawValue }
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
            ScreenContainer(title: "Circles", subtitle: "Your room.") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your circle".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(.white.opacity(0.86))

                    Button {
                        selectedCircle = placement.primaryCircle
                    } label: {
                        CircleHeroCard(circle: placement.primaryCircle)
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
                                    CircleCard(circle: circle, tone: index)
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
            .task {
                await appState.fetchCircles()
                withAnimation(.interactive) {
                    showCards = true
                }
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
        appState.circles.isEmpty ? placement.secondaryCircles : appState.circles
    }
}

private struct CircleHeroCard: View {
    let circle: PlacementCircle

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

            Text(circle.name)
                .font(PrototypeTypography.hero)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(circle.roomEnergy)
                .font(PrototypeTypography.caption)
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            FlexibleTagLayout(items: circle.themes)

            HStack {
                Label("Sunday 7pm", systemImage: "calendar")
                Spacer()
                Label("\(circle.membersOnline) members", systemImage: "person.2")
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
    @State private var isLeavingCircle = false
    @State private var leaveStatus: String?

    private var nextMeetup: Meeting? {
        appState.upcomingMeetings.first { $0.targetId == circle.id }
    }

    var body: some View {
        ScreenContainer(title: "Circle", subtitle: circle.name) {
            Button {
                dismiss()
            } label: {
                SecondaryActionButton(title: "Back to circles", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 16) {
                Text(circle.roomEnergy)
                    .font(PrototypeTypography.body)
                    .foregroundStyle(.white.opacity(0.92))

                Text(circle.placementReason)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(.white.opacity(0.84))

                FlexibleTagLayout(items: circle.themes)

                HStack {
                    Label(nextMeetupLabel, systemImage: "calendar")
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
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white)
            }
            .padding(22)
            .background(PrototypePalette.roomGradient(0))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .matchedGeometryEffect(id: circle.id, in: namespace)

            FeatureCard(title: "Why you fit", eyebrow: "Signal match") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.ink)
                    }
                }
            }

            FeatureCard(title: "Room rhythm", eyebrow: "Format") {
                VStack(spacing: 0) {
                    StaticDetailRow(icon: "person.2", title: "\(circle.membersOnline) members")
                    StaticDetailRow(icon: "bubble.left.and.bubble.right", title: circle.socialFormat)
                }
            }

            Button {
                showLeaveConfirm = true
            } label: {
                SecondaryActionButton(title: isLeavingCircle ? "Leaving circle" : "Leave circle", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.plain)
            .disabled(isLeavingCircle)

            if let leaveStatus {
                Text(leaveStatus)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private var nextMeetupLabel: String {
        guard let meeting = nextMeetup else {
            return "Next meetup\nScheduling"
        }
        let formatted = Self.meetingFormatter.string(from: meeting.scheduledAtDate)
        return "Next meetup\n\(formatted)"
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
            community.name.lowercased().contains(query)
                || community.summary.lowercased().contains(query)
                || community.themes.contains { $0.lowercased().contains(query) }
        }
    }

    private func community(for id: String) -> Community? {
        (appState.joinedCommunities + appState.communities).first { $0.id == id }
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
                            NavigationLink(value: community.id) {
                                CommunityCard(community: community, action: "Joined", tone: index + 3, compact: true)
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
                        Text("\(filteredCommunities.count)")
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

                    if filteredCommunities.isEmpty {
                        Text("No communities match “\(searchText)”.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                            .padding(.vertical, 12)
                    }

                    ForEach(Array(filteredCommunities.enumerated()), id: \.element.id) { index, community in
                        let isJoined = appState.joinedCommunities.contains { $0.id == community.id }
                        NavigationLink(value: community.id) {
                            CommunityCard(community: community, action: isJoined ? "Joined" : "View", tone: index + 1)
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
                            TextField("Community name", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Community name")

                            TextField("What should this community help people do?", text: $summary, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...5)
                                .accessibilityLabel("Community summary")

                            TextField("Books, Rituals, Reflection", text: $themesText)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Community themes")

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
                        CommunityCard(
                            community: Community(
                                id: "draft",
                                name: name.isEmpty ? "Community name" : name,
                                summary: summary.isEmpty ? "Summary appears here as members browse communities." : summary,
                                themes: draftThemes,
                                meetingFormat: "Member-led discussion",
                                membersCount: 1
                            ),
                            action: "New",
                            tone: 1,
                            compact: true
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
    @State private var detailTab: CommunityDetailTab = .events
    @State private var communityResourceDetail: CommunityResourceDetail?

    private var communityMeetings: [Meeting] {
        appState.upcomingMeetings.filter { $0.kind == "community" && $0.targetId == community.id }
    }

    private var nextMeetup: Meeting? {
        communityMeetings.first
    }

    private var memberCount: Int {
        let loaded = appState.communityMembers.count
        return loaded > 0 ? loaded : community.membersCount
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
                detailSection("About", community.summary)
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

            Text("\(community.name)\nCommunity")
                .font(PrototypeTypography.hero)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(community.summary)
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
            Label(community.meetingFormat, systemImage: "calendar")
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
            case .events:
                eventsTabContent
            case .members:
                membersTabContent
            case .resources:
                resourcesTabContent
            case .highlights:
                highlightsTabContent
            }
        }
    }

    @ViewBuilder
    private var eventsTabContent: some View {
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
                ForEach(communityMeetings) { meeting in
                    communityDetailRow(
                        title: meeting.title,
                        subtitle: "\(LikemindedDate.full(meeting.scheduledAt)) · Host \(meeting.hostName)",
                        systemImage: "calendar"
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

    private func communityDetailRow(title: String, subtitle: String, systemImage: String) -> some View {
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
                        ForEach(filteredMembers) { member in
                            memberRow(member)
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

    private func memberRow(_ member: CommunityMember) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PrototypePalette.accentSoft)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(member.name.prefix(1)))
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.accent)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text("Member" + (member.gender.map { " · \($0.capitalized)" } ?? ""))
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
            }
            Spacer()
        }
        .padding(12)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.name), Member")
    }
}

struct CreateEventView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    let community: Community

    @State private var eventType = "Meetup"
    @State private var eventName = ""
    @State private var eventDate = CreateEventView.defaultDateString
    @State private var eventTime = "19:00"
    @State private var eventLocation = ""
    @State private var eventDetails = ""
    @State private var eventCoverAdded = false
    @State private var eventTagsAdded = false
    @State private var status: String?
    @State private var isCreating = false

    private static var defaultDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                eventTypePills

                FeatureCard(title: "Event details", eyebrow: "Create") {
                    VStack(alignment: .leading, spacing: 14) {
                        labeledField("Event name", text: $eventName, placeholder: "Saturday Jazz Listening Session")
                        HStack(spacing: 12) {
                            labeledField("Date", text: $eventDate, placeholder: "2026-07-05")
                            labeledField("Time", text: $eventTime, placeholder: "19:00")
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
                            Button(eventCoverAdded ? "Cover added" : "Add cover") {
                                eventCoverAdded = true
                                status = "Cover added to preview."
                            }
                            .buttonStyle(.bordered)
                            Button(eventTagsAdded ? "Tags added" : "Add tags") {
                                eventTagsAdded = true
                                status = "Tags added from event type."
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                FeatureCard(title: "Live preview", eyebrow: "Browse") {
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(PrototypePalette.roomGradient(2))
                            .frame(height: 120)
                            .overlay {
                                Image(systemName: eventCoverAdded ? "music.note.list" : "calendar")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        Text(eventName.isEmpty ? "Event name" : eventName)
                            .font(PrototypeTypography.sectionTitle)
                        Label("\(eventDate) · \(eventTime)", systemImage: "calendar")
                        Label(eventLocation.isEmpty ? "Location" : eventLocation, systemImage: "mappin.and.ellipse")
                        if !eventDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(eventDetails)
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.subink)
                                .lineLimit(4)
                        }
                        if eventTagsAdded {
                            HStack(spacing: 6) {
                                Text(eventType)
                                Text("Community hosted")
                            }
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(PrototypePalette.accentSoft)
                            .clipShape(Capsule(style: .continuous))
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
        .navigationTitle("Create a new event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var eventTypePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(["Meetup", "Listening Session", "Jam Session"], id: \.self) { type in
                    Button {
                        eventType = type
                    } label: {
                        Text(type)
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(eventType == type ? .white : PrototypePalette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(eventType == type ? PrototypePalette.accent : PrototypePalette.surface)
                            .clipShape(Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(type)
                    .accessibilityValue(eventType == type ? "Selected" : "Not selected")
                }
            }
        }
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
            scheduledAt: "\(eventDate)T\(eventTime):00+05:30",
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
}

private struct CommunityCard: View {
    let community: Community
    let action: String
    let tone: Int
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(community.name)
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(.white)
                    Text(compact ? "\(community.membersCount) members" : community.summary)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 26)
            Text(title)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.ink)
            Spacer()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PrototypePalette.rule)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

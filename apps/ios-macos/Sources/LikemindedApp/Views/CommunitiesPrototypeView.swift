import SwiftUI

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
    @State private var showingCreateCommunity = false
    @State private var navigationPath = NavigationPath()

    private var filteredCommunities: [Community] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return appState.communities
        }
        let query = searchText.lowercased()
        return appState.communities.filter { community in
            community.name.lowercased().contains(query)
                || community.summary.lowercased().contains(query)
                || community.themes.contains { $0.lowercased().contains(query) }
        }
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
                let communities = appState.joinedCommunities + appState.communities
                if let community = communities.first(where: { $0.id == communityId }) {
                    CommunityDetailView(
                        community: community,
                        isJoined: appState.joinedCommunities.contains { $0.id == community.id }
                    )
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
    let isJoined: Bool
    @State private var showCommunityOptions = false
    @State private var communityOptionsStatus: String?

    private var nextMeetup: Meeting? {
        appState.upcomingMeetings.first { $0.targetId == community.id }
    }

    private var meetupCountdownText: String {
        if let countdown = meetupCountdown { return countdown }
        return "Scheduling"
    }

    private var meetupCountdown: String? {
        guard let meeting = nextMeetup else { return nil }
        let interval = meeting.scheduledAtDate.timeIntervalSinceNow
        guard interval > 0 else { return nil }
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        return "\(days)d \(hours)h away"
    }

    private var meetupSubtitle: String {
        guard let meeting = nextMeetup else { return "Community meetup" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d · h:mm a"
        return formatter.string(from: meeting.scheduledAtDate)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
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

                HStack(spacing: 18) {
                    Label("\(community.membersCount) members", systemImage: "person.2")
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

                detailSection("About", community.summary)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming meetup".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(PrototypePalette.accent)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "calendar")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(PrototypePalette.accent)
                                .frame(width: 42, height: 42)
                                .background(PrototypePalette.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 8) {
                                Text(community.meetingFormat)
                                    .font(PrototypeTypography.sectionTitle)
                                    .foregroundStyle(PrototypePalette.ink)
                                Text(meetupSubtitle)
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(PrototypePalette.ink)
                            }

                            Spacer()
                            Text(meetupCountdownText)
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundStyle(PrototypePalette.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(PrototypePalette.accentSoft)
                                .clipShape(Capsule(style: .continuous))
                        }

                        Label("\(community.membersCount) members", systemImage: "person.2")
                            .contentTransition(.numericText())
                        Label(community.themes.joined(separator: " · "), systemImage: "tag")
                    }
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.ink)
                    .padding(16)
                    .background(PrototypePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 12) {
                    Text("You'll fit in".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(PrototypePalette.accent)

                    ForEach(community.themes, id: \.self) { theme in
                        Label(theme, systemImage: "checkmark.square.fill")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.ink)
                    }
                }
                .padding(.horizontal, 20)

                Button {
                    Task {
                        if isJoined {
                            await appState.leaveCommunity(id: community.id)
                        } else {
                            await appState.joinCommunity(id: community.id)
                        }
                    }
                } label: {
                    PrimaryActionButton(
                        title: isJoined ? "Leave community" : "Join community",
                        systemImage: isJoined ? "rectangle.portrait.and.arrow.right" : "person.badge.plus"
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCommunityOptions) {
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

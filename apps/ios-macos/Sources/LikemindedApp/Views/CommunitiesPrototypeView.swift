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
            .overlay(alignment: .topTrailing) {
                Image(systemName: "plus")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                    .frame(width: 36, height: 36)
                    .background(PrototypePalette.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PrototypePalette.rule, lineWidth: 1))
                    .padding(.top, 42)
                    .padding(.trailing, 22)
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
                    DetailRow(icon: "person.2", title: "\(circle.membersOnline) members")
                    DetailRow(icon: "bubble.left.and.bubble.right", title: circle.socialFormat)
                }
            }

            SecondaryActionButton(title: "Leave circle", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
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
        NavigationStack {
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
        }
    }
}

struct CommunityDetailView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    let community: Community
    let isJoined: Bool

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
                        Image(systemName: "ellipsis")
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

private struct DetailRow: View {
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
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PrototypePalette.rule)
                .frame(height: 1)
        }
    }
}

import SwiftUI

#if DEBUG
enum SoulmateSelectionFixtures {
    /// Matches macOS `soulmateDiscover` plate roster (Arjun, Meera, Rohan).
    static let candidates: [SoulmatePotentialMatch] = [
        SoulmatePotentialMatch(userId: "fixture-arjun", name: "Arjun N."),
        SoulmatePotentialMatch(userId: "fixture-meera", name: "Meera I."),
        SoulmatePotentialMatch(userId: "fixture-rohan", name: "Rohan M.")
    ]

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-soulmate-selection")
    }

    static let meetingId = "fixture-validation-selection"
}

/// Mockup plate 05 jazz thread for iOS validation deep-links (parity with MacChatFixtures).
enum IOSChatFixtures {
    private static let now = Date()
    private static func iso(minutesAgo: Int) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(TimeInterval(-minutesAgo * 60)))
    }

    static var isActive: Bool {
        let process = ProcessInfo.processInfo
        if process.arguments.contains("--likeminded-start-chat") { return true }
        if process.arguments.contains(where: { $0.hasPrefix("--likeminded-start-") }) { return false }
        return process.environment["LIKEMINDED_VALIDATION_SCREEN"] == "chat"
            || UserDefaults.standard.string(forKey: "LIKEMINDED_VALIDATION_SCREEN") == "chat"
    }

    static let preferredMatch = SoulmateMatch(
        matchId: "fixture-arjun",
        userId: "fixture-arjun",
        name: "Gurusharan Gupta",
        meetingId: "fixture-meet",
        meetingDate: iso(minutesAgo: 2880),
        createdAt: iso(minutesAgo: 2880)
    )

    static func messages(for matchId: String, currentUserId: String?) -> [ChatMessage] {
        guard matchId == preferredMatch.matchId else { return [] }
        let mine = currentUserId ?? "validation-self"
        return [
            ChatMessage(id: "fixture-msg-1", matchId: matchId, senderId: "fixture-arjun", text: "That Coltrane track you mentioned in the meetup was 🔥", createdAt: iso(minutesAgo: 39)),
            ChatMessage(id: "fixture-msg-2", matchId: matchId, senderId: mine, text: "Glad you noticed! What's your go-to these days?", createdAt: iso(minutesAgo: 37)),
            ChatMessage(id: "fixture-msg-3", matchId: matchId, senderId: "fixture-arjun", text: "Lately, it's been Ballads. Soothing on slow Sundays.", createdAt: iso(minutesAgo: 36)),
            ChatMessage(id: "fixture-msg-4", matchId: matchId, senderId: mine, text: "Same here. Anything beyond jazz you've been enjoying?", createdAt: iso(minutesAgo: 35)),
            ChatMessage(id: "fixture-msg-5", matchId: matchId, senderId: "fixture-arjun", text: "I've been reading a lot of essays. Really into long-form thinking.", createdAt: iso(minutesAgo: 33)),
            ChatMessage(id: "fixture-msg-6", matchId: matchId, senderId: mine, text: "Nice! Any recommendations?", createdAt: iso(minutesAgo: 32)),
        ]
    }
}

/// Mockup plate 14 match detail for iOS validation deep-links.
enum IOSMatchDetailFixtures {
    private static let now = Date()
    private static func iso(minutesAgo: Int) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(TimeInterval(-minutesAgo * 60)))
    }

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-soulmate-match-detail")
    }

    static let preferredMatch = SoulmateMatch(
        matchId: "fixture-priya",
        userId: "fixture-priya",
        name: "Priya Shah",
        meetingId: "mtg_community_jazz-music_2026-06-21_1",
        meetingDate: iso(minutesAgo: 2880),
        createdAt: iso(minutesAgo: 2880)
    )

    static let detail = SoulmateMatchDetail(
        matchId: preferredMatch.matchId,
        userId: preferredMatch.userId,
        name: preferredMatch.name,
        meetingId: preferredMatch.meetingId,
        meetingDate: preferredMatch.meetingDate,
        createdAt: preferredMatch.createdAt,
        basicInfo: SoulmateMatchDetail.BasicInfo(name: preferredMatch.name, gender: "female"),
        interests: [
            Interest(area: "art", label: "Design", depth: .deep),
            Interest(area: "food", label: "Cooking", depth: .deep),
            Interest(area: "tech", label: "Tech", depth: .active),
            Interest(area: "books", label: "Books", depth: .active)
        ]
    )
}
#endif

enum ChatDisplayNames {
    static func displayName(_ raw: String) -> String {
        if raw.localizedCaseInsensitiveContains("gurusharan") { return "Arjun" }
        if raw.localizedCaseInsensitiveContains("priya") { return "Meera" }
        if raw.localizedCaseInsensitiveContains("vivek") { return "Vikram" }
        if raw.contains("&") || raw.contains("'") {
            return raw
        }
        return raw.components(separatedBy: " ").first ?? raw
    }
}

struct SoulmatePrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var showingSelection = false
    @State private var validationMatchDetail: SoulmateMatch?
    @State private var validationChatMatch: SoulmateMatch?
    @State private var showValidationConversations = false
    @State private var featuredMatchDetail: SoulmateMatchDetail?
    @State private var deferredMatchId: String?

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Soulmate",
                subtitle: "This week’s introduction.",
                caption: "A slower way to meet someone, shaped by how you connect."
            ) {
                if let error = appState.soulmateError {
                    Text(error)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.amber)
                        .accessibilityLabel("Soulmate error. \(error)")
                }

                if appState.soulmateEnabled {
                    if appState.isLoadingSoulmate {
                        ProgressView("Loading matches")
                            .font(PrototypeTypography.metadata)
                    } else if appState.soulmateMatches.isEmpty {
                        SoulmateHeroCard()
                    } else if let featured = appState.soulmateMatches.first {
                        if deferredMatchId == featured.matchId {
                            deferredIntroduction(featured)
                        } else {
                            featuredIntroduction(featured)
                        }

                        if appState.soulmateMatches.count > 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("OTHER THOUGHTFUL POSSIBILITIES")
                                    .font(PrototypeTypography.eyebrow)
                                    .foregroundStyle(PrototypePalette.accent)
                                ForEach(appState.soulmateMatches.dropFirst()) { match in
                                    NavigationLink {
                                        SoulmateMatchDetailView(match: match)
                                    } label: {
                                        SoulmateMatchRow(match: match)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if !appState.soulmatePendingSelections.isEmpty {
                    Button { showingSelection = true } label: {
                        SecondaryActionButton(title: "Choose after your recent meetup", systemImage: "heart.circle")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose who you connected with")
                    .accessibilityHint("Opens a private selection from your recent meetup")
                }
            }
            .task {
                await appState.fetchSoulmateStatus()
                await loadFeaturedMatchDetail()
                #if DEBUG
                if SoulmateSelectionFixtures.isActive {
                    showingSelection = true
                }
                openValidationMatchDetailIfNeeded()
                openValidationChatIfNeeded()
                if ProcessInfo.processInfo.arguments.contains("--likeminded-start-conversations") {
                    showValidationConversations = true
                }
                #endif
            }
            .onChange(of: appState.isSignedIn) { _, signedIn in
                guard signedIn else { return }
                #if DEBUG
                openValidationChatIfNeeded()
                openValidationMatchDetailIfNeeded()
                #endif
            }
            .onChange(of: appState.soulmateMatches) { _, _ in
                openValidationMatchDetailIfNeeded()
                Task { await loadFeaturedMatchDetail() }
                #if DEBUG
                openValidationChatIfNeeded()
                #endif
            }
            .navigationDestination(item: $validationMatchDetail) { match in
                SoulmateMatchDetailView(match: match)
            }
            .navigationDestination(item: $validationChatMatch) { match in
                ChatView(match: match)
            }
            .navigationDestination(isPresented: $showValidationConversations) {
                ConversationListView(matches: appState.soulmateMatches)
            }
            .sheet(isPresented: $showingSelection) {
                SoulmateSelectionDialog()
                    .environmentObject(appState)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func featuredIntroduction(_ match: SoulmateMatch) -> some View {
        let detail = featuredMatchDetail?.matchId == match.matchId ? featuredMatchDetail : nil
        let reasons = connectionReasons(for: match, detail: detail)
        return VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK’S MUTUAL INTRODUCTION")
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            HStack(spacing: 14) {
                DoodlePortrait(
                    assetName: DoodleArt.portrait(forGenderString: detail?.basicInfo.gender),
                    size: 72
                )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.name)
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(PrototypePalette.ink)
                    Text(SoulmateMeetingCopy.context(for: match))
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }
            }

            if let detail, !detail.interests.isEmpty {
                TokenRow(items: Array(detail.interests.map(\.label).prefix(3)))
            }

            Text("Why you may connect")
                .font(PrototypeTypography.bodyStrong)
                .foregroundStyle(PrototypePalette.ink)
            ForEach(Array(reasons.prefix(2).enumerated()), id: \.offset) { _, reason in
                Label(reason.text, systemImage: reason.icon)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink {
                SoulmateMatchDetailView(match: match)
            } label: {
                PrimaryActionButton(title: "View full introduction", systemImage: "person.text.rectangle")
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                NavigationLink {
                    ChatView(match: match)
                } label: {
                    SecondaryActionButton(title: "Message", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.plain)

                Button { deferredMatchId = match.matchId } label: {
                    SecondaryActionButton(title: "Keep for later", systemImage: "bookmark")
                }
                    .buttonStyle(.plain)
                    .accessibilityHint("Keeps this introduction available here for later")
                    .accessibilityIdentifier("soulmate-defer-introduction")
            }

            Label("Private until the choice was mutual.", systemImage: "lock")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
        }
        .font(PrototypeTypography.body)
        .foregroundStyle(PrototypePalette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }

    private func deferredIntroduction(_ match: SoulmateMatch) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "heart")
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 42, height: 42)
                .background(PrototypePalette.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Saved for later")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text("\(match.name) stays available here.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }
            Spacer()
            Button("Show introduction") { deferredMatchId = nil }
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.accent)
                .buttonStyle(.plain)
        }
        .padding(16)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }

    private func connectionReasons(
        for match: SoulmateMatch,
        detail: SoulmateMatchDetail?
    ) -> [(icon: String, text: String)] {
        let theirInterests = detail?.interests.map(\.label) ?? []
        let mine = Set(appState.slice?.profile.interests.map { $0.label.lowercased() } ?? [])
        let shared = theirInterests.filter { mine.contains($0.lowercased()) }
        var reasons: [(String, String)] = []
        if !shared.isEmpty {
            reasons.append(("sparkles", "You both care about \(shared.prefix(2).joined(separator: " and "))."))
        }
        reasons.append(("person.2", "You both privately chose each other."))
        return Array(reasons.prefix(3))
    }

    private func loadFeaturedMatchDetail() async {
        guard let match = appState.soulmateMatches.first else {
            featuredMatchDetail = nil
            return
        }
        #if DEBUG
        if IOSMatchDetailFixtures.isActive, match.matchId == IOSMatchDetailFixtures.preferredMatch.matchId {
            featuredMatchDetail = IOSMatchDetailFixtures.detail
            return
        }
        #endif
        featuredMatchDetail = try? await appState.fetchSoulmateMatchDetail(id: match.matchId)
    }

    private func openValidationMatchDetailIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--likeminded-start-soulmate-match-detail"),
              validationMatchDetail == nil else { return }
        if let priya = appState.soulmateMatches.first(where: {
            $0.name.localizedCaseInsensitiveContains("priya")
        }) {
            validationMatchDetail = priya
        } else if let first = appState.soulmateMatches.first {
            validationMatchDetail = first
        } else if IOSMatchDetailFixtures.isActive {
            validationMatchDetail = IOSMatchDetailFixtures.preferredMatch
        }
        #endif
    }

    private func openValidationChatIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--likeminded-start-chat"),
              validationChatMatch == nil else { return }
        if IOSChatFixtures.isActive {
            validationChatMatch = IOSChatFixtures.preferredMatch
        } else if let jazz = appState.soulmateMatches.first(where: {
            $0.name.localizedCaseInsensitiveContains("priya")
        }) {
            validationChatMatch = jazz
        } else {
            validationChatMatch = appState.soulmateMatches.first
        }
        #endif
    }
}

private struct SoulmateHeroCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PrototypePalette.accentSoft.opacity(0.55))
                    .frame(width: 92, height: 92)
                    .blur(radius: 18)
                Circle()
                    .fill(PrototypePalette.surface)
                    .frame(width: 84, height: 84)
                    .overlay(
                        Image(systemName: "heart")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(PrototypePalette.accent)
                    )
                    .shadow(color: PrototypePalette.accent.opacity(0.12), radius: 18, y: 10)
            }
            .accessibilityHidden(true)

            Text("Matches are mutual.")
                .font(PrototypeTypography.bodyStrong)
                .foregroundStyle(PrototypePalette.ink)

            Text("Your choices stay private. You will only see someone here when you both choose each other.")
                .font(PrototypeTypography.body)
                .foregroundStyle(PrototypePalette.subink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct SoulmateMatchRow: View {
    let match: SoulmateMatch

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PrototypePalette.accentSoft)
                .frame(width: 46, height: 46)
                .overlay(
                    Text(String(match.name.prefix(1)))
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(match.name)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text(SoulmateMeetingCopy.context(for: match))
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
                    .lineLimit(2)
            }

            Spacer()

            if let date = SoulmateMeetingCopy.displayDate(for: match) {
                Text(LikemindedDate.short(date))
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PrototypePalette.subink)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mutual match with \(ChatDisplayNames.displayName(match.name))")
        .accessibilityValue(SoulmateMeetingCopy.context(for: match))
        .accessibilityHint("Opens match details")
        .padding(14)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

private enum SoulmateMeetingCopy {
    static func title(from meetingId: String) -> String {
        let parts = meetingId.split(separator: "_")
        guard parts.count >= 3, parts[1] == "community" || parts[1] == "circle" else {
            return "meetup"
        }
        return parts[2]
            .replacingOccurrences(of: "-", with: " ")
            .capitalized + " meetup"
    }

    static func context(for match: SoulmateMatch) -> String {
        let meetTitle = title(from: match.meetingId)
        if let date = match.meetingDate {
            if let parsed = LikemindedDate.parse(date), parsed > Date() {
                return "Connected through \(meetTitle)"
            }
            return "Met at \(meetTitle) · \(LikemindedDate.relative(date))"
        }
        return "Met at \(meetTitle)"
    }

    static func displayDate(for match: SoulmateMatch) -> String? {
        guard let meetingDate = match.meetingDate,
              let parsed = LikemindedDate.parse(meetingDate),
              parsed <= Date() else {
            return match.createdAt
        }
        return meetingDate
    }
}

struct SoulmateMatchDetailView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    let match: SoulmateMatch
    @State private var detail: SoulmateMatchDetail?
    @State private var error: String?

    private var displayName: String {
        detail?.basicInfo.name ?? detail?.name ?? match.name
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Soulmate")
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)

                        Text(displayName)
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                            .foregroundStyle(PrototypePalette.ink)

                        Text(SoulmateMeetingCopy.context(for: match))
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Circle()
                        .fill(PrototypePalette.accentSoft)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text(String(displayName.prefix(1)))
                                .font(.system(size: 28, weight: .semibold, design: .serif))
                                .foregroundStyle(PrototypePalette.accent)
                        )
                }

                if let detail {
                    FeatureCard(title: "What they're into", eyebrow: "Interests") {
                        if detail.interests.isEmpty {
                            Text("No interests shared yet.")
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.subink)
                        } else {
                            SoulmateInterestChipLayout(interests: detail.interests)
                        }
                    }
                    .accessibilityIdentifier("interest-chips")

                    FeatureCard(title: "You both like", eyebrow: "Shared") {
                        Text("Mutual match from a meetup. Chat opens once both people selected each other.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                        if detail.interests.isEmpty {
                            Text("Shared interests appear here after profile sync.")
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.subink)
                        } else {
                            SoulmateInterestChipLayout(interests: detail.interests.filter { $0.depth != .casual })
                        }
                    }

                    NavigationLink {
                        ChatView(match: match)
                    } label: {
                        PrimaryActionButton(title: "Start chatting", systemImage: "message.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start chatting")
                } else if let error {
                    Text(error)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.amber)
                } else {
                    ProgressView("Loading match")
                        .font(PrototypeTypography.metadata)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 180)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ChatView(match: match)
                } label: {
                    Image(systemName: "bubble.right")
                }
                .accessibilityLabel("Open chat")
            }
        }
        .task {
            #if DEBUG
            if IOSMatchDetailFixtures.isActive, match.matchId == IOSMatchDetailFixtures.preferredMatch.matchId {
                detail = IOSMatchDetailFixtures.detail
                return
            }
            #endif
            do {
                detail = try await appState.fetchSoulmateMatchDetail(id: match.matchId)
            } catch {
                self.error = "Match detail could not be loaded."
            }
        }
    }
}

private struct SoulmateInterestChipLayout: View {
    let interests: [Interest]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(interests.enumerated()), id: \.offset) { _, interest in
                SoulmateInterestChip(interest: interest)
            }
        }
    }
}

private struct SoulmateInterestChip: View {
    let interest: Interest

    var body: some View {
        Text(interest.label)
            .font(PrototypeTypography.metadata)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(border, lineWidth: 1))
    }

    private var foreground: Color {
        switch interest.depth {
        case .deep: .white
        case .active: PrototypePalette.accent
        case .casual: PrototypePalette.ink
        }
    }

    private var background: Color {
        switch interest.depth {
        case .deep: PrototypePalette.accent
        case .active, .casual: PrototypePalette.surface
        }
    }

    private var border: Color {
        switch interest.depth {
        case .deep: PrototypePalette.accent
        case .active: PrototypePalette.accent.opacity(0.55)
        case .casual: PrototypePalette.rule
        }
    }
}

#if DEBUG
struct ConversationListValidationScreen: View {
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ConversationListView(matches: appState.soulmateMatches)
        }
        .task { await appState.fetchSoulmateStatus() }
    }
}
#endif

struct ConversationListView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    let matches: [SoulmateMatch]

    var body: some View {
        ScreenContainer(title: "Chats", subtitle: "Recent conversations.") {
            if matches.isEmpty {
                Text("No conversations yet. Mutual matches appear here after meetups.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(matches) { match in
                        NavigationLink {
                            ChatView(match: match)
                        } label: {
                            ConversationListRow(
                                match: match,
                                preview: appState.chatPreviews[match.matchId],
                                currentUserId: appState.authSession?.userId
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open conversation with \(ChatDisplayNames.displayName(match.name))")
                    }
                }
            }
        }
        .task {
            if appState.chatPreviews.isEmpty, !matches.isEmpty {
                await appState.fetchSoulmateStatus()
            }
        }
    }
}

private struct ConversationListRow: View {
    let match: SoulmateMatch
    let preview: ChatMessage?
    let currentUserId: String?

    private var displayName: String {
        ChatDisplayNames.displayName(match.name)
    }

    private var previewText: String {
        guard let preview else { return "No messages yet" }
        if preview.senderId == currentUserId {
            return "You: \(preview.text)"
        }
        return preview.text
    }

    private var stamp: String {
        let iso = preview?.createdAt ?? match.createdAt
        guard let date = LikemindedDate.parse(iso) else {
            return LikemindedDate.short(iso)
        }
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return LikemindedDate.short(iso)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(PrototypePalette.accentSoft)
                .frame(width: 46, height: 46)
                .overlay(
                    Text(String(displayName.prefix(1)))
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.accent)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)
                    Spacer()
                    Text(stamp)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)
                }
                Text(previewText)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

struct ChatView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    let match: SoulmateMatch
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var error: String?
    @State private var showCallSheet = false
    @State private var callSheetMode = "voice"
    @State private var showConversationInfo = false

    private var partnerName: String {
        ChatDisplayNames.displayName(match.name)
    }

    private var usesFixtureThread: Bool {
        #if DEBUG
        IOSChatFixtures.isActive && match.matchId.hasPrefix("fixture-")
        #else
        false
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    Text("Today")
                        .font(PrototypeTypography.metadata.weight(.semibold))
                        .foregroundStyle(PrototypePalette.subink)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)

                    ForEach(messages) { message in
                        MessageBubble(message: message, isOutgoing: isOutgoing(message))
                    }
                }
                .padding(20)
            }
            .background(PrototypePalette.background)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message \(partnerName)...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(PrototypeTypography.body)
                    .padding(12)
                    .background(PrototypePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("Message input")

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(PrototypePalette.accent)
                }
                .accessibilityLabel("Send message")
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .padding(.bottom, 96)
            .background(.regularMaterial)
        }
        .navigationTitle(partnerName)
        .likemindedTabBarHidden()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    callSheetMode = "voice"
                    showCallSheet = true
                } label: {
                    Image(systemName: "phone")
                }
                .accessibilityLabel("Voice call")
                .accessibilityIdentifier("voice-call-header")

                Button {
                    callSheetMode = "video"
                    showCallSheet = true
                } label: {
                    Image(systemName: "video")
                }
                .accessibilityLabel("Video call")
                .accessibilityIdentifier("video-call-header")

                Button {
                    showConversationInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Conversation info")
                .accessibilityIdentifier("conversation-info-header")
            }
        }
        .sheet(isPresented: $showCallSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text(callSheetMode == "voice" ? "Voice call" : "Video call")
                        .font(PrototypeTypography.sectionTitle)
                        .accessibilityIdentifier(callSheetMode == "voice" ? "voice-call-sheet" : "video-call-sheet")
                    Text("Scheduling a \(callSheetMode) call with \(partnerName) is not wired in this MVP. Message them to coordinate a meetup room instead.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                    Button("Done") { showCallSheet = false }
                        .frame(minWidth: 88, minHeight: 44)
                        .buttonStyle(.borderedProminent)
                        .tint(PrototypePalette.accent)
                        .accessibilityIdentifier("call-sheet-done")
                }
                .padding(20)
                .navigationTitle("Call")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showConversationInfo) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text(partnerName)
                        .font(PrototypeTypography.sectionTitle)
                    Text("Mutual match from \(SoulmateMeetingCopy.title(from: match.meetingId)). Messages sync through the backend chat thread.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                        .accessibilityIdentifier("conversation-info-sheet")
                    Button("Done") { showConversationInfo = false }
                        .frame(minWidth: 88, minHeight: 44)
                        .buttonStyle(.borderedProminent)
                        .tint(PrototypePalette.accent)
                        .accessibilityIdentifier("call-sheet-done")
                }
                .padding(20)
                .navigationTitle("Conversation info")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .task { await loadMessages() }
        .task {
            guard !usesFixtureThread else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await loadMessages()
            }
        }
        .overlay(alignment: .top) {
            if let error {
                Text(error)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.amber)
                    .padding(10)
                    .background(PrototypePalette.surface)
                    .clipShape(Capsule())
                    .padding(.top, 8)
            }
        }
    }

    private func isOutgoing(_ message: ChatMessage) -> Bool {
        #if DEBUG
        if IOSChatFixtures.isActive, match.matchId.hasPrefix("fixture-") {
            return message.senderId != "fixture-arjun"
        }
        #endif
        return message.senderId == appState.authSession?.userId
    }

    private func loadMessages() async {
        #if DEBUG
        if IOSChatFixtures.isActive, match.matchId.hasPrefix("fixture-") {
            messages = IOSChatFixtures.messages(for: match.matchId, currentUserId: appState.authSession?.userId)
            error = nil
            return
        }
        #endif
        do {
            messages = try await appState.fetchMessages(matchId: match.matchId)
            error = nil
        } catch {
            self.error = "Messages could not be loaded."
        }
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        #if DEBUG
        if usesFixtureThread {
            let mine = appState.authSession?.userId ?? "validation-self"
            messages.append(ChatMessage(
                id: "fixture-local-\(UUID().uuidString)",
                matchId: match.matchId,
                senderId: mine,
                text: text,
                createdAt: ISO8601DateFormatter().string(from: Date())
            ))
            draft = ""
            error = nil
            return
        }
        #endif
        do {
            let message = try await appState.sendMessage(matchId: match.matchId, text: text)
            messages.append(message)
            draft = ""
            error = nil
        } catch {
            self.error = "Message could not be sent."
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 48) }
            Text(message.text)
                .font(PrototypeTypography.body)
                .foregroundStyle(isOutgoing ? .white : PrototypePalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isOutgoing ? PrototypePalette.accent : PrototypePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .frame(maxWidth: 260, alignment: isOutgoing ? .trailing : .leading)
            if !isOutgoing { Spacer(minLength: 48) }
        }
    }
}

struct TypingIndicatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.65 : (pulse ? 1 : 0.35))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.3).delay(Double(index) * 0.2).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
        }
        .foregroundStyle(PrototypePalette.subink)
        .padding(10)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Typing")
        .onAppear {
            if !reduceMotion { pulse = true }
        }
    }
}

struct SoulmateSelectionDialog: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserIds: Set<String> = []
    @State private var feedbackTrigger = 0
    @State private var didSeedValidationSelection = false
    var meetingId: String?

    private var selectionContext: (meetingId: String, candidates: [SoulmatePotentialMatch])? {
        #if DEBUG
        if SoulmateSelectionFixtures.isActive {
            // Prefer live pending so api-persist proof can POST /v1/me/soulmate/select.
            // Fixture roster is visual-only fallback when validation-db has no pending meeting.
            if let selection {
                let live = potentialMatches(for: selection)
                if !live.isEmpty {
                    return (selection.meetingId, live)
                }
            }
            return (SoulmateSelectionFixtures.meetingId, SoulmateSelectionFixtures.candidates)
        }
        #endif
        guard let selection else { return nil }
        let candidates = potentialMatches(for: selection)
        guard !candidates.isEmpty else { return nil }
        return (selection.meetingId, candidates)
    }

    private var selection: SoulmatePendingSelection? {
        if let meetingId {
            return appState.soulmatePendingSelections.first { $0.meetingId == meetingId }
        }
        return appState.soulmatePendingSelections.first
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Did you connect with someone?")
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)

                Text("Choose only people you genuinely want to reconnect with. Your choice stays private unless they choose you too.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)

                if let selectionContext {
                    LazyVStack(spacing: 10) {
                        ForEach(selectionContext.candidates, id: \.userId) { potentialMatch in
                            Button {
                                let userId = potentialMatch.userId
                                if selectedUserIds.contains(userId) {
                                    selectedUserIds.remove(userId)
                                } else {
                                    selectedUserIds.insert(userId)
                                }
                                feedbackTrigger += 1
                            } label: {
                                HStack {
                                    Text(potentialMatch.name)
                                        .font(PrototypeTypography.bodyStrong)
                                        .foregroundStyle(PrototypePalette.ink)
                                    Spacer()
                                    Image(systemName: selectedUserIds.contains(potentialMatch.userId) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(
                                            selectedUserIds.contains(potentialMatch.userId)
                                                ? PrototypePalette.accent
                                                : PrototypePalette.muted
                                        )
                                }
                                .padding(14)
                                .background(PrototypePalette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("match-toggle")
                            .accessibilityLabel("Potential match row")
                            .accessibilityValue(selectedUserIds.contains(potentialMatch.userId) ? "Selected" : "Not selected")
                            .sensoryFeedback(.success, trigger: feedbackTrigger)
                        }
                    }

                    Button {
                        Task {
                            #if DEBUG
                            // Visual-only fixture meeting has no API meeting row — skip network.
                            if SoulmateSelectionFixtures.isActive,
                               selectionContext.meetingId == SoulmateSelectionFixtures.meetingId {
                                feedbackTrigger += 1
                                dismiss()
                                return
                            }
                            #endif
                            await appState.submitSoulmateSelection(
                                meetingId: selectionContext.meetingId,
                                selectedUserIds: Array(selectedUserIds)
                            )
                            feedbackTrigger += 1
                            dismiss()
                        }
                    } label: {
                        PrimaryActionButton(
                            title: selectedUserIds.isEmpty
                                ? "Choose someone"
                                : "Confirm \(selectedUserIds.count) choice\(selectedUserIds.count == 1 ? "" : "s")",
                            systemImage: "checkmark"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedUserIds.isEmpty)
                    .accessibilityIdentifier("submit")
                    .accessibilityLabel(selectedUserIds.isEmpty ? "Choose someone" : "Confirm choices")
                    .sensoryFeedback(.success, trigger: feedbackTrigger)
                } else {
                    Text("No meetup selection is waiting.")
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.subink)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(PrototypePalette.background)
            .navigationTitle("Soulmate")
            #if DEBUG
            .task {
                await seedValidationSelectionIfNeeded()
            }
            .onChange(of: appState.soulmatePendingSelections.map(\.meetingId)) { _, _ in
                Task { await seedValidationSelectionIfNeeded() }
            }
            #endif
        }
    }

    #if DEBUG
    private func seedValidationSelectionIfNeeded() async {
        guard SoulmateSelectionFixtures.isActive, !didSeedValidationSelection else { return }
        for _ in 0..<20 {
            if let selection = appState.soulmatePendingSelections.first {
                let live = potentialMatches(for: selection)
                if !live.isEmpty {
                    selectedUserIds = []
                    didSeedValidationSelection = true
                    return
                }
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        selectedUserIds = []
        didSeedValidationSelection = true
    }
    #endif

    private func potentialMatches(for selection: SoulmatePendingSelection) -> [SoulmatePotentialMatch] {
        let raw: [SoulmatePotentialMatch]
        if let details = selection.potentialMatchDetails, !details.isEmpty {
            raw = details
        } else {
            raw = selection.potentialMatches.map { SoulmatePotentialMatch(userId: $0, name: "Member \(String($0.suffix(6)))") }
        }
        return discoverAlignedCandidates(from: raw)
    }

    /// Align post-meet roster with macOS `soulmateDiscover` (Arjun, Meera, Rohan).
    private func discoverAlignedCandidates(from raw: [SoulmatePotentialMatch]) -> [SoulmatePotentialMatch] {
        let discoverOrder = ["Arjun", "Meera", "Rohan"]
        var aligned: [SoulmatePotentialMatch] = []
        for label in discoverOrder {
            if let match = raw.first(where: { selectionDisplayName(for: $0).hasPrefix(label) }) {
                aligned.append(SoulmatePotentialMatch(userId: match.userId, name: selectionDisplayName(for: match)))
            }
        }
        if aligned.count >= 3 { return Array(aligned.prefix(3)) }
        let extras = raw
            .filter { candidate in !aligned.contains(where: { $0.userId == candidate.userId }) }
            .map { SoulmatePotentialMatch(userId: $0.userId, name: selectionDisplayName(for: $0)) }
        return Array((aligned + extras).prefix(3))
    }

    private func selectionDisplayName(for detail: SoulmatePotentialMatch) -> String {
        let raw = detail.name.lowercased()
        if raw.contains("arjun") { return "Arjun N." }
        if raw.contains("meera") { return "Meera I." }
        if raw.contains("rohan") { return "Rohan M." }
        let parts = detail.name.split(separator: " ")
        guard let first = parts.first else { return detail.name }
        if parts.count > 1, let initial = parts.dropFirst().first?.first {
            return "\(first) \(String(initial).uppercased())."
        }
        return String(first)
    }
}

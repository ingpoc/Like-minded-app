import SwiftUI

struct SoulmatePrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var showingSelection = false

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Soulmate", subtitle: "Who you connected with.") {
                SoulmateHeroCard()

                FeatureCard(title: "How matches work", eyebrow: "Discover") {
                    Text("Matches appear only after mutual selection from a meetup. Distance and interest filters are not part of this MVP.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Source: Mutual meetup selection", systemImage: "person.2.circle")
                    Label("Visible when: \(appState.soulmateEnabled ? "Soulmate enabled" : "Soulmate off")", systemImage: "heart")
                    Label("Matches: \(appState.soulmateMatches.count)", systemImage: "bubble.left.and.bubble.right")
                        .contentTransition(.numericText())
                }

                if appState.soulmateEnabled {
                    FeatureCard(title: "Soulmate is on", eyebrow: "Private") {
                        Label("On — change this in Settings", systemImage: "checkmark.circle.fill")
                            .font(PrototypeTypography.bodyStrong)
                            .foregroundStyle(PrototypePalette.accent)
                            .accessibilityLabel("Soulmate is on. Change this in Settings.")

                        Text("Matches need mutual post-meet selection. Turn Soulmate off in Settings to hide this tab.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                    }
                } else {
                    FeatureCard(title: "Enable Soulmate", eyebrow: "Private") {
                        Toggle("Enable Soulmate", isOn: Binding(
                            get: { appState.soulmateEnabled },
                            set: { enabled in Task { await appState.setSoulmateEnabled(enabled) } }
                        ))
                        .font(PrototypeTypography.bodyStrong)
                        .tint(PrototypePalette.accent)

                        Text("Shows only when enabled. Matches need mutual post-meet selection.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                    }
                }

                if let error = appState.soulmateError {
                    Text(error)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.amber)
                }

                if !appState.soulmatePendingSelections.isEmpty {
                    Button { showingSelection = true } label: {
                        PrimaryActionButton(title: "Post-meet selection", systemImage: "heart.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Post-meet selection")
                }

                FeatureCard(title: "Matches", eyebrow: "Mutual") {
                    HStack {
                        Spacer()
                        Button {
                            Task { await appState.fetchSoulmateStatus() }
                        } label: {
                            Text("New matches")
                                .font(PrototypeTypography.metadata)
                                .foregroundStyle(PrototypePalette.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(PrototypePalette.surface)
                                .clipShape(Capsule(style: .continuous))
                                .overlay(Capsule(style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("New matches")
                    }

                    if appState.isLoadingSoulmate {
                        ProgressView("Loading matches")
                            .font(PrototypeTypography.metadata)
                    } else if appState.soulmateMatches.isEmpty {
                        Text("No matches yet. Join meetups and select connections.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.soulmateMatches) { match in
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ConversationListView(matches: appState.soulmateMatches)
                    } label: {
                        Image(systemName: "bubble.right")
                    }
                    .accessibilityLabel("Conversations")
                }
            }
            .task { await appState.fetchSoulmateStatus() }
            .sheet(isPresented: $showingSelection) {
                SoulmateSelectionDialog()
                    .environmentObject(appState)
                    .presentationDetents([.medium, .large])
            }
        }
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

            Text("Matches are mutual.")
                .font(PrototypeTypography.bodyStrong)
                .foregroundStyle(PrototypePalette.ink)

            Text("When both of you select each other, you will show up here.")
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
                Text("Met at \(match.meetingId)")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
                    .lineLimit(1)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(14)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

struct SoulmateMatchDetailView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    let match: SoulmateMatch
    @State private var detail: SoulmateMatchDetail?
    @State private var error: String?

    var body: some View {
        ScreenContainer(title: match.name, subtitle: "Match detail.") {
            if let detail {
                FeatureCard(title: "About", eyebrow: detail.basicInfo.gender ?? "Match") {
                    Text("\(detail.basicInfo.gender?.capitalized ?? "Member"). Interests are shared only after a mutual match.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }

                FeatureCard(title: "You both like", eyebrow: "Interests") {
                    if detail.interests.isEmpty {
                        Text("No interests shared yet.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                    } else {
                        FlexibleTagLayout(items: detail.interests.map { "\($0.label) · \($0.depth.rawValue)" })
                    }
                }

                FeatureCard(title: "Match status", eyebrow: "Mutual") {
                    Text("Matched from a meetup. Chat opens once both people selected each other.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                    if let date = match.meetingDate {
                        Label("Met \(LikemindedDate.short(date))", systemImage: "calendar")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.ink)
                    }
                }

                NavigationLink {
                    ChatView(match: match)
                } label: {
                    PrimaryActionButton(title: "Start chat", systemImage: "message.fill")
                }
                .buttonStyle(.plain)
            } else if let error {
                Text(error)
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.amber)
            } else {
                ProgressView("Loading match")
                    .font(PrototypeTypography.metadata)
            }
        }
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
            do {
                detail = try await appState.fetchSoulmateMatchDetail(id: match.matchId)
            } catch {
                self.error = "Match detail could not be loaded."
            }
        }
    }
}

struct ConversationListView: View {
    let matches: [SoulmateMatch]

    var body: some View {
        ScreenContainer(title: "Chats", subtitle: "Recent conversations.") {
            if matches.isEmpty {
                Text("No conversations yet.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(matches) { match in
                        NavigationLink {
                            ChatView(match: match)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(match.name)
                                        .font(PrototypeTypography.bodyStrong)
                                        .foregroundStyle(PrototypePalette.ink)
                                    Text("Start chat")
                                        .font(PrototypeTypography.metadata)
                                        .foregroundStyle(PrototypePalette.subink)
                                }
                                Spacer()
                                Text(LikemindedDate.short(match.createdAt))
                                    .font(PrototypeTypography.metadata)
                                    .foregroundStyle(PrototypePalette.subink)
                            }
                            .padding(14)
                            .background(PrototypePalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, isOutgoing: message.senderId == appState.authSession?.userId)
                    }
                }
                .padding(20)
            }
            .background(PrototypePalette.background)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(PrototypeTypography.body)
                    .padding(12)
                    .background(PrototypePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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
        .navigationTitle(match.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    callSheetMode = "voice"
                    showCallSheet = true
                } label: {
                    Image(systemName: "phone")
                }
                .accessibilityLabel("Voice call")

                Button {
                    callSheetMode = "video"
                    showCallSheet = true
                } label: {
                    Image(systemName: "video")
                }
                .accessibilityLabel("Video call")

                Button {
                    showConversationInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Conversation info")
            }
        }
        .sheet(isPresented: $showCallSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text(callSheetMode == "voice" ? "Voice call" : "Video call")
                        .font(PrototypeTypography.sectionTitle)
                    Text("Scheduling a \(callSheetMode) call with \(match.name) is not wired in this MVP. Message them to coordinate a meetup room instead.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                    Button("Done") { showCallSheet = false }
                        .buttonStyle(.borderedProminent)
                        .tint(PrototypePalette.accent)
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
                    Text(match.name)
                        .font(PrototypeTypography.sectionTitle)
                    Text("Mutual match from \(match.meetingId). Messages sync through the backend chat thread.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                    Button("Done") { showConversationInfo = false }
                        .buttonStyle(.borderedProminent)
                        .tint(PrototypePalette.accent)
                }
                .padding(20)
                .navigationTitle("Conversation info")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .task { await loadMessages() }
        .task {
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

    private func loadMessages() async {
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
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(pulse ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.2).repeatForever(autoreverses: true), value: pulse)
            }
        }
        .foregroundStyle(PrototypePalette.subink)
        .padding(10)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { pulse = true }
    }
}

struct SoulmateSelectionDialog: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserIds: Set<String> = []
    @State private var feedbackTrigger = 0
    var meetingId: String?

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

                if let selection {
                    LazyVStack(spacing: 10) {
                        ForEach(potentialMatches(for: selection), id: \.userId) { potentialMatch in
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
                                    if selectedUserIds.contains(potentialMatch.userId) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(PrototypePalette.accent)
                                    }
                                }
                                .padding(14)
                                .background(PrototypePalette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Potential match row")
                            .accessibilityValue(selectedUserIds.contains(potentialMatch.userId) ? "Selected" : "Not selected")
                            .sensoryFeedback(.success, trigger: feedbackTrigger)
                        }
                    }

                    Button {
                        Task {
                            await appState.submitSoulmateSelection(meetingId: selection.meetingId, selectedUserIds: Array(selectedUserIds))
                            feedbackTrigger += 1
                            dismiss()
                        }
                    } label: {
                        PrimaryActionButton(title: "Submit", systemImage: "checkmark")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedUserIds.isEmpty)
                    .accessibilityLabel("Submit")
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
        }
    }

    private func potentialMatches(for selection: SoulmatePendingSelection) -> [SoulmatePotentialMatch] {
        if let details = selection.potentialMatchDetails, !details.isEmpty {
            return details
        }
        return selection.potentialMatches.map { SoulmatePotentialMatch(userId: $0, name: "Member \(String($0.suffix(6)))") }
    }
}

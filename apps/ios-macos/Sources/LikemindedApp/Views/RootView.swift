import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = RootView.initialSelection()
    @State private var showingValidationPrivacyPolicy = false

    var body: some View {
        Group {
            if appState.isSignedIn {
                if Self.showsValidationNotifications {
                    NotificationsView()
                        .environmentObject(appState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PrototypePalette.background.ignoresSafeArea())
                        .task {
                            await appState.fetchNotifications()
                        }
                } else if Self.showsValidationConversations {
                    NavigationStack {
                        ConversationListView(matches: appState.soulmateMatches)
                            .environmentObject(appState)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PrototypePalette.background.ignoresSafeArea())
                    .task { await appState.fetchSoulmateStatus() }
                } else if Self.showsValidationChat {
                    NavigationStack {
                        ChatView(match: Self.validationChatMatch)
                            .environmentObject(appState)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PrototypePalette.background.ignoresSafeArea())
                } else if Self.showsValidationPastMeetDetail {
                    NavigationStack {
                        Group {
                            if let meeting = appState.pastMeetings.first {
                                PastMeetDetailView(meeting: meeting)
                            } else {
                                ProgressView("Loading recap")
                                    .font(PrototypeTypography.metadata)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .environmentObject(appState)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PrototypePalette.background.ignoresSafeArea())
                    .task {
                        await appState.fetchMeetings()
                        await appState.fetchSoulmateStatus()
                    }
                } else if Self.showsValidationSoulmateSelection {
                    SoulmateSelectionDialog()
                        .environmentObject(appState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PrototypePalette.background.ignoresSafeArea())
                } else if Self.showsValidationCreateEvent {
                    NavigationStack {
                        CreateEventView(community: Self.validationCreateEventCommunity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PrototypePalette.background.ignoresSafeArea())
                } else if (Self.showsValidationCommunityMembers || appState.validationDirectCommunityMembers)
                    && !Self.showsValidationPastMeetDetail {
                    NavigationStack {
                        CommunityMembersView(community: Self.validationCommunityMembersCommunity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PrototypePalette.background.ignoresSafeArea())
                } else {
                ZStack(alignment: .bottom) {
                    tabContent(for: selection)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    CustomTabBar(
                        tabs: AppTab.visible(soulmateEnabled: appState.soulmateEnabled),
                        selection: $selection
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .animation(.interactive, value: appState.soulmateEnabled)
                }
                .background(PrototypePalette.background.ignoresSafeArea())
                .onChange(of: appState.soulmateEnabled) { _, enabled in
                    withAnimation(.interactive) {
                        if !enabled && selection == .soulmate && !RootView.shouldKeepSoulmateTabForValidation() {
                            selection = .meet
                        }
                    }
                }
                .task {
                    await appState.loadCurrentPlacement()
                    await appState.fetchSoulmateStatus()
                    await appState.fetchNotifications()
                }
                .onChange(of: appState.concernFlag) { oldValue, needsReinterview in
                    #if DEBUG
                    let args = ProcessInfo.processInfo.arguments
                    if args.contains("--likeminded-start-notifications")
                        || args.contains("--likeminded-start-soulmate-selection")
                        || args.contains("--likeminded-start-past-meet-detail") {
                        return
                    }
                    // Harness launches with dev-auth-bypass; stale concernFlag in validation-db
                    // must not hijack Meet tab before app-shell title-action flows.
                    if args.contains("--likeminded-dev-auth-bypass")
                        && !args.contains("--likeminded-dev-profile-concern") {
                        return
                    }
                    #endif
                    guard needsReinterview, !oldValue else { return }
                    withAnimation(.interactive) {
                        selection = .profile
                    }
                }
                .onChange(of: appState.requestedTab) { _, tab in
                    guard let tab else { return }
                    withAnimation(.interactive) {
                        selection = tab
                    }
                    appState.requestedTab = nil
                }
                .onChange(of: appState.isSignedIn) { _, signedIn in
                    guard signedIn else { return }
                    let routed = Self.initialSelection()
                    if routed != .meet || Self.hasDevLaunchRoute {
                        selection = routed
                    }
                }
                }
            } else {
                AuthGateView()
            }
        }
        .task(id: appState.isSignedIn) {
            await appState.signInForLocalValidationIfNeeded()
            await appState.validateStoredAppleCredentialIfNeeded()
            #if DEBUG
            if appState.isSignedIn && ProcessInfo.processInfo.arguments.contains("--likeminded-open-privacy-policy") {
                try? await Task.sleep(nanoseconds: 600_000_000)
                showingValidationPrivacyPolicy = true
            }
            #endif
        }
        .onChange(of: appState.isSignedIn) { _, signedIn in
            #if DEBUG
            if signedIn && ProcessInfo.processInfo.arguments.contains("--likeminded-open-privacy-policy") {
                showingValidationPrivacyPolicy = true
            }
            #endif
        }
        .sheet(isPresented: $showingValidationPrivacyPolicy) {
            PrivacyPolicySheet()
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .meet:
            MeetView()
        case .circles:
            CirclesPrototypeView()
        case .communities:
            CommunitiesPrototypeView()
        case .profile:
            VoiceProfileView()
        case .soulmate:
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--likeminded-start-conversations") {
                ConversationListValidationScreen()
            } else {
                SoulmatePrototypeView()
            }
            #else
            SoulmatePrototypeView()
            #endif
        }
    }

    private static var hasDevLaunchRoute: Bool {
        #if DEBUG
        !ProcessInfo.processInfo.arguments.filter { $0.hasPrefix("--likeminded-start-") }.isEmpty
        #else
        false
        #endif
    }

    private static var showsValidationNotifications: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-notifications")
        #else
        false
        #endif
    }

    private static var showsValidationConversations: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-conversations")
        #else
        false
        #endif
    }

    private static var showsValidationChat: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-chat")
            || ProcessInfo.processInfo.environment["LIKEMINDED_VALIDATION_SCREEN"] == "chat"
            || UserDefaults.standard.string(forKey: "LIKEMINDED_VALIDATION_SCREEN") == "chat"
        #else
        false
        #endif
    }

    private static var validationChatMatch: SoulmateMatch {
        #if DEBUG
        IOSChatFixtures.preferredMatch
        #else
        SoulmateMatch(matchId: "fixture", userId: "fixture", name: "Chat", meetingId: "fixture", createdAt: "")
        #endif
    }

    private static var showsValidationPastMeetDetail: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-past-meet-detail")
            || ProcessInfo.processInfo.environment["LIKEMINDED_VALIDATION_SCREEN"] == "past-meet-detail"
            || UserDefaults.standard.string(forKey: "LIKEMINDED_VALIDATION_SCREEN") == "past-meet-detail"
        #else
        false
        #endif
    }

    private static var showsValidationSoulmateSelection: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-soulmate-selection")
        #else
        false
        #endif
    }

    private static var showsValidationCreateEvent: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-create-event")
        #else
        false
        #endif
    }

    private static var showsValidationCommunityMembers: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--likeminded-start-community-members")
        #else
        false
        #endif
    }

    private static var validationCreateEventCommunity: Community {
        Community(
            id: "jazz-music",
            name: "Jazz & Music Community",
            summary: "People who live and breathe music. Listen, share, explore.",
            themes: ["Jazz", "Music", "Listening", "Creativity"],
            meetingFormat: "community",
            membersCount: 18
        )
    }

    private static var validationCommunityMembersCommunity: Community {
        Community(
            id: "jazz-music",
            name: "Jazz Music",
            summary: "Listeners and players exploring jazz records, history, and taste.",
            themes: ["Jazz", "Music", "Listening"],
            meetingFormat: "Saturday listening session",
            membersCount: 12
        )
    }

    private static func initialSelection() -> AppTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--likeminded-start-circles") || args.contains("--likeminded-start-circle-detail") { return .circles }
        if args.contains("--likeminded-start-communities") { return .communities }
        if args.contains("--likeminded-start-community-detail") { return .communities }
        if args.contains("--likeminded-start-create-community") { return .communities }
        if args.contains("--likeminded-start-community-members") { return .communities }
        if args.contains("--likeminded-start-create-event") { return .communities }
        if args.contains("--likeminded-start-soulmate") || args.contains("--likeminded-start-soulmate-selection") || args.contains("--likeminded-start-chat") || args.contains("--likeminded-start-conversations") || args.contains("--likeminded-start-soulmate-match-detail") { return .soulmate }
        if args.contains("--likeminded-start-profile") { return .profile }
        if args.contains("--likeminded-start-voice-session") { return .profile }
        if args.contains("--likeminded-start-settings-info") { return .profile }
        if args.contains("--likeminded-start-settings") { return .profile }
        if args.contains("--likeminded-start-settings-support") { return .profile }
        if args.contains("--likeminded-start-past-meet-detail") { return .meet }
        #endif
        return .meet
    }

    private static func shouldKeepSoulmateTabForValidation() -> Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--likeminded-start-soulmate")
            || args.contains("--likeminded-start-chat")
            || args.contains("--likeminded-start-conversations")
            || args.contains("--likeminded-start-soulmate-match-detail")
            || args.contains("--likeminded-start-soulmate-selection")
        #else
        return false
        #endif
    }
}

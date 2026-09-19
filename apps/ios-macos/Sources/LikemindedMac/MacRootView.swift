import AppKit
import SwiftUI

struct MacRootView: View {
    @EnvironmentObject private var appState: MacAppState
    @State private var selectedScreen: MacPrototypeScreen = Self.bootstrappedScreen()

    private static func bootstrappedScreen() -> MacPrototypeScreen {
        #if DEBUG
        if let deepLink = resolvedMacScreenDeepLink() {
            return deepLink
        }
        #endif
        return .initial
    }
    @State private var returnScreen: MacPrototypeScreen?

    private var macScreenDeepLink: MacPrototypeScreen? {
        Self.resolvedMacScreenDeepLink()
    }

    private var displayedScreen: MacPrototypeScreen {
        return selectedScreen
    }

    private var backDestination: MacPrototypeScreen? {
        returnScreen ?? displayedScreen.fallbackParent
    }

    private var shouldShowSoulmateTab: Bool {
        appState.soulmateEnabled || displayedScreen.tab == .soulmate
    }

    private static func resolvedMacScreenDeepLink() -> MacPrototypeScreen? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--mac-screen"),
           let index = args.firstIndex(of: "--mac-screen"),
           args.indices.contains(index + 1),
           let screen = MacPrototypeScreen(rawValue: args[index + 1]),
           screen != .welcome {
            return screen
        }
        #endif
        return nil
    }

    private func navigateToScreen(_ destination: MacPrototypeScreen) {
        guard destination != selectedScreen else { return }
        returnScreen = selectedScreen
        selectedScreen = destination
    }

    @ViewBuilder
    private var screenContent: some View {
        MacScreenView(screen: displayedScreen, appState: appState, navigate: navigateToScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var isCirclesPlacementScreen: Bool {
        displayedScreen == .circlesRoom
    }

    var body: some View {
        ZStack {
            MacPalette.background.ignoresSafeArea()
            if displayedScreen != .welcome, !isCirclesPlacementScreen {
                RadialGradient(colors: [MacPalette.accentSoft.opacity(0.45), .clear], center: .topTrailing, startRadius: 30, endRadius: 520)
                    .ignoresSafeArea()
            }

            Group {
                if displayedScreen == .welcome || isCirclesPlacementScreen {
                    screenContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    VStack(spacing: 0) {
                        GeometryReader { proxy in
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 18) {
                                    screenContent
                                }
                                .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - 72), alignment: .top)
                                .padding(.horizontal, 28)
                                .padding(.top, 18)
                                .padding(.bottom, 18)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) {
                if appState.isSignedIn,
                   displayedScreen != .welcome,
                   displayedScreen != .notifications {
                    MacTopNavigation(selectedTab: activeTab, soulmateEnabled: shouldShowSoulmateTab) { tab in
                        returnScreen = nil
                        selectedScreen = tab.primaryScreen
                    }
                    .padding(.horizontal, 88)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .overlay(alignment: .topLeading) {
                if appState.isSignedIn,
                   displayedScreen != .welcome,
                   backDestination != nil {
                    MacBackButton {
                        navigateBack()
                    }
                    .padding(.top, 18)
                    .padding(.leading, 28)
                }
            }
            .overlay(alignment: .topTrailing) {
                if titleActionAvailable {
                    Button {
                        performTitleAction()
                    } label: {
                        // Single circular control — labeled pills stacked with AX text look like
                        // duplicate "Notifications" chrome. Keep CUA via accessibilityLabel.
                        Image(systemName: titleActionIcon)
                            .font(MacType.button)
                            .foregroundStyle(MacPalette.ink)
                            .frame(width: 30, height: 30)
                            .background(MacPalette.surface, in: Circle())
                            .overlay(Circle().stroke(MacPalette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(titleActionAccessibilityLabel)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier(
                        selectedScreen == .meetOverview || selectedScreen == .meetRecap
                            ? "meet-bell"
                            : "title-action"
                    )
                    .padding(.top, 18)
                    .padding(.trailing, 28)
                }
            }
        }
        .containerBackground(MacPalette.background, for: .window)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .foregroundStyle(MacPalette.ink)
        .macSuppressFocusRing()
        .frame(
            minWidth: MacWindowMetrics.minWidth,
            minHeight: MacWindowMetrics.minHeight
        )
        .task {
            if macScreenDeepLink == nil, ProcessInfo.processInfo.arguments.contains("--likeminded-validation-welcome") {
                selectedScreen = .welcome
            }
            await appState.signInForLocalValidationIfNeeded()
            await appState.validateStoredAppleCredentialIfNeeded()
            if macScreenDeepLink == nil, ProcessInfo.processInfo.arguments.contains("--likeminded-validation-welcome") {
                selectedScreen = .welcome
            }
            if appState.isSignedIn {
                await appState.fetchMeetings()
                await appState.fetchCircles()
                await appState.fetchCommunities()
                await appState.fetchSoulmateStatus()
                await appState.fetchNotifications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectMeet)) { _ in
            selectedScreen = .meetOverview
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectCircles)) { _ in
            selectedScreen = .circlesRoom
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectCommunities)) { _ in
            selectedScreen = .communitiesBrowse
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectProfile)) { _ in
            selectedScreen = .myProfile
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectSoulmate)) { _ in
            selectedScreen = .soulmateDiscover
        }
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onChange(of: appState.isSignedIn) { _, isSignedIn in
            if !isSignedIn {
                selectedScreen = .welcome
                returnScreen = nil
                return
            }
            if selectedScreen == .welcome {
                if ProcessInfo.processInfo.arguments.contains("--likeminded-validation-welcome") {
                    return
                }
                selectedScreen = .meetOverview
            }
        }
    }

    private var activeTab: MacTab {
        // Contextual screens inherit their owning destination for stable dock selection.
        displayedScreen.tab
    }

    private var titleActionIcon: String {
        switch selectedScreen {
        case .settingsSoulmate, .messages, .notifications:
            return "xmark"
        case .myProfile:
            return "gearshape"
        case .meetOverview, .meetRecap:
            return "bell"
        default:
            return "bubble.left.and.bubble.right"
        }
    }

    private var titleActionAccessibilityLabel: String {
        switch selectedScreen {
        case .settingsSoulmate, .messages, .notifications:
            return "Close"
        case .myProfile:
            return "Settings"
        case .meetOverview, .meetRecap:
            return "Notifications"
        default:
            return "Messages"
        }
    }

    private var titleActionAvailable: Bool {
        // Meet bell must appear even while dev-auth is still resolving — concept
        // header already shows "When you meet." before isSignedIn flips true.
        if selectedScreen == .meetOverview || selectedScreen == .meetRecap {
            return true
        }
        guard appState.isSignedIn else { return false }
        switch selectedScreen {
        case .soulmateOverview, .soulmateDiscover:
            return false
        case .myProfile, .settingsSoulmate, .messages, .notifications:
            return true
        default:
            return !appState.soulmateMatches.isEmpty
        }
    }

    private func performTitleAction() {
        switch selectedScreen {
        case .settingsSoulmate, .messages, .notifications:
            navigateBack()
        case .myProfile:
            returnScreen = selectedScreen
            selectedScreen = .settingsSoulmate
        case .meetOverview, .meetRecap:
            returnScreen = selectedScreen
            selectedScreen = .notifications
        default:
            returnScreen = selectedScreen
            selectedScreen = .messages
        }
    }

    private func navigateBack() {
        guard let destination = backDestination else { return }
        selectedScreen = destination
        returnScreen = nil
    }

}

struct MacTopNavigation: View {
    let selectedTab: MacTab
    let soulmateEnabled: Bool
    let select: (MacTab) -> Void

    var body: some View {
        let tabs = MacTab.visible(soulmateEnabled: soulmateEnabled)
        let tabWidth: CGFloat = 144
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button {
                    select(tab)
                } label: {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .font(MacType.small.weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? MacPalette.accent : MacPalette.muted)
                        .frame(width: tabWidth)
                        .padding(.vertical, 12)
                        .background(selectedTab == tab ? MacPalette.accentSoft.opacity(0.62) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityLabel(tab.rawValue)
                .accessibilityValue(selectedTab == tab ? "Selected" : "Not selected")
                .accessibilityAddTraits(selectedTab == tab ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(8)
        .background(MacPalette.surface, in: Capsule())
        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }
}

#Preview {
    MacRootView()
        .environmentObject(MacAppState())
        .frame(width: MacWindowMetrics.defaultWidth, height: MacWindowMetrics.defaultHeight)
}

import AppKit
import SwiftUI

struct MacRootView: View {
    @StateObject private var appState = MacAppState()
    @State private var selectedScreen: MacPrototypeScreen = .initial
    @State private var returnScreen: MacPrototypeScreen?

    var body: some View {
        ZStack {
            MacPalette.background.ignoresSafeArea()
            RadialGradient(colors: [MacPalette.accentSoft.opacity(0.45), .clear], center: .topTrailing, startRadius: 30, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 18) {
                            MacScreenView(screen: selectedScreen, appState: appState) { destination in
                                if destination == .messages {
                                    returnScreen = selectedScreen
                                }
                                selectedScreen = destination
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - (appState.isSignedIn && selectedScreen != .welcome ? bottomContentInset : 72)), alignment: .top)
                        .padding(.horizontal, 28)
                        .padding(.top, 54)
                        .padding(.bottom, bottomContentInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                if appState.isSignedIn, selectedScreen != .welcome, selectedScreen != .meetVideoCall {
                    MacBottomNav(selectedTab: activeTab, soulmateEnabled: appState.soulmateEnabled) { tab in
                        returnScreen = nil
                        selectedScreen = tab.primaryScreen
                    }
                    .padding(.bottom, 18)
                }
            }
            .overlay(alignment: .topTrailing) {
                if titleActionAvailable {
                    Button {
                        performTitleAction()
                    } label: {
                        Image(systemName: titleActionIcon)
                            .font(MacType.button)
                            .foregroundStyle(MacPalette.ink)
                            .frame(width: 30, height: 30)
                            .background(MacPalette.surface, in: Circle())
                            .overlay(Circle().stroke(MacPalette.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .accessibilityLabel(titleActionAccessibilityLabel)
                    .padding(.top, 18)
                    .padding(.trailing, 28)
                }
            }
        }
        .foregroundStyle(MacPalette.ink)
        .task {
            await appState.signInForLocalValidationIfNeeded()
            await appState.validateStoredAppleCredentialIfNeeded()
            if ProcessInfo.processInfo.arguments.contains("--likeminded-validation-welcome") {
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
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectMeet)) { _ in selectedScreen = .meetOverview }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectCircles)) { _ in selectedScreen = .circlesRoom }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectCommunities)) { _ in selectedScreen = .communitiesBrowse }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectProfile)) { _ in selectedScreen = .myProfile }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectSoulmate)) { _ in selectedScreen = .soulmateDiscover }
        .onAppear {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onChange(of: appState.isSignedIn) { _, isSignedIn in
            if isSignedIn, selectedScreen == .welcome {
                if ProcessInfo.processInfo.arguments.contains("--likeminded-validation-welcome") {
                    return
                }
                selectedScreen = .meetOverview
            }
        }
        .onChange(of: appState.soulmateEnabled) { _, enabled in
            if !enabled, selectedScreen.tab == .soulmate {
                selectedScreen = .myProfile
            }
        }
    }

    private var activeTab: MacTab {
        if selectedScreen == .messages, let returnScreen {
            return returnScreen.tab
        }
        return selectedScreen.tab
    }

    private var bottomContentInset: CGFloat {
        guard appState.isSignedIn, selectedScreen != .welcome else { return 18 }
        return selectedScreen == .meetVideoCall ? 28 : 116
    }

    private var titleActionIcon: String {
        if selectedScreen == .settingsSoulmate || selectedScreen == .messages {
            return "xmark"
        }
        return selectedScreen == .myProfile ? "gearshape" : "bubble.left.and.bubble.right"
    }

    private var titleActionAccessibilityLabel: String {
        if selectedScreen == .settingsSoulmate || selectedScreen == .messages {
            return "Close"
        }
        return selectedScreen == .myProfile ? "Settings" : "Messages"
    }

    private var titleActionAvailable: Bool {
        guard appState.isSignedIn else { return false }
        if selectedScreen == .myProfile || selectedScreen == .settingsSoulmate || selectedScreen == .messages {
            return true
        }
        return !appState.soulmateMatches.isEmpty
    }

    private func performTitleAction() {
        switch selectedScreen {
        case .settingsSoulmate:
            selectedScreen = .myProfile
        case .messages:
            selectedScreen = returnScreen ?? .meetOverview
            returnScreen = nil
        case .myProfile:
            selectedScreen = .settingsSoulmate
        default:
            returnScreen = selectedScreen
            selectedScreen = .messages
        }
    }

}

struct MacBottomNav: View {
    let selectedTab: MacTab
    let soulmateEnabled: Bool
    let select: (MacTab) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MacTab.visible(soulmateEnabled: soulmateEnabled)) { tab in
                Button {
                    select(tab)
                } label: {
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .font(MacType.small.weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? MacPalette.accent : MacPalette.muted)
                        .frame(width: 124)
                        .padding(.vertical, 14)
                        .background(selectedTab == tab ? MacPalette.accentSoft.opacity(0.62) : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
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
        .frame(width: 1200, height: 760)
}

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
                titleBar
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 18) {
                        MacScreenView(screen: selectedScreen, appState: appState)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 18)
                }
                MacBottomNav(selectedTab: activeTab, soulmateEnabled: appState.soulmateEnabled) { tab in
                    returnScreen = nil
                    selectedScreen = tab.primaryScreen
                }
                .padding(.bottom, 18)
            }
        }
        .foregroundStyle(MacPalette.ink)
        .task {
            await appState.signInForLocalValidationIfNeeded()
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
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectSoulmate)) { _ in selectedScreen = .soulmateOverview }
    }

    private var activeTab: MacTab {
        if selectedScreen == .messages, let returnScreen {
            return returnScreen.tab
        }
        return selectedScreen.tab
    }

    private var titleActionIcon: String {
        if selectedScreen == .settingsSoulmate || selectedScreen == .messages {
            return "xmark"
        }
        return selectedScreen == .myProfile ? "gearshape" : "bubble.left.and.bubble.right"
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

    private var titleBar: some View {
        HStack {
            HStack(spacing: 9) {
                Circle().fill(Color.red).frame(width: 12, height: 12)
                Circle().fill(Color.orange).frame(width: 12, height: 12)
                Circle().fill(Color.green).frame(width: 12, height: 12)
            }
            Spacer()
            Text("Likeminded")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                performTitleAction()
            } label: {
                Image(systemName: titleActionIcon)
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                    .frame(width: 30, height: 30)
                    .background(MacPalette.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
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
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }
}

#Preview {
    MacRootView()
        .frame(width: 1200, height: 760)
}

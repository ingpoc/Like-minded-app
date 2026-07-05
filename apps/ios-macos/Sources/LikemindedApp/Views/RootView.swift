import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = RootView.initialSelection()

    var body: some View {
        Group {
            if appState.isSignedIn {
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
                        if !enabled && selection == .soulmate {
                            selection = .meet
                        }
                    }
                }
                .task {
                    await appState.loadCurrentPlacement()
                    await appState.fetchSoulmateStatus()
                    await appState.fetchNotifications()
                }
                .onChange(of: appState.concernFlag) { _, needsReinterview in
                    if needsReinterview {
                        withAnimation(.interactive) {
                            selection = .profile
                        }
                    }
                }
                .onChange(of: appState.requestedTab) { _, tab in
                    guard let tab else { return }
                    withAnimation(.interactive) {
                        selection = tab
                    }
                    appState.requestedTab = nil
                }
            } else {
                AuthGateView()
            }
        }
        .task {
            await appState.signInForLocalValidationIfNeeded()
            await appState.validateStoredAppleCredentialIfNeeded()
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
            SoulmatePrototypeView()
        }
    }

    private static func initialSelection() -> AppTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--likeminded-start-circles") { return .circles }
        if args.contains("--likeminded-start-communities") { return .communities }
        if args.contains("--likeminded-start-soulmate") { return .soulmate }
        if args.contains("--likeminded-start-profile") { return .profile }
        #endif
        return .meet
    }
}

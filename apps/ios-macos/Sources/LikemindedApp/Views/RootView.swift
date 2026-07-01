import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = .meet

    var body: some View {
        Group {
            if appState.isSignedIn {
                TabView(selection: $selection) {
                    ForEach(AppTab.visible(soulmateEnabled: appState.soulmateEnabled)) { tab in
                        tabContent(for: tab)
                            .tabItem {
                                Label(tab.rawValue, systemImage: tab.systemImage)
                            }
                            .tag(tab)
                    }
                }
                .tint(PrototypePalette.accent)
                .task {
                    await appState.loadCurrentPlacement()
                    await appState.fetchSoulmateStatus()
                }
                .onChange(of: appState.concernFlag) { _, needsReinterview in
                    if needsReinterview {
                        selection = .profile
                    }
                }
                .onChange(of: appState.soulmateEnabled) { _, enabled in
                    if !enabled && selection == .soulmate {
                        selection = .meet
                    }
                }
            } else {
                AuthGateView()
            }
        }
        .task {
            await appState.signInForLocalValidationIfNeeded()
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
}

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = .meet

    var body: some View {
        Group {
            if appState.isSignedIn {
                TabView(selection: $selection) {
                    ForEach(AppTab.allCases) { tab in
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
                }
                .onChange(of: appState.concernFlag) { _, needsReinterview in
                    if needsReinterview {
                        selection = .profile
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

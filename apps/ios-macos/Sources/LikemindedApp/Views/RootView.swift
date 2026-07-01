import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = .meet

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
                }
                .onChange(of: appState.concernFlag) { _, needsReinterview in
                    if needsReinterview {
                        withAnimation(.interactive) {
                            selection = .profile
                        }
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

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = .profile

    var body: some View {
        Group {
            if appState.isSignedIn {
                TabView(selection: $selection) {
                    CirclesPrototypeView()
                        .tabItem {
                            Label(AppTab.circles.rawValue, systemImage: AppTab.circles.systemImage)
                        }
                        .tag(AppTab.circles)

                    CommunitiesPrototypeView()
                        .tabItem {
                            Label(AppTab.communities.rawValue, systemImage: AppTab.communities.systemImage)
                        }
                        .tag(AppTab.communities)

                    Group {
                        if appState.slice == nil, appState.basicInfo != nil {
                            VoiceProfileView()
                        } else {
                            ProfilePrototypeView()
                        }
                    }
                        .tabItem {
                            Label(AppTab.profile.rawValue, systemImage: AppTab.profile.systemImage)
                        }
                        .tag(AppTab.profile)
                }
                .tint(PrototypePalette.accent)
                .task {
                    await appState.loadCurrentPlacement()
                }
            } else {
                AuthGateView()
            }
        }
        .task {
            await appState.signInForLocalValidationIfNeeded()
        }
    }
}

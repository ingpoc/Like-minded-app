import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = .meet

    var body: some View {
        Group {
            if appState.isSignedIn {
                TabView(selection: $selection) {
                    MeetPrototypeView()
                        .tabItem {
                            Label(AppTab.meet.rawValue, systemImage: AppTab.meet.systemImage)
                        }
                        .tag(AppTab.meet)

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

                    VoiceProfileView()
                        .tabItem {
                            Label(AppTab.profile.rawValue, systemImage: AppTab.profile.systemImage)
                        }
                        .tag(AppTab.profile)

                    SoulmatePrototypeView()
                        .tabItem {
                            Label(AppTab.soulmate.rawValue, systemImage: AppTab.soulmate.systemImage)
                        }
                        .tag(AppTab.soulmate)
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

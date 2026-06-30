import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var selection: AppTab = .talk

    var body: some View {
        Group {
            if appState.isSignedIn {
                TabView(selection: $selection) {
                    ReflectionPrototypeView()
                        .tabItem {
                            Label(AppTab.talk.rawValue, systemImage: AppTab.talk.systemImage)
                        }
                        .tag(AppTab.talk)

                    CirclesPrototypeView()
                        .tabItem {
                            Label(AppTab.circles.rawValue, systemImage: AppTab.circles.systemImage)
                        }
                        .tag(AppTab.circles)

                    ProfilePrototypeView()
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

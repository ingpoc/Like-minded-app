import SwiftUI

struct RootView: View {
    @State private var selection: AppTab = .place

    var body: some View {
        TabView(selection: $selection) {
            TodayPrototypeView()
                .tabItem {
                    Label(AppTab.place.rawValue, systemImage: AppTab.place.systemImage)
                }
                .tag(AppTab.place)

            ReflectionPrototypeView()
                .tabItem {
                    Label(AppTab.reflect.rawValue, systemImage: AppTab.reflect.systemImage)
                }
                .tag(AppTab.reflect)

            ConnectionsPrototypeView()
                .tabItem {
                    Label(AppTab.connect.rawValue, systemImage: AppTab.connect.systemImage)
                }
                .tag(AppTab.connect)
        }
        .tint(PrototypePalette.accent)
    }
}

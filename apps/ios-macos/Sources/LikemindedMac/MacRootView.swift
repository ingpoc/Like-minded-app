import SwiftUI

struct MacRootView: View {
    @State private var selectedScreen: MacPrototypeScreen = .welcome

    var body: some View {
        ZStack {
            MacPalette.background.ignoresSafeArea()
            RadialGradient(colors: [MacPalette.accentSoft.opacity(0.45), .clear], center: .topTrailing, startRadius: 30, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 18) {
                        MacScreenView(screen: selectedScreen)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 98)
                }
            }

            VStack {
                Spacer()
                MacBottomNav(selectedTab: selectedScreen.tab) { tab in
                    selectedScreen = tab.primaryScreen
                }
                .padding(.bottom, 22)
            }
        }
        .foregroundStyle(MacPalette.ink)
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectMeet)) { _ in selectedScreen = .meetOverview }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectCircles)) { _ in selectedScreen = .circlesRoom }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectCommunities)) { _ in selectedScreen = .communitiesBrowse }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectProfile)) { _ in selectedScreen = .myProfile }
        .onReceive(NotificationCenter.default.publisher(for: .macPrototypeSelectSoulmate)) { _ in selectedScreen = .soulmateOverview }
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
            Image(systemName: "bell")
                .font(MacType.button)
                .foregroundStyle(MacPalette.ink)
                .frame(width: 30, height: 30)
                .background(MacPalette.surface, in: Circle())
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }
}

struct MacBottomNav: View {
    let selectedTab: MacTab
    let select: (MacTab) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MacTab.allCases) { tab in
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

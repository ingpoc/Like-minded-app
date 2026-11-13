import SwiftUI

extension Animation {
    static let interactive = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let celebratory = Animation.spring(response: 0.50, dampingFraction: 0.70)
    static let snappy = Animation.spring(response: 0.30, dampingFraction: 0.85)
}

struct CustomTabBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tabs: [AppTab]
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(PrototypePalette.rule, lineWidth: 1))
        .shadow(color: PrototypePalette.ink.opacity(0.10), radius: 24, y: 10)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .snappy) {
                selection = tab
            }
        } label: {
            tabLabel(tab)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityValue(selection == tab ? "Selected" : "Not selected")
        .accessibilityHint(selection == tab ? "" : "Switches to \(tab.rawValue)")
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    @ViewBuilder
    private func tabLabel(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        VStack(spacing: 4) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .symbolVariant(isSelected ? .fill : .none)

            Text(tab.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded))
                .fontWidth(tab == .communities ? .condensed : .standard)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .allowsTightening(true)
        }
        .foregroundStyle(isSelected ? PrototypePalette.accent : PrototypePalette.subink)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(isSelected ? PrototypePalette.accentSoft.opacity(0.70) : .clear, in: Capsule())
        .contentShape(Capsule())
    }
}

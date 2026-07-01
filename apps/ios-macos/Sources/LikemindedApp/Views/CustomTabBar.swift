import SwiftUI

extension Animation {
    static let interactive = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let celebratory = Animation.spring(response: 0.50, dampingFraction: 0.70)
    static let snappy = Animation.spring(response: 0.30, dampingFraction: 0.85)
}

struct CustomTabBar: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.snappy) {
                        selection = tab
                    }
                } label: {
                    tabLabel(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(PrototypePalette.rule, lineWidth: 1))
        .shadow(color: PrototypePalette.ink.opacity(0.10), radius: 24, y: 10)
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return HStack(spacing: 6) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .symbolVariant(isSelected ? .fill : .none)
                .scaleEffect(isSelected ? 1.1 : 1.0)

            if isSelected {
                Text(tab.rawValue)
                    .font(PrototypeTypography.metadata.weight(.semibold))
                    .transition(.opacity.combined(with: .move(edge: .bottom)).combined(with: .scale))
            }
        }
        .foregroundStyle(isSelected ? PrototypePalette.accent : PrototypePalette.subink)
        .frame(maxWidth: isSelected ? 116 : 48, minHeight: 44)
        .background(isSelected ? PrototypePalette.accentSoft.opacity(0.70) : .clear, in: Capsule())
        .contentShape(Capsule())
    }
}

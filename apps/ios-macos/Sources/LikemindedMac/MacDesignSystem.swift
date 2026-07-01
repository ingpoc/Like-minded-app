import SwiftUI

enum MacPalette {
    static let background = Color(red: 0.972, green: 0.954, blue: 0.928)
    static let surface = Color.white.opacity(0.72)
    static let ink = Color(red: 0.055, green: 0.057, blue: 0.048)
    static let muted = Color(red: 0.34, green: 0.35, blue: 0.31)
    static let accent = Color(red: 0.0, green: 0.29, blue: 0.20)
    static let accentSoft = Color(red: 0.80, green: 0.88, blue: 0.80)
    static let clay = Color(red: 0.66, green: 0.30, blue: 0.20)
    static let sage = Color(red: 0.47, green: 0.59, blue: 0.48)
    static let line = Color.black.opacity(0.08)
}

enum MacType {
    static let eyebrow = Font.system(size: 11, weight: .bold, design: .rounded)
    static let title = Font.system(size: 34, weight: .semibold, design: .serif)
    static let section = Font.system(size: 20, weight: .semibold, design: .serif)
    static let body = Font.system(size: 14, weight: .regular, design: .rounded)
    static let small = Font.system(size: 12, weight: .regular, design: .rounded)
    static let button = Font.system(size: 13, weight: .semibold, design: .rounded)
}

struct MacPanel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(MacType.section)
                    .foregroundStyle(MacPalette.ink)
            }
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MacPalette.line, lineWidth: 1)
        )
    }
}

struct MacPill: View {
    let text: String
    var isSelected = false

    var body: some View {
        Text(text)
            .font(MacType.small.weight(.medium))
            .foregroundStyle(isSelected ? .white : MacPalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? MacPalette.accent : MacPalette.surface, in: Capsule())
            .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
    }
}

struct MacOrb: View {
    var heart = false

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: heart ? 42 : 100, style: .continuous)
                    .stroke(MacPalette.accent.opacity(0.05 + Double(index) * 0.018), lineWidth: 1)
                    .frame(width: CGFloat(90 + index * 18), height: CGFloat(90 + index * 16))
                    .rotationEffect(.degrees(Double(index) * 17))
            }
            Circle()
                .fill(RadialGradient(colors: [Color.white, MacPalette.accentSoft, MacPalette.accent.opacity(0.18)], center: .center, startRadius: 4, endRadius: 92))
                .frame(width: 160, height: 160)
            Image(systemName: heart ? "heart.fill" : "sparkle")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: MacPalette.accent.opacity(0.45), radius: 16)
        }
    }
}

struct MacHeroArt: View {
    let tone: Color
    var label: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [tone.opacity(0.95), MacPalette.accent.opacity(0.88), Color.black.opacity(0.7)], startPoint: .topTrailing, endPoint: .bottomLeading)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: CGFloat(220 + index * 90))
                    .offset(x: CGFloat(index * 24), y: CGFloat(index * -12))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(MacType.section)
                    .foregroundStyle(.white)
                Text("Thoughtful - Calm - Curious")
                    .font(MacType.small)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MacAvatar: View {
    let initials: String
    var color = MacPalette.accentSoft

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 42, height: 42)
            .overlay(Text(initials).font(.system(size: 16, weight: .medium, design: .serif)).foregroundStyle(MacPalette.accent))
    }
}


import AppKit
import SwiftUI

extension View {
    /// Suppresses the default macOS blue focus ring on click and keyboard focus
    /// while keeping controls in the accessibility focus order (unlike `focusable(false)`).
    func macSuppressFocusRing() -> some View {
        focusEffectDisabled()
    }
}

enum MacPalette {
    static let background = Color(red: 0.980, green: 0.969, blue: 0.945) // #FAF7F1 warm cream
    static let surface = Color(red: 1.0, green: 0.988, blue: 0.973)     // #FFFBF7 warm white
    static let surfaceTranslucent = Color.white.opacity(0.72)
    static let ink = Color(red: 0.059, green: 0.165, blue: 0.145)      // #0F2A25 near-black green
    static let muted = Color(red: 0.34, green: 0.35, blue: 0.31)
    static let accent = Color(red: 0.059, green: 0.290, blue: 0.239)   // #0F4A3D forest green
    static let accentSoft = Color(red: 0.78, green: 0.84, blue: 0.78)  // ~#C8D8C7 sage
    static let clay = Color(red: 0.77, green: 0.44, blue: 0.29)        // #C46F4A
    static let sage = Color(red: 0.78, green: 0.85, blue: 0.78)        // #C8D8C7
    static let ochre = Color(red: 0.84, green: 0.71, blue: 0.43)       // #D7B56D
    static let line = Color.black.opacity(0.07)
}

enum MacType {
    /// Uppercase section labels — SF Pro, not serif.
    static let eyebrow = Font.system(size: 11, weight: .semibold, design: .default)
    /// Hero phrases ("Your room.") — editorial serif.
    static let title = Font.system(size: 34, weight: .semibold, design: .serif)
    /// Panel / card titles on cream surfaces — editorial serif.
    static let section = Font.system(size: 20, weight: .semibold, design: .serif)
    /// Body copy and cover meta — SF Pro for readability (mockups use sans for body).
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let small = Font.system(size: 12, weight: .medium, design: .default)
    static let button = Font.system(size: 13, weight: .semibold, design: .default)
    /// White titles on thematic covers.
    static let coverTitle = Font.system(size: 26, weight: .semibold, design: .serif)
    static let coverTitleSmall = Font.system(size: 18, weight: .semibold, design: .serif)
    /// White meta on thematic covers (member counts, room energy).
    static let coverMeta = Font.system(size: 14, weight: .regular, design: .default)
}

struct MacPanel<Content: View>: View {
    var title: String? = nil
    var dark: Bool = false
    var glass: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(MacType.section)
                    .foregroundStyle(dark ? .white : MacPalette.ink)
            }
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgView)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(dark ? MacPalette.accent : MacPalette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(dark ? .white : .primary)
    }

    @ViewBuilder
    private var bgView: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if dark {
            shape.fill(MacPalette.accent)
        } else if glass {
            shape.fill(.ultraThinMaterial)
        } else {
            shape.fill(MacPalette.surface)
        }
    }
}

struct MacBackButton: View {
    let label: String
    let action: () -> Void

    init(label: String = "Back", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: "chevron.left")
                .font(MacType.button)
                .foregroundStyle(MacPalette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(MacPalette.surface, in: Capsule())
                .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(label)
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

struct MacAgeRangeSlider: View {
    @Binding var minAge: Int
    @Binding var maxAge: Int
    var bounds: ClosedRange<Int> = 18...100

    private func fraction(_ age: Int) -> CGFloat {
        CGFloat(age - bounds.lowerBound) / CGFloat(bounds.upperBound - bounds.lowerBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(bounds.lowerBound)")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                Spacer()
                Text("\(minAge) – \(maxAge)")
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                Spacer()
                Text("\(bounds.upperBound)")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }
            GeometryReader { geo in
                let width = geo.size.width
                let lo = fraction(minAge) * width
                let hi = fraction(maxAge) * width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MacPalette.line)
                        .frame(height: 5)
                    Capsule()
                        .fill(MacPalette.accent.opacity(0.35))
                        .frame(width: max(hi - lo, 6), height: 5)
                        .offset(x: lo)
                    Circle()
                        .fill(MacPalette.accent)
                        .frame(width: 14, height: 14)
                        .offset(x: lo - 7)
                    Circle()
                        .fill(MacPalette.accent)
                        .frame(width: 14, height: 14)
                        .offset(x: hi - 7)
                }
            }
            .frame(height: 14)
            Slider(
                value: Binding(
                    get: { Double(minAge) },
                    set: { minAge = min(Int($0.rounded()), maxAge) }
                ),
                in: Double(bounds.lowerBound)...Double(maxAge),
                step: 1
            )
            .tint(MacPalette.accent)
            .accessibilityLabel("Minimum age")
            Slider(
                value: Binding(
                    get: { Double(maxAge) },
                    set: { maxAge = max(Int($0.rounded()), minAge) }
                ),
                in: Double(minAge)...Double(bounds.upperBound),
                step: 1
            )
            .tint(MacPalette.accent)
            .accessibilityLabel("Maximum age")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Age range")
        .accessibilityValue("\(minAge) to \(maxAge)")
    }
}

struct MacRadioCard: View {
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(MacPalette.line, lineWidth: 1)
                        .frame(width: 16, height: 16)
                    if selected {
                        Circle()
                            .fill(MacPalette.accent)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(MacType.button)
                        .foregroundStyle(MacPalette.ink)
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? MacPalette.accent.opacity(0.45) : MacPalette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
    var size: CGFloat = 42

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Text(initials).font(.system(size: size * 0.38, weight: .medium, design: .serif)).foregroundStyle(MacPalette.accent))
    }
}

/// Photo-led profile portrait — circular art with soft sage glow rings (plate 09).
struct MacProfilePortrait: View {
    let assetName: String
    var size: CGFloat = 108

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .stroke(MacPalette.sage.opacity(0.42 - Double(index) * 0.08), lineWidth: 1.5)
                    .frame(width: size + CGFloat(index) * 20, height: size + CGFloat(index) * 20)
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [MacPalette.sage.opacity(0.55), MacPalette.accent.opacity(0.12), .clear],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 0.78
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.92), lineWidth: 2))
                .shadow(color: MacPalette.accent.opacity(0.28), radius: 14, y: 5)
        }
        .frame(width: size + 56, height: size + 56)
        .accessibilityHidden(true)
    }
}

// ponytail: gradient tones cycling for card variety
enum MacTone: CaseIterable {
    case sage, clay, accent, night
    var color: Color {
        switch self {
        case .sage: MacPalette.sage
        case .clay: MacPalette.clay
        case .accent: MacPalette.accent
        case .night: Color(red: 0.12, green: 0.14, blue: 0.18)
        }
    }
}

struct MacGradientCard: View {
    let tone: MacTone
    var height: CGFloat = 130
    var title: String
    var subtitle: String? = nil
    var tags: [String] = []

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [tone.color, tone.color.opacity(0.75), .black.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(.white.opacity(0.05), lineWidth: 1)
                    .frame(width: 120 + CGFloat(i * 60))
                    .offset(x: CGFloat(i * 20), y: CGFloat(i * 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(MacType.coverTitleSmall).foregroundStyle(.white)
                if let subtitle { Text(subtitle).font(MacType.coverMeta).foregroundStyle(.white.opacity(0.9)) }
                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text(tag).font(MacType.small).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                    }
                }
            }
            .doodleOverlayText()
            .padding(18)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MacSearchField: View {
    var placeholder: String = "Search"
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(MacType.body).foregroundStyle(MacPalette.muted)
            Text(placeholder).font(MacType.body).foregroundStyle(MacPalette.muted)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MacPalette.line, lineWidth: 1))
    }
}

struct MacFilterTab: View {
    let label: String
    var isSelected = false
    var body: some View {
        Text(label)
            .font(MacType.button)
            .foregroundStyle(isSelected ? .white : MacPalette.muted)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(isSelected ? MacPalette.accent : .clear, in: Capsule())
    }
}

struct MacWindowChromeHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension Notification.Name {
    static let macPrototypeSelectMeet = Notification.Name("macPrototypeSelectMeet")
    static let macPrototypeSelectCircles = Notification.Name("macPrototypeSelectCircles")
    static let macPrototypeSelectCommunities = Notification.Name("macPrototypeSelectCommunities")
    static let macPrototypeSelectSoulmate = Notification.Name("macPrototypeSelectSoulmate")
    static let macPrototypeSelectProfile = Notification.Name("macPrototypeSelectProfile")
}


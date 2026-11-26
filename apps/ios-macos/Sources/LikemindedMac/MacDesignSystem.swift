import AppKit
import SwiftUI

extension View {
    /// Suppresses the default macOS blue focus ring on click and keyboard focus
    /// while keeping controls in the accessibility focus order (unlike `focusable(false)`).
    func macSuppressFocusRing() -> some View {
        focusEffectDisabled()
    }
}

typealias MacPalette = LikemindedPalette

enum MacType {
    /// Uppercase section labels — SF Pro, not serif. Shared 14-point floor.
    static var eyebrow: Font { LikemindedTypography.scaled(size: 14, weight: .semibold, design: .default, textStyle: .caption) }
    /// Hero phrases ("Your room.") — editorial serif.
    static var title: Font { LikemindedTypography.scaled(size: 34, weight: .semibold, design: .serif, textStyle: .largeTitle) }
    static var display: Font { LikemindedTypography.scaled(size: 44, weight: .semibold, design: .serif, textStyle: .largeTitle) }
    static var pageTitle: Font { LikemindedTypography.scaled(size: 38, weight: .semibold, design: .serif, textStyle: .largeTitle) }
    /// Panel / card titles on cream surfaces — editorial serif.
    static var section: Font { LikemindedTypography.scaled(size: 24, weight: .semibold, design: .serif, textStyle: .title2) }
    static var cardTitle: Font { LikemindedTypography.scaled(size: 22, weight: .semibold, design: .serif, textStyle: .title3) }
    static var smallSerif: Font { LikemindedTypography.scaled(size: 16, weight: .semibold, design: .serif, textStyle: .headline) }
    static var subheading: Font { LikemindedTypography.scaled(size: 28, weight: .semibold, design: .serif, textStyle: .title) }
    static var serifCallout: Font { LikemindedTypography.scaled(size: 20, weight: .medium, design: .serif, textStyle: .title3) }
    /// Body copy and cover meta — SF Pro for readability (mockups use sans for body).
    static var body: Font { LikemindedTypography.scaled(size: 18, weight: .regular, design: .default, textStyle: .body) }
    static var small: Font { LikemindedTypography.scaled(size: 16, weight: .medium, design: .default, textStyle: .callout) }
    static var button: Font { LikemindedTypography.button }
    static var caption: Font { LikemindedTypography.caption }
    static var metric: Font { LikemindedTypography.scaled(size: 72, weight: .semibold, design: .serif, textStyle: .largeTitle) }
    static var metricValue: Font { LikemindedTypography.scaled(size: 28, weight: .semibold, design: .rounded, textStyle: .title) }
    static var iconSmall: Font { LikemindedTypography.scaled(size: 16, weight: .semibold, design: .default, textStyle: .callout) }
    static var iconMedium: Font { LikemindedTypography.scaled(size: 22, weight: .semibold, design: .default, textStyle: .title3) }
    static var iconHero: Font { LikemindedTypography.scaled(size: 28, weight: .medium, design: .default, textStyle: .title) }
    static var iconProminent: Font { LikemindedTypography.scaled(size: 26, weight: .semibold, design: .default, textStyle: .title) }
    static var icon: Font { LikemindedTypography.scaled(size: 18, weight: .semibold, design: .default, textStyle: .body) }
    static var iconLarge: Font { LikemindedTypography.scaled(size: 36, weight: .regular, design: .default, textStyle: .largeTitle) }
    static var decorativeIcon: Font { LikemindedTypography.scaled(size: 30, weight: .semibold, design: .default, textStyle: .title) }
    static var roundedInitials: Font { LikemindedTypography.scaled(size: 18, weight: .semibold, design: .rounded, textStyle: .body) }
    static var roundedInitialsLarge: Font { LikemindedTypography.scaled(size: 30, weight: .semibold, design: .rounded, textStyle: .title) }
    static func avatarInitials(diameter: CGFloat) -> Font {
        LikemindedTypography.scaled(size: max(LikemindedTypography.minimumPointSize, diameter * 0.38), weight: .medium, design: .serif, textStyle: .body)
    }
    /// White titles on thematic covers.
    static var coverTitle: Font { LikemindedTypography.scaled(size: 26, weight: .semibold, design: .serif, textStyle: .title) }
    static var coverTitleSmall: Font { LikemindedTypography.scaled(size: 18, weight: .semibold, design: .serif, textStyle: .body) }
    /// White meta on thematic covers (member counts, room energy).
    static var coverMeta: Font { LikemindedTypography.scaled(size: 14, weight: .regular, design: .default, textStyle: .caption) }
}

private struct MacScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Vertical scroller with a always-visible indicator and a "Scroll for more" cue
/// when content overflows the default window (UI-08).
struct MacScrollCanvas<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var atBottom = false

    private var showsCue: Bool {
        contentHeight > viewportHeight + 8 && !atBottom
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                content
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(key: MacScrollContentHeightKey.self, value: geometry.size.height)
                        }
                    }
            }
            .scrollIndicators(.visible)
            .onAppear { viewportHeight = proxy.size.height }
            .onChange(of: proxy.size.height) { _, height in viewportHeight = height }
            .onPreferenceChange(MacScrollContentHeightKey.self) { contentHeight = $0 }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 12
            } action: { _, nowAtBottom in
                atBottom = nowAtBottom
            }
            .overlay(alignment: .bottom) {
                if showsCue {
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [MacPalette.background.opacity(0), MacPalette.background.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.down")
                            Text("Scroll for more")
                        }
                        .font(MacType.caption)
                        .foregroundStyle(MacPalette.muted)
                        .padding(.bottom, 8)
                    }
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Scroll for more")
                    .accessibilityIdentifier("scroll-for-more")
                }
            }
        }
    }
}

struct MacPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MacType.button)
            .foregroundStyle(isEnabled ? MacPalette.onAccent : MacPalette.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isEnabled ? MacPalette.accent : MacPalette.accentSoft,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MacSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        return configuration.label
            .font(MacType.button)
            .foregroundStyle(isEnabled ? MacPalette.accent : MacPalette.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? MacPalette.accentSoft : MacPalette.surface, in: shape)
            .overlay(shape.stroke(isEnabled ? MacPalette.accent : MacPalette.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}


/// In-window confirm/alert so destructive actions use brand clay and ink
/// instead of the system pink and blue confirmation dialog (UI-13).
struct MacBrandDialog: View {
    let title: String
    let message: String
    var confirmTitle: String? = nil
    var confirmDestructive = false
    var cancelTitle: String = "Cancel"
    var onConfirm: (() -> Void)? = nil
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            MacPalette.ink.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(MacType.cardTitle)
                    .foregroundStyle(MacPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let confirmTitle, confirmDestructive {
                    Button(confirmTitle) { onConfirm?() }
                        .buttonStyle(MacDestructiveButtonStyle())
                        .accessibilityLabel(confirmTitle)
                } else if let confirmTitle {
                    Button(confirmTitle) { onConfirm?() }
                        .buttonStyle(MacPrimaryButtonStyle())
                        .accessibilityLabel(confirmTitle)
                }

                Button(cancelTitle, action: onCancel)
                    .buttonStyle(MacSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(cancelTitle)
            }
            .padding(24)
            .frame(width: 420, alignment: .leading)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("brand-dialog")
            .accessibilityLabel(title)
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct MacDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MacType.button)
            .foregroundStyle(isEnabled ? MacPalette.onAccent : MacPalette.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isEnabled ? MacPalette.clay : MacPalette.accentSoft,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
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
                    .foregroundStyle(dark ? LikemindedPalette.inverseText : MacPalette.ink)
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
        .foregroundStyle(dark ? LikemindedPalette.inverseText : .primary)
    }

    @ViewBuilder
    private var bgView: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if dark {
            shape.fill(MacPalette.coverForest)
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
            .foregroundStyle(isSelected ? MacPalette.onAccent : MacPalette.ink)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? MacPalette.accent : MacPalette.surface, in: Capsule())
            .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
    }
}

/// Welcome-screen convergence field — see `ConvergenceFieldView` in Shared/.
struct MacConvergenceField: View {
    var body: some View {
        ConvergenceFieldView(background: MacPalette.background)
    }
}

/// Compact, activity-driven convergence field for AI conversation surfaces.
/// Quiet at rest; faster and clearer only while the model is generating or speaking.
struct ProfileAIActivityField: View {
    let isActive: Bool
    var audioLevel = 0.0
    var exposesAudioLevel = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: isActive ? 1.0 / 20.0 : 0.5, paused: reduceMotion)) { timeline in
            let phase = CGFloat(reduceMotion || !isActive ? 0 : timeline.date.timeIntervalSinceReferenceDate * 1.65)
            let level = CGFloat(min(max(audioLevel, 0), 1))
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let maxRadius = min(size.width, size.height) * 0.46
                for ring in 0..<26 {
                    let progress = CGFloat(ring + 1) / 26
                    let baseRadius = maxRadius * progress
                    var path = Path()
                    for point in 0...96 {
                        let angle = CGFloat(point) / 96 * .pi * 2
                        let ringPhase = CGFloat(ring) * 0.16
                        let flow = sin(angle * 3 + phase + ringPhase)
                        let drift = cos(angle * 2 - phase * 0.65) * 0.55
                        let warpStrength: CGFloat = isActive ? 7.2 + (level * 13) : 1.35
                        let warp = (flow + drift) * warpStrength * progress
                        let biasStrength: CGFloat = isActive ? 5.2 + (level * 7) : 0.8
                        let xBias = sin(angle + phase * 0.35) * biasStrength * progress
                        let x = center.x + cos(angle) * (baseRadius + warp) + xBias
                        let y = center.y + sin(angle) * (baseRadius - warp * 0.42)
                        let contourPoint = CGPoint(x: x, y: y)
                        if path.isEmpty { path.move(to: contourPoint) } else { path.addLine(to: contourPoint) }
                    }
                    path.closeSubpath()
                    let baseOpacity: CGFloat = isActive ? 0.52 : 0.22
                    let opacity = baseOpacity * (1 - progress * 0.38)
                    let lineWidth: CGFloat = ring % 5 == 0 ? 0.9 : 0.55
                    context.stroke(
                        path,
                        with: .color(MacPalette.ink.opacity(opacity)),
                        lineWidth: lineWidth
                    )
                }
            }
            .background(
                RadialGradient(
                    colors: [
                        MacPalette.accentSoft.opacity(isActive ? 0.9 : 0.58),
                        MacPalette.background.opacity(0.18)
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 120
                )
            )
        }
        .scaleEffect(isActive && !reduceMotion ? 1.025 + (audioLevel * 0.045) : 1)
        .animation(.easeInOut(duration: 0.4), value: isActive)
        .clipShape(Circle())
        .overlay(Circle().stroke(MacPalette.accent.opacity(isActive ? 0.2 : 0.08), lineWidth: 1))
        .shadow(color: MacPalette.accent.opacity(isActive ? 0.14 : 0.05), radius: isActive ? 18 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Microphone activity")
        .accessibilityValue("\(Int(audioLevel * 100)) percent")
        .accessibilityHidden(!exposesAudioLevel)
    }
}

/// Meet hero atmosphere — generated at render size, so line sharpness survives resizing.
struct MacMeetVenueConvergenceField: View {
    private let contourCount = 74
    private let pointsPerContour = 150
    private let shapeCount = 3

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let focus = Self.pinPosition(in: size)
                let minSide = min(size.width, size.height)
                let reach = Self.maxDistanceToCorner(from: focus, in: size) * 1.08

                for shape in 0..<shapeCount {
                    let shapePhase = Double(shape) * .pi * 2.0 / Double(shapeCount)
                    let center = CGPoint(
                        x: focus.x + CGFloat(sin(shapePhase * 0.7)) * minSide * 0.12,
                        y: focus.y + CGFloat(cos(shapePhase * 0.9)) * minSide * 0.08
                    )

                    for contour in 0..<contourCount {
                        let t = CGFloat(contour) / CGFloat(contourCount - 1)
                        let radius = minSide * 0.035 + reach * t
                        var path = Path()
                        var started = false

                        for pointIndex in 0...pointsPerContour {
                            let p = Double(pointIndex) / Double(pointsPerContour)
                            let angle = p * .pi * 2.0
                            let wave = 1.0
                                + 0.055 * sin(angle * 3.0 + shapePhase)
                                + 0.032 * cos(angle * 5.0 - shapePhase * 0.65)
                                + 0.016 * sin(angle * 8.0 + Double(contour) * 0.12)

                            let x = center.x + CGFloat(cos(angle) * wave) * radius
                            let y = center.y + CGFloat(sin(angle) * wave) * radius * 0.44

                            if x < size.width * 0.08 {
                                started = false
                                continue
                            }

                            let next = CGPoint(x: x, y: y)
                            if started {
                                path.addLine(to: next)
                            } else {
                                path.move(to: next)
                                started = true
                            }
                        }

                        let rightWeight = Self.smoothstep(0.22, 0.62, center.x / max(size.width, 1))
                        let alpha = (0.018 + 0.046 * rightWeight) * (1.0 - 0.24 * t)
                        context.stroke(path, with: .color(MacPalette.ink.opacity(alpha)), lineWidth: 0.42)
                    }
                }
            }
        }
        .background(MacPalette.background)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func pinPosition(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * 0.76,
            y: size.height * 0.50
        )
    }

    private static func maxDistanceToCorner(from point: CGPoint, in size: CGSize) -> CGFloat {
        [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        .map { hypot($0.x - point.x, $0.y - point.y) }
        .max() ?? max(size.width, size.height)
    }

    private static func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
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
                .fill(RadialGradient(colors: [MacPalette.orbHighlight, MacPalette.accentSoft, MacPalette.accent.opacity(0.18)], center: .center, startRadius: 4, endRadius: 92))
                .frame(width: 160, height: 160)
            Image(systemName: heart ? "heart.fill" : "sparkle")
                .font(MacType.decorativeIcon)
                .foregroundStyle(MacPalette.accentDeep)
                .shadow(color: MacPalette.accent.opacity(0.45), radius: 16)
        }
    }
}

struct MacAgeRangeSlider: View {
    @Binding var minAge: Int
    @Binding var maxAge: Int
    var bounds: ClosedRange<Int> = 18...80

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
            .accessibilityValue("\(minAge)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    minAge = min(minAge + 1, maxAge)
                case .decrement:
                    minAge = max(bounds.lowerBound, minAge - 1)
                @unknown default:
                    break
                }
            }
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
            .accessibilityValue("\(maxAge)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    maxAge = min(bounds.upperBound, maxAge + 1)
                case .decrement:
                    maxAge = max(minAge, maxAge - 1)
                @unknown default:
                    break
                }
            }
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

    private var accessibilityIdentifier: String {
        switch title {
        case "Circles only":
            return "discovery-visibility-circles"
        case "Circles and communities":
            return "discovery-visibility-circles-communities"
        case "Mutual matches only":
            return "discovery-visibility-mutual-matches"
        case "Visible in discover":
            return "discovery-visibility-discover"
        case "Visible only after both like":
            return "discovery-visibility-private"
        default:
            return "radio-\(title)"
        }
    }

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
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    // Keep title Text in the AX tree — CUA snap/SOM matches visible
                    // text nodes; children:.ignore hid "Visible in discover" entirely.
                    Text(title)
                        .font(MacType.button)
                        .foregroundStyle(MacPalette.ink)
                    Text(detail)
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                        .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}

struct MacHeroArt: View {
    let tone: Color
    var label: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [tone.opacity(0.95), MacPalette.coverForest.opacity(0.88), MacPalette.coverScrim], startPoint: .topTrailing, endPoint: .bottomLeading)
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(MacPalette.coverHairline, lineWidth: 1)
                    .frame(width: CGFloat(220 + index * 90))
                    .offset(x: CGFloat(index * 24), y: CGFloat(index * -12))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(MacType.section)
                    .foregroundStyle(LikemindedPalette.inverseText)
                Text("Thoughtful - Calm - Curious")
                    .font(MacType.small)
                    .foregroundStyle(LikemindedPalette.whiteOverlay(alpha: 0.82))
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
            .overlay(Text(initials).font(MacType.avatarInitials(diameter: size)).foregroundStyle(MacPalette.accent))
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
                .overlay(Circle().stroke(MacPalette.coverAvatarRing, lineWidth: 2))
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
        case .sage: MacPalette.coverSage
        case .clay: MacPalette.coverClay
        case .accent: MacPalette.coverForestLight
        case .night: MacPalette.dusk
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
            LinearGradient(colors: [tone.color, tone.color.opacity(0.75), MacPalette.photoScrim], startPoint: .topLeading, endPoint: .bottomTrailing)
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(LikemindedPalette.whiteOverlay(alpha: 0.05), lineWidth: 1)
                    .frame(width: 120 + CGFloat(i * 60))
                    .offset(x: CGFloat(i * 20), y: CGFloat(i * 10))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(MacType.coverTitleSmall).foregroundStyle(LikemindedPalette.inverseText)
                if let subtitle { Text(subtitle).font(MacType.coverMeta).foregroundStyle(LikemindedPalette.whiteOverlay(alpha: 0.9)) }
                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text(tag).font(MacType.small).foregroundStyle(LikemindedPalette.inverseText)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(MacPalette.coverTag, in: Capsule())
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
            .foregroundStyle(isSelected ? MacPalette.onAccent : MacPalette.muted)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(isSelected ? MacPalette.accent : .clear, in: Capsule())
    }
}

enum MacWindowMetrics {
    static let minWidth: CGFloat = 1120
    static let minHeight: CGFloat = 720
    static let defaultWidth: CGFloat = 1200
    static let defaultHeight: CGFloat = 760
}

enum MacWindowChrome {
    static let backgroundNSColor = MacPalette.backgroundNSColor
}

struct MacWindowChromeHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            Self.configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configure(window: nsView.window)
        }
    }

    private static func configure(window: NSWindow?) {
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.backgroundColor = MacWindowChrome.backgroundNSColor
        window.isOpaque = true

        let minSize = NSSize(width: MacWindowMetrics.minWidth, height: MacWindowMetrics.minHeight)
        window.contentMinSize = minSize
        window.minSize = minSize

        var frame = window.frame
        let needsResize = frame.width < minSize.width || frame.height < minSize.height
        if needsResize {
            frame.size = NSSize(
                width: max(frame.width, minSize.width),
                height: max(frame.height, minSize.height)
            )
            window.setFrame(frame, display: true)
        }
    }
}

extension Notification.Name {
    static let macPrototypeSelectMeet = Notification.Name("macPrototypeSelectMeet")
    static let macPrototypeSelectCircles = Notification.Name("macPrototypeSelectCircles")
    static let macPrototypeSelectCommunities = Notification.Name("macPrototypeSelectCommunities")
    static let macPrototypeSelectSoulmate = Notification.Name("macPrototypeSelectSoulmate")
    static let macPrototypeSelectProfile = Notification.Name("macPrototypeSelectProfile")
}

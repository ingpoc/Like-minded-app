import SwiftUI

struct WaveLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        for offset in stride(from: -80.0, through: 80.0, by: 10.0) {
            path.move(to: CGPoint(x: rect.maxX * 0.58, y: mid + offset))
            path.addCurve(
                to: CGPoint(x: rect.maxX + 30, y: mid + offset * 0.55),
                control1: CGPoint(x: rect.maxX * 0.72, y: mid + offset - 34),
                control2: CGPoint(x: rect.maxX * 0.88, y: mid + offset + 34)
            )
        }
        return path
    }
}

struct ScreenContainer<Content: View, TrailingHeader: View>: View {
    let title: String
    let subtitle: String
    var caption: String?
    @ViewBuilder var trailingHeader: TrailingHeader
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String,
        caption: String? = nil,
        @ViewBuilder trailingHeader: () -> TrailingHeader,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.caption = caption
        self.trailingHeader = trailingHeader()
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title.uppercased())
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)

                        Text(subtitle)
                            .font(PrototypeTypography.display)
                            .foregroundStyle(PrototypePalette.ink)
                            .frame(maxWidth: 320, alignment: .leading)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        if let caption, !caption.isEmpty {
                            Text(caption)
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.subink)
                                .frame(maxWidth: 320, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    trailingHeader
                }

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 180)
        }
        .contentMargins(.top, 12, for: .scrollContent)
        .background {
            PrototypePalette.background.ignoresSafeArea()
        }
#if os(iOS)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(PrototypePalette.background.opacity(0.96), for: .navigationBar)
#endif
    }
}

extension ScreenContainer where TrailingHeader == EmptyView {
    init(title: String, subtitle: String, caption: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, caption: caption, trailingHeader: { EmptyView() }, content: content)
    }
}

struct FeatureCard<Content: View>: View {
    let title: String
    let eyebrow: String?
    @ViewBuilder var content: Content

    init(title: String, eyebrow: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.eyebrow = eyebrow
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(PrototypeTypography.eyebrow)
                    .foregroundStyle(PrototypePalette.accent)
            }

            Text(title)
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(PrototypePalette.ink)

            content
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PrototypePalette.rule)
                .frame(height: 1)
        }
    }
}

struct TokenRow: View {
    let items: [String]

    var body: some View {
        FlexibleTagLayout(items: items)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(PrototypeTypography.button)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PrototypePalette.actionGradient)
            )
            .shadow(color: PrototypePalette.accent.opacity(0.18), radius: 14, y: 8)
    }
}

struct SecondaryActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(PrototypeTypography.button)
            .foregroundStyle(PrototypePalette.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PrototypePalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(PrototypePalette.rule, lineWidth: 1)
            )
    }
}

struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(PrototypeTypography.metric)
                .foregroundStyle(PrototypePalette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MiniMetricCard: View {
    let icon: String
    let value: String
    let label: String
    var floatDelay: Double = 0

    @State private var isFloating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)

            Text(value)
                .font(PrototypeTypography.metric)
                .foregroundStyle(PrototypePalette.ink)

            Text(label)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PrototypePalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
        .offset(y: isFloating ? -2 : 2)
        .task {
            guard !isFloating else { return }
            try? await Task.sleep(for: .seconds(floatDelay))
            withAnimation(.easeInOut(duration: 4.6).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}

struct IconPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)

            Text(title)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule(style: .continuous)
                .fill(PrototypePalette.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }
}

struct LikemindedGlyph: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.38))
                .frame(width: 154, height: 154)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(PrototypePalette.rule, lineWidth: 1)
                )
                .rotationEffect(.degrees(isAnimating ? 0.6 : -0.6))

            Path { path in
                path.move(to: CGPoint(x: 46, y: 48))
                path.addLine(to: CGPoint(x: 78, y: 94))
                path.addLine(to: CGPoint(x: 112, y: 56))
            }
            .stroke(PrototypePalette.accent.opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .frame(width: 154, height: 154)
            .scaleEffect(isAnimating ? 1.01 : 0.99)

            Circle()
                .fill(PrototypePalette.accentSoft)
                .frame(width: 44, height: 44)
                .offset(x: isAnimating ? -34 : -28, y: isAnimating ? -28 : -34)

            Circle()
                .fill(PrototypePalette.accent)
                .frame(width: 34, height: 34)
                .offset(x: isAnimating ? 32 : 38, y: isAnimating ? -18 : -14)

            Circle()
                .fill(Color.white)
                .frame(width: 62, height: 62)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PrototypePalette.ink)
                        .rotationEffect(.degrees(isAnimating ? 4 : -4))
                )
                .offset(x: 0, y: isAnimating ? 31 : 36)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 18, y: 12)
        .accessibilityHidden(true)
        .task {
            guard !isAnimating else { return }
            withAnimation(.easeInOut(duration: 6.4).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

enum JourneyTone {
    case accent
    case secondary

    var color: Color {
        switch self {
        case .accent:
            return PrototypePalette.accent
        case .secondary:
            return PrototypePalette.subink
        }
    }

    var background: Color {
        switch self {
        case .accent:
            return PrototypePalette.accentSoft.opacity(0.55)
        case .secondary:
            return Color.white.opacity(0.80)
        }
    }
}

struct JourneyStep: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tone: JourneyTone
}

struct JourneyStepRow: View {
    let step: JourneyStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(step.tone.background)
                    .frame(width: 38, height: 38)

                Text(step.systemImage)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(step.tone.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)

                Text(step.detail)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }
        }
    }
}

struct FlexibleTagLayout: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    TagView(title: item)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    TagView(title: item)
                }
            }
        }
    }
}

struct TagView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(PrototypeTypography.metadata)
            .foregroundStyle(PrototypePalette.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(PrototypePalette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(PrototypePalette.rule, lineWidth: 1)
            )
    }
}

struct LikemindedEntranceModifier: ViewModifier {
    let order: Int
    let isActive: Bool
    var x: CGFloat = 0
    var y: CGFloat = 24
    var scale: CGFloat = 0.96

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .blur(radius: isActive ? 0 : 4)
            .scaleEffect(isActive ? 1 : scale, anchor: .topLeading)
            .offset(x: isActive ? 0 : x, y: isActive ? 0 : y)
            .animation(
                .spring(response: 0.78, dampingFraction: 0.9)
                    .delay(Double(order) * 0.045),
                value: isActive
            )
    }
}

extension View {
    func likemindedEntrance(
        order: Int,
        isActive: Bool,
        x: CGFloat = 0,
        y: CGFloat = 24,
        scale: CGFloat = 0.96
    ) -> some View {
        modifier(
            LikemindedEntranceModifier(
                order: order,
                isActive: isActive,
                x: x,
                y: y,
                scale: scale
            )
        )
    }

    func prototypeBackNavigation(label: String = "Back") -> some View {
        overlay(alignment: .topLeading) {
            PrototypeBackButton(label: label)
                .padding(.leading, 20)
                .padding(.top, 12)
        }
    }
}

struct PrototypeBackButton: View {
    enum Style {
        case surface
        case overlay
    }

    @Environment(\.dismiss) private var dismiss
    let label: String
    let style: Style
    let action: (() -> Void)?

    init(label: String = "Back", style: Style = .surface, action: (() -> Void)? = nil) {
        self.label = label
        self.style = style
        self.action = action
    }

    var body: some View {
        Button {
            if let action {
                action()
            } else {
                dismiss()
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: 44, height: 44)
                .background(backgroundColor)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var foregroundColor: Color {
        switch style {
        case .surface:
            return PrototypePalette.ink
        case .overlay:
            return .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .surface:
            return PrototypePalette.surface
        case .overlay:
            return Color.black.opacity(0.28)
        }
    }
}

struct PrototypeAgeRangeSlider: View {
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
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.muted)
                Spacer()
                Text("\(minAge) – \(maxAge)")
                    .font(PrototypeTypography.button)
                    .foregroundStyle(PrototypePalette.ink)
                Spacer()
                Text("\(bounds.upperBound)")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.muted)
            }
            GeometryReader { geo in
                let width = geo.size.width
                let lo = fraction(minAge) * width
                let hi = fraction(maxAge) * width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PrototypePalette.rule)
                        .frame(height: 5)
                    Capsule()
                        .fill(PrototypePalette.accent.opacity(0.35))
                        .frame(width: max(hi - lo, 6), height: 5)
                        .offset(x: lo)
                    Circle()
                        .fill(PrototypePalette.accent)
                        .frame(width: 14, height: 14)
                        .offset(x: lo - 7)
                    Circle()
                        .fill(PrototypePalette.accent)
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
            .tint(PrototypePalette.accent)
            .accessibilityLabel("Minimum age")
            Slider(
                value: Binding(
                    get: { Double(maxAge) },
                    set: { maxAge = max(Int($0.rounded()), minAge) }
                ),
                in: Double(minAge)...Double(bounds.upperBound),
                step: 1
            )
            .tint(PrototypePalette.accent)
            .accessibilityLabel("Maximum age")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Age range")
        .accessibilityValue("\(minAge) to \(maxAge)")
    }
}

struct PrototypeRadioCard: View {
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(PrototypePalette.rule, lineWidth: 1)
                        .frame(width: 16, height: 16)
                    if selected {
                        Circle()
                            .fill(PrototypePalette.accent)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PrototypeTypography.button)
                        .foregroundStyle(PrototypePalette.ink)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? PrototypePalette.accent.opacity(0.45) : PrototypePalette.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

enum PrototypeTypography {
    static let eyebrow = Font.system(size: 11, weight: .semibold)
        .smallCaps()
    static let display = Font.system(size: 26, weight: .medium, design: .serif)
    static let hero = Font.system(size: 42, weight: .medium, design: .serif)
    static let cardTitle = Font.system(size: 24, weight: .medium, design: .serif)
    static let heroBody = Font.system(size: 16, weight: .regular)
    static let sectionTitle = Font.system(size: 17, weight: .semibold)
    static let quote = Font.system(size: 20, weight: .semibold)
    static let metric = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyStrong = Font.system(size: 15, weight: .semibold)
    static let button = Font.system(size: 15, weight: .semibold)
    static let metadata = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 14, weight: .regular)
}

enum PrototypePalette {
    static let background = Color(red: 0.984, green: 0.970, blue: 0.938)
    static let surface = Color(red: 1.000, green: 0.991, blue: 0.973)
    static let accent = Color(red: 0.059, green: 0.290, blue: 0.239)
    static let accentDeep = Color(red: 0.031, green: 0.220, blue: 0.184)
    static let accentSoft = Color(red: 0.898, green: 0.941, blue: 0.918)
    static let success = Color(red: 0.235, green: 0.608, blue: 0.373)
    static let amber = Color(red: 0.780, green: 0.514, blue: 0.063)
    static let coral = Color(red: 0.914, green: 0.510, blue: 0.400)
    static let teal = Color(red: 0.184, green: 0.478, blue: 0.471)
    static let ink = Color(red: 0.063, green: 0.165, blue: 0.145)
    static let subink = Color(red: 0.373, green: 0.384, blue: 0.365)
    static let muted = Color(red: 0.541, green: 0.541, blue: 0.510)
    static let rule = Color(red: 0.902, green: 0.875, blue: 0.835)
    static let gold = Color(red: 0.918, green: 0.732, blue: 0.433)
    static let dusk = Color(red: 0.118, green: 0.075, blue: 0.157)
    static let rose = Color(red: 0.890, green: 0.398, blue: 0.584)

    static let actionGradient = LinearGradient(
        colors: [accent, Color(red: 0.021, green: 0.392, blue: 0.257)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func roomGradient(_ index: Int = 0) -> LinearGradient {
        let palettes: [[Color]] = [
            [accentDeep, accent, gold.opacity(0.62)],
            [Color(red: 0.078, green: 0.270, blue: 0.255), teal, Color(red: 0.682, green: 0.758, blue: 0.545)],
            [Color(red: 0.250, green: 0.126, blue: 0.153), Color(red: 0.650, green: 0.247, blue: 0.177), Color(red: 0.965, green: 0.604, blue: 0.353)],
            [dusk, Color(red: 0.247, green: 0.160, blue: 0.335), rose.opacity(0.58)]
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

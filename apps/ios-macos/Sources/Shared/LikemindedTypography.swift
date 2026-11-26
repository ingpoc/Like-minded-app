import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Process-wide Dynamic Type size so token fonts can scale on Mac and iOS.
enum LikemindedTypeRuntime {
    static var current: DynamicTypeSize = launchOverride ?? .large

    static var launchOverride: DynamicTypeSize? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--likeminded-dynamic-type-size"),
              arguments.indices.contains(index + 1) else { return nil }
        return parse(arguments[index + 1])
    }()

    static func parse(_ raw: String) -> DynamicTypeSize? {
        switch raw {
        case "xSmall": return .xSmall
        case "small": return .small
        case "medium": return .medium
        case "large": return .large
        case "xLarge": return .xLarge
        case "xxLarge": return .xxLarge
        case "xxxLarge": return .xxxLarge
        case "accessibility1": return .accessibility1
        case "accessibility2": return .accessibility2
        case "accessibility3": return .accessibility3
        case "accessibility4": return .accessibility4
        case "accessibility5": return .accessibility5
        default: return nil
        }
    }

    static func scaleFactor(for size: DynamicTypeSize = current) -> CGFloat {
        switch size {
        case .xSmall: return 0.82
        case .small: return 0.88
        case .medium: return 0.94
        case .large: return 1.0
        case .xLarge: return 1.12
        case .xxLarge: return 1.23
        case .xxxLarge: return 1.35
        case .accessibility1: return 1.55
        case .accessibility2: return 1.75
        case .accessibility3: return 1.95
        case .accessibility4: return 2.15
        case .accessibility5: return 2.35
        default: return 1.0
        }
    }

    static func applyLaunchOverride() {
        if let launchOverride {
            current = launchOverride
        }
    }
}

/// Cross-target type tokens shared by the iOS and macOS apps.
///
/// One scale on both platforms: the same design sizes, a 14-point floor,
/// and Dynamic Type that may scale up but never shrink below the token.
enum LikemindedTypography {
    static var compact: Font { scaled(size: 14, weight: .regular, design: .default, textStyle: .body) }
    static var body: Font { scaled(size: 14, weight: .regular, design: .default, textStyle: .body) }
    static var caption: Font { scaled(size: 14, weight: .regular, design: .default, textStyle: .callout) }
    static var button: Font { scaled(size: 16, weight: .semibold, design: .default, textStyle: .body) }
    static var pageTitle: Font { scaled(size: 24, weight: .semibold, design: .serif, textStyle: .title2) }
    static var iconSmall: Font { scaled(size: 14, weight: .semibold, design: .default, textStyle: .callout) }
    static var icon: Font { scaled(size: 18, weight: .semibold, design: .default, textStyle: .body) }
    static var iconLarge: Font { scaled(size: 22, weight: .semibold, design: .default, textStyle: .title3) }

    /// Design size for the compact token, and the typography floor on both platforms.
    static let minimumPointSize: CGFloat = 14

    static func scaled(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        textStyle: Font.TextStyle
    ) -> Font {
        let floored = max(size, minimumPointSize)
        #if canImport(UIKit) && !os(macOS)
        if LikemindedTypeRuntime.launchOverride != nil {
            let point = max(minimumPointSize, floored * LikemindedTypeRuntime.scaleFactor())
            return Font(uiFont(size: point, weight: weight, design: design))
        }
        let base = uiFont(size: floored, weight: weight, design: design)
        let scaledFont = UIFontMetrics(forTextStyle: uiTextStyle(textStyle)).scaledFont(for: base)
        let point = max(floored, scaledFont.pointSize)
        return Font(base.withSize(point))
        #else
        let point = max(minimumPointSize, floored * LikemindedTypeRuntime.scaleFactor())
        return Font.system(size: point, weight: weight, design: design)
        #endif
    }

    #if canImport(UIKit) && !os(macOS)
    private static func uiFont(size: CGFloat, weight: Font.Weight, design: Font.Design) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: size, weight: uiWeight(weight)).fontDescriptor
        switch design {
        case .serif:
            if let serif = descriptor.withDesign(.serif) { descriptor = serif }
        case .rounded:
            if let rounded = descriptor.withDesign(.rounded) { descriptor = rounded }
        case .monospaced:
            if let mono = descriptor.withDesign(.monospaced) { descriptor = mono }
        default:
            break
        }
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        default: return .body
        }
    }
    #endif
}

struct LikemindedTypeSizeBinder: ViewModifier {
    @Environment(\.dynamicTypeSize) private var size

    func body(content: Content) -> some View {
        content
            .onAppear { sync() }
            .onChange(of: size) { _, _ in sync() }
    }

    private func sync() {
        LikemindedTypeRuntime.current = LikemindedTypeRuntime.launchOverride ?? size
    }
}

extension View {
    func likemindedTypography() -> some View {
        let bound = modifier(LikemindedTypeSizeBinder())
        if let override = LikemindedTypeRuntime.launchOverride {
            return AnyView(bound.environment(\.dynamicTypeSize, override))
        }
        return AnyView(bound)
    }
}

/// Debug-only specimen that proves the 14-point floor and shared token names.
struct LikemindedTypographySpecimenView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Shared typography")
                    .font(LikemindedTypography.pageTitle)
                    .accessibilityAddTraits(.isHeader)

                Text("One iOS and Mac scale. Compact, caption, and body use a 14 point floor and scale up with Dynamic Type.")
                    .font(LikemindedTypography.body)
                    .fixedSize(horizontal: false, vertical: true)

                tokenRow(name: "Compact", sample: "The compact token stays at least 14 points.", font: LikemindedTypography.compact)
                tokenRow(name: "Caption", sample: "The caption token stays at least 14 points.", font: LikemindedTypography.caption)
                tokenRow(name: "Body", sample: "The body token stays at least 14 points.", font: LikemindedTypography.body)
                tokenRow(name: "Button", sample: "Button 16 points, still above the floor.", font: LikemindedTypography.button)
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .background(LikemindedPalette.background.ignoresSafeArea())
        .foregroundStyle(LikemindedPalette.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("typography-specimen")
        .accessibilityLabel("Shared typography specimen. Compact, caption, and body use a 14 point floor.")
    }

    private func tokenRow(name: String, sample: String, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(name) · 14 point floor")
                .font(LikemindedTypography.caption.weight(.semibold))
                .foregroundStyle(LikemindedPalette.accent)
            Text(sample)
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(name). \(sample)")
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("typography-\(name.lowercased())")
    }
}

import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Shared semantic colours for the native iOS and macOS apps.
enum LikemindedPalette {
    #if canImport(AppKit)
    private static func adaptiveColor(
        _ name: String,
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(nsColor: adaptiveNSColor(
            name,
            light: light,
            dark: dark,
            lightAlpha: lightAlpha,
            darkAlpha: darkAlpha
        ))
    }

    private static func adaptiveNSColor(
        _ name: String,
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> NSColor {
        NSColor(name: NSColor.Name("com.likeminded.palette.\(name)")) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        }
    }

    private static func nsColor(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    static let backgroundNSColor = adaptiveNSColor("window-background", light: 0xFAF7F1, dark: 0x151816)
    #elseif canImport(UIKit)
    private static func adaptiveColor(
        _ name: String,
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return uiColor(isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        })
    }

    private static func uiColor(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
    #endif

    static let background = adaptiveColor("background", light: 0xFAF7F1, dark: 0x151816)
    static let welcomeBackdrop = adaptiveColor("welcome-backdrop", light: 0xEFE3C7, dark: 0x25231E)
    static let surface = adaptiveColor("surface", light: 0xFFFBF7, dark: 0x1E2320)
    static let surfaceTranslucent = adaptiveColor(
        "surface-translucent",
        light: 0xFFFBF7,
        dark: 0x252B27,
        lightAlpha: 0.72,
        darkAlpha: 0.88
    )
    static let ink = adaptiveColor("ink", light: 0x0F2A25, dark: 0xF1EDE4)
    static let subink = adaptiveColor("subink", light: 0x545B54, dark: 0xD0D6CE)
    static let muted = adaptiveColor("muted", light: 0x484F48, dark: 0xB7BEB7)
    static let appleSignInBackground = adaptiveColor("apple-sign-in-background", light: 0x000000, dark: 0xFFFFFF)
    static let appleSignInForeground = adaptiveColor("apple-sign-in-foreground", light: 0xFFFFFF, dark: 0x000000)
    static let accent = adaptiveColor("accent", light: 0x0F4A3D, dark: 0x77C9A8)
    static let accentDeep = adaptiveColor("accent-deep", light: 0x0A382E, dark: 0x173429)
    static let accentSoft = adaptiveColor("accent-soft", light: 0xC8D8C7, dark: 0x2A4136)
    static let onAccent = adaptiveColor("on-accent", light: 0xFFFFFF, dark: 0x14231B)
    static let inverseText = fixedColor(0xFFFFFF)
    static func whiteOverlay(alpha: CGFloat) -> Color { fixedColor(0xFFFFFF, alpha: alpha) }
    static func blackOverlay(alpha: CGFloat) -> Color { fixedColor(0x000000, alpha: alpha) }
    static let clay = adaptiveColor("clay", light: 0xC46F4A, dark: 0xEF9B78)
    static let coral = adaptiveColor("coral", light: 0xC46F4A, dark: 0xEF9B78)
    static let sage = adaptiveColor("sage", light: 0xC8D8C7, dark: 0x49634D)
    static let ochre = adaptiveColor("ochre", light: 0xD7B56D, dark: 0xE5C274)
    static let gold = ochre
    static let amber = adaptiveColor("amber", light: 0x875509, dark: 0xFFC85D)
    static let success = adaptiveColor("success", light: 0x28764B, dark: 0x66D391)
    static let teal = adaptiveColor("teal", light: 0x286F6B, dark: 0x76C9C2)
    static let line = adaptiveColor(
        "line",
        light: 0x000000,
        dark: 0xFFFFFF,
        lightAlpha: 0.07,
        darkAlpha: 0.10
    )
    static let rule = line

    // Static dark colours are reserved for image and room-cover surfaces with white type.
    static let coverForest = fixedColor(0x0C332B)
    static let coverForestLight = fixedColor(0x145447)
    static let coverTeal = fixedColor(0x153B3A)
    static let coverTealLight = fixedColor(0x24605A)
    static let coverSage = fixedColor(0x465B42)
    static let coverRosewood = fixedColor(0x3B2026)
    static let coverClay = fixedColor(0x6F342D)
    static let coverAmber = fixedColor(0x8A552E)
    static let voiceSessionBackground = fixedColor(0x0D241C)
    static let voiceSessionBackgroundDeep = fixedColor(0x050D0A)
    static let dusk = fixedColor(0x1E1328)
    static let rose = fixedColor(0x633047)
    static let orbHighlight = fixedColor(0xFFFFFF)
    static let coverHairline = fixedColor(0xFFFFFF, alpha: 0.05)
    static let coverBorder = fixedColor(0xFFFFFF, alpha: 0.15)
    static let coverAvatarRing = fixedColor(0xFFFFFF, alpha: 0.92)
    static let coverPill = fixedColor(0xFFFFFF, alpha: 0.12)
    static let coverTag = fixedColor(0xFFFFFF, alpha: 0.20)
    static let coverProgressTrack = fixedColor(0xFFFFFF, alpha: 0.20)
    static let coverProgressFill = fixedColor(0xFFFFFF, alpha: 0.85)
    static let coverScrim = fixedColor(0x000000, alpha: 0.70)
    static let photoScrim = fixedColor(0x000000, alpha: 0.55)

    static let googleBlue = fixedColor(0x4285F4)
    static let googleRed = fixedColor(0xEA4335)
    static let googleYellow = fixedColor(0xFBBC05)
    static let googleGreen = fixedColor(0x34A853)
    static let walletOrange = fixedColor(0xF28C28)
    static let solflareOrange = fixedColor(0xFA7415)

    private static let actionAccent = adaptiveColor("action-accent", light: 0x0F4A3D, dark: 0x77C9A8)
    private static let actionAccentEnd = adaptiveColor("action-accent-end", light: 0x12614B, dark: 0x61BB99)
    static let actionGradient = LinearGradient(
        colors: [actionAccent, actionAccentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let meetCardStart = adaptiveColor("meet-card-start", light: 0x0F4A3D, dark: 0x173429)
    private static let meetCardEnd = adaptiveColor("meet-card-end", light: 0x0A382E, dark: 0x224B3C)
    static let meetCardGradient = LinearGradient(
        colors: [meetCardStart, meetCardEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func roomGradient(_ index: Int = 0) -> LinearGradient {
        let palettes: [[Color]] = [
            [coverForest, coverForestLight, fixedColor(0x6D5834)],
            [coverTeal, coverTealLight, coverSage],
            [coverRosewood, coverClay, coverAmber],
            [dusk, fixedColor(0x392345), rose]
        ]
        return LinearGradient(
            colors: palettes[index % palettes.count],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func fixedColor(_ hex: UInt32, alpha: CGFloat = 1) -> Color {
        #if canImport(AppKit)
        return Color(nsColor: nsColor(hex, alpha: alpha))
        #elseif canImport(UIKit)
        return Color(uiColor: uiColor(hex, alpha: alpha))
        #else
        return .clear
        #endif
    }
}

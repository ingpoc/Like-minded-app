import SwiftUI

/// Cross-target type tokens for views shared by the iOS and macOS apps.
enum LikemindedTypography {
    static let body: Font = {
        #if os(macOS)
        Font.system(size: 14, weight: .regular, design: .default)
        #else
        Font.body
        #endif
    }()

    static let compact: Font = {
        #if os(macOS)
        Font.system(size: 14, weight: .regular, design: .default)
        #else
        Font.system(size: 13, weight: .regular, design: .default)
        #endif
    }()

    static let pageTitle: Font = {
        #if os(macOS)
        Font.system(size: 24, weight: .semibold, design: .serif)
        #else
        Font.system(.title2, design: .serif, weight: .semibold)
        #endif
    }()

    static let button: Font = {
        #if os(macOS)
        Font.system(size: 16, weight: .semibold, design: .default)
        #else
        Font.body.weight(.semibold)
        #endif
    }()

    static let caption: Font = {
        #if os(macOS)
        Font.system(size: 14, weight: .regular, design: .default)
        #else
        Font.callout
        #endif
    }()

    static let iconSmall: Font = {
        #if os(macOS)
        Font.system(size: 14, weight: .semibold, design: .default)
        #else
        Font.callout.weight(.semibold)
        #endif
    }()

    static let icon: Font = {
        #if os(macOS)
        Font.system(size: 18, weight: .semibold, design: .default)
        #else
        Font.body.weight(.semibold)
        #endif
    }()

    static let iconLarge: Font = {
        #if os(macOS)
        Font.system(size: 22, weight: .semibold, design: .default)
        #else
        Font.title3.weight(.semibold)
        #endif
    }()
}

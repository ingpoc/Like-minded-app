import SwiftUI

enum AuthBrandMark {
    case google
    case metamask
    case solflare

    @ViewBuilder
    var view: some View {
        switch self {
        case .google:
            GoogleGMark()
        case .metamask:
            MetaMaskMark()
        case .solflare:
            SolflareMark()
        }
    }
}

private struct GoogleGMark: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.0, to: 0.25)
                .stroke(LikemindedPalette.googleBlue, lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Circle()
                .trim(from: 0.25, to: 0.5)
                .stroke(LikemindedPalette.googleRed, lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Circle()
                .trim(from: 0.5, to: 0.75)
                .stroke(LikemindedPalette.googleYellow, lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Circle()
                .trim(from: 0.75, to: 1.0)
                .stroke(LikemindedPalette.googleGreen, lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Text("G")
                .font(LikemindedTypography.caption.weight(.bold))
                .foregroundStyle(LikemindedPalette.googleBlue)
                .offset(x: 1)
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

private struct MetaMaskMark: View {
    var body: some View {
        Image(systemName: "hexagon.fill")
            .font(LikemindedTypography.icon)
            .foregroundStyle(LikemindedPalette.walletOrange)
            .accessibilityHidden(true)
    }
}

private struct SolflareMark: View {
    var body: some View {
        Image(systemName: "sun.max.fill")
            .font(LikemindedTypography.icon)
            .foregroundStyle(LikemindedPalette.solflareOrange)
            .accessibilityHidden(true)
    }
}

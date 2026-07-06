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
                .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Circle()
                .trim(from: 0.25, to: 0.5)
                .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Circle()
                .trim(from: 0.5, to: 0.75)
                .stroke(Color(red: 0.98, green: 0.74, blue: 0.02), lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Circle()
                .trim(from: 0.75, to: 1.0)
                .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), lineWidth: 3)
                .rotationEffect(.degrees(-45))
            Text("G")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                .offset(x: 1)
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}

private struct MetaMaskMark: View {
    var body: some View {
        Image(systemName: "hexagon.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.17))
            .accessibilityHidden(true)
    }
}

private struct SolflareMark: View {
    var body: some View {
        Image(systemName: "sun.max.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color(red: 0.98, green: 0.45, blue: 0.09))
            .accessibilityHidden(true)
    }
}

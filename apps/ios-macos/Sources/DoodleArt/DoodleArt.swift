import SwiftUI

/// Thematic cover art for circles, communities, events, and default portraits.
/// Each asset is scene-relevant to its id and contains no baked-in lettering —
/// UI typography is always drawn by SwiftUI over a scrim.
enum DoodleArt {
    static let portraitDefault = "DoodlePortraitDefault"
    static let portraitMale = "DoodlePortraitDefault"
    static let portraitFemale = "DoodlePortraitFemale"

    static func portrait(for gender: Gender?) -> String {
        switch gender {
        case .female:
            return portraitFemale
        case .male:
            return portraitMale
        default:
            return portraitDefault
        }
    }

    static func portrait(forGenderString gender: String?) -> String {
        switch gender?.lowercased() {
        case "female":
            return portraitFemale
        case "male":
            return portraitMale
        default:
            return portraitDefault
        }
    }
    static let eventJazzListening = "EventJazzListening"
    static let eventMeetup = "DoodleEventMeetup"
    static let eventJam = "DoodleEventJam"

    private static let circleAssets: [String: String] = [
        "reflective-builders": "DoodleCircleReflectiveBuilders",
        "gentle-romantics": "DoodleCircleGentleRomantics",
        "longform-thinkers": "DoodleCircleLongformThinkers",
        "bold-explorers": "DoodleCircleBoldExplorers",
        "grounded-nurturers": "DoodleCircleGroundedNurturers",
    ]

    private static let communityAssets: [String: String] = [
        "ai-builders": "DoodleCommAIBuilders",
        "longform-reading": "DoodleCommLongformReading",
        "design-craft": "DoodleCommDesignCraft",
        "startups": "DoodleCommStartups",
        "mindful-living": "DoodleCommMindfulLiving",
        "creative-writing": "DoodleCommCreativeWriting",
        "jazz-music": "EventJazzListening",
        "trekking-outdoors": "DoodleCommTrekkingOutdoors",
    ]

    static func circle(_ circleId: String) -> String {
        circleAssets[circleId] ?? "DoodleCircleReflectiveBuilders"
    }

    static func community(_ communityId: String) -> String {
        communityAssets[communityId] ?? "DoodleCommMindfulLiving"
    }

    static func eventCover(eventType: String) -> String {
        switch eventType {
        case "Listening Session": return eventJazzListening
        case "Jam Session": return eventJam
        default: return eventMeetup
        }
    }
}

/// Scrim for overlay copy — mockups place white serif titles on a dark lower band.
enum DoodleScrimStyle {
    case none
    /// Title + meta anchored at the bottom (available circle / community browse cards).
    case bottomBand
    /// Multi-line hero copy over the lower-left (featured circle, detail headers).
    case heroOverlay
}

struct DoodleCover: View {
    let assetName: String
    var height: CGFloat = 140
    var cornerRadius: CGFloat = 0
    var scrimStyle: DoodleScrimStyle = .bottomBand

    /// Convenience for event previews where title sits below the art (create-event mockup).
    init(assetName: String, height: CGFloat = 140, cornerRadius: CGFloat = 0, scrim: Bool) {
        self.assetName = assetName
        self.height = height
        self.cornerRadius = cornerRadius
        self.scrimStyle = scrim ? .bottomBand : .none
    }

    init(assetName: String, height: CGFloat = 140, cornerRadius: CGFloat = 0, scrimStyle: DoodleScrimStyle = .bottomBand) {
        self.assetName = assetName
        self.height = height
        self.cornerRadius = cornerRadius
        self.scrimStyle = scrimStyle
    }

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .top)
                .clipped()
            switch scrimStyle {
            case .none:
                EmptyView()
            case .bottomBand:
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.08), location: 0.35),
                        .init(color: .black.opacity(0.55), location: 0.72),
                        .init(color: .black.opacity(0.82), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .heroOverlay:
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black.opacity(0.12), location: 0.32),
                            .init(color: .black.opacity(0.58), location: 0.68),
                            .init(color: .black.opacity(0.86), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    LinearGradient(
                        colors: [.black.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: UnitPoint(x: 0.7, y: 0.55)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct DoodleOverlayTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func doodleOverlayText() -> some View {
        modifier(DoodleOverlayTextStyle())
    }
}

struct DoodlePortrait: View {
    let assetName: String
    var size: CGFloat = 40

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
    }
}

/// Circular crop of the same circle cover art used in circle detail (`DoodleCover`).
struct DoodleCircleMark: View {
    let circleId: String
    var size: CGFloat = 64

    var body: some View {
        Image(DoodleArt.circle(circleId))
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

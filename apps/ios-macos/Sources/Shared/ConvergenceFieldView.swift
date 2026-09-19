import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// GPU isoline background shared by macOS welcome and iOS auth gate.
/// Shader: `Sources/Shared/ConvergenceField.metal`
struct ConvergenceFieldView: View {
    var background: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.displayScale) private var displayScale
    #endif

    private let startDate = Date()

    private var resolvedDisplayScale: Float {
        #if os(iOS)
        Float(displayScale)
        #else
        Float(NSScreen.main?.backingScaleFactor ?? 2)
        #endif
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startDate)
            let fieldTime = 0.4 + elapsed * 0.05
            Rectangle()
                .fill(background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .visualEffect { [resolvedDisplayScale] content, proxy in
                    content.colorEffect(
                        ShaderLibrary.convergenceField(
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(Float(fieldTime)),
                            .float(resolvedDisplayScale)
                        )
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Pin-centered radial convergence for Meet hero map panels.
/// Shader: `meetVenueConvergenceField` in `ConvergenceField.metal`
struct MeetVenueConvergenceFieldView: View {
    var background: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.displayScale) private var displayScale
    #endif

    private let startDate = Date()

    private var resolvedDisplayScale: Float {
        #if os(iOS)
        Float(displayScale)
        #else
        Float(NSScreen.main?.backingScaleFactor ?? 2)
        #endif
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startDate)
            let fieldTime = 0.4 + elapsed * 0.04
            Rectangle()
                .fill(background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .visualEffect { [resolvedDisplayScale] content, proxy in
                    content.colorEffect(
                        ShaderLibrary.meetVenueConvergenceField(
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(Float(fieldTime)),
                            .float(resolvedDisplayScale)
                        )
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Circles room-orb fingerprint — MorphingContours grammar (not Meet sink-flow, not auth topo).
struct CirclesRoomOrbFieldView: View {
    var background: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.displayScale) private var displayScale
    #endif

    private let startDate = Date()

    private var resolvedDisplayScale: Float {
        #if os(iOS)
        Float(displayScale)
        #else
        Float(NSScreen.main?.backingScaleFactor ?? 2)
        #endif
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startDate)
            let fieldTime = 0.4 + elapsed * 0.03
            Rectangle()
                .fill(background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .visualEffect { [resolvedDisplayScale] content, proxy in
                    content.colorEffect(
                        ShaderLibrary.circlesRoomOrbField(
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(Float(fieldTime)),
                            .float(resolvedDisplayScale)
                        )
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Circles placement atmosphere — soft sand-ripple field (not auth welcome field).
struct CirclesPlacementFieldView: View {
    var background: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.displayScale) private var displayScale
    #endif

    private let startDate = Date()

    private var resolvedDisplayScale: Float {
        #if os(iOS)
        Float(displayScale)
        #else
        Float(NSScreen.main?.backingScaleFactor ?? 2)
        #endif
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startDate)
            let fieldTime = 0.4 + elapsed * 0.035
            Rectangle()
                .fill(background)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .visualEffect { [resolvedDisplayScale] content, proxy in
                    content.colorEffect(
                        ShaderLibrary.circlesPlacementField(
                            .float2(Float(proxy.size.width), Float(proxy.size.height)),
                            .float(Float(fieldTime)),
                            .float(resolvedDisplayScale)
                        )
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

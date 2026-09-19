import SwiftUI

/// Meet venue field — **direct port** of thewayofcode **ch.16 MorphingContours**.
///
/// Source (verbatim algorithm):
/// https://github.com/generativelabs/the-way-of-code/blob/main/chapters/16/visualization.jsx
///
/// Layout-only adaptations for Meet:
/// - center on venue pin `focus` instead of canvas midpoint
/// - soft left dissolve under copy
/// - expansive scale so rings fill more of the card
///
/// Plate: `mockups/macos/concepts/mockup-meet-overview-convergence.png`
struct MeetVenueStreamlineFieldView: View {
    /// thewayofcode cream `#F0EEE6`
    var background: Color = Color(red: 240.0 / 255.0, green: 238.0 / 255.0, blue: 230.0 / 255.0)
    /// Pin focus — must match SwiftUI pin (`MacMeetOverviewConceptView`).
    var focus: UnitPoint = UnitPoint(x: 0.78, y: 0.48)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            // JSX: time += 0.001 per frame (~60fps) → ~0.06/sec
            let t = reduceMotion ? 0.35 : context.date.timeIntervalSince(startDate) * 0.06
            Canvas { ctx, size in
                drawMorphingContours(context: ctx, size: size, time: t)
            }
            .background(background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// Literal ch.16 MorphingContours draw loop (expansive Meet scale).
    private func drawMorphingContours(context: GraphicsContext, size: CGSize, time: Double) {
        let width = size.width
        let height = size.height
        guard width > 8, height > 8 else { return }

        // --- Parameters (from visualization.jsx) ---
        // Expansive Meet layout: same ch.16 math, larger scale + more outer rings
        // so the field fills the right ~⅔ of the card (concept plate).
        let numShapes = 3
        let contoursPerShape = 42
        let points = 120
        // Their canvas is 550×550 with scaleFactor 1.5. Push larger so rings reach card edges.
        let scaleFactor = 2.35 * (min(width, height) / 400.0)
        let contourStep = 3.0 // ch.16 original

        // Project colors: rgba(50, 50, 50, 0.4), lineWidth 0.8
        let ink = Color(red: 50.0 / 255.0, green: 50.0 / 255.0, blue: 50.0 / 255.0)
        let stroke = StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round)

        let centerX = focus.x * width
        let centerY = focus.y * height

        for shapeIndex in 0..<numShapes {
            let shapePhase = time + Double(shapeIndex) * .pi * 2 / Double(numShapes)

            // Slightly wider shape drift so forms spread across the card.
            let offsetX = sin(shapePhase * 0.2) * 55 * scaleFactor
            let offsetY = cos(shapePhase * 0.3) * 48 * scaleFactor

            for contour in 0..<contoursPerShape {
                let scale = (30 + Double(contour) * contourStep) * scaleFactor

                let contourOffsetX = sin(Double(contour) * 0.2 + shapePhase) * 10 * scaleFactor
                let contourOffsetY = cos(Double(contour) * 0.2 + shapePhase) * 10 * scaleFactor

                var path = Path()
                var started = false

                for i in 0...points {
                    let angle = (Double(i) / Double(points)) * .pi * 2

                    var radius = scale
                    radius += 15 * sin(angle * 3 + shapePhase * 2) * scaleFactor
                    radius += 10 * cos(angle * 5 - shapePhase) * scaleFactor
                    radius += 5 * sin(angle * 8 + Double(contour) * 0.1) * scaleFactor

                    let x = centerX + offsetX + contourOffsetX + cos(angle) * radius
                    let y = centerY + offsetY + contourOffsetY + sin(angle) * radius

                    // Meet layout only: dissolve under left copy (softer — field reaches further).
                    if x < width * 0.04 {
                        started = false
                        continue
                    }

                    let pt = CGPoint(x: x, y: y)
                    if !started {
                        path.move(to: pt)
                        started = true
                    } else {
                        path.addLine(to: pt)
                    }
                }
                if started {
                    path.closeSubpath()
                }

                context.stroke(path, with: .color(ink.opacity(0.4)), style: stroke)
            }
        }
    }
}

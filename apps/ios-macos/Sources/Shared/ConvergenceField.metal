#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Convergence field — thewayofcode.com-inspired topographic contour art shared
// by the iOS auth gate and macOS welcome screen. Per-pixel isoline rendering of a
// domain-warped fBm height field with gentle right-side (or lower-right portrait) bias.

namespace {

inline float hash2(int x, int y) {
    uint n = uint(x * 374761393 + y * 668265263);
    n = (n ^ (n >> 13)) * 1274126177u;
    n = n ^ (n >> 16);
    return float(n) / float(0xFFFFFFFFu);
}

inline float valueNoise(float x, float y) {
    float x0 = floor(x);
    float y0 = floor(y);
    float fx = x - x0;
    float fy = y - y0;
    float ux = fx * fx * (3.0 - 2.0 * fx);
    float uy = fy * fy * (3.0 - 2.0 * fy);
    int ix = int(x0);
    int iy = int(y0);
    float a = hash2(ix, iy);
    float b = hash2(ix + 1, iy);
    float c = hash2(ix, iy + 1);
    float d = hash2(ix + 1, iy + 1);
    float ab = a + (b - a) * ux;
    float cd = c + (d - c) * ux;
    return ab + (cd - ab) * uy;
}

inline float fbm3(float x, float y) {
    float sum = 0.5 * valueNoise(x, y);
    sum += 0.25 * valueNoise(x * 2.03, y * 2.03);
    sum += 0.125 * valueNoise(x * 4.1209, y * 4.1209);
    return sum / 0.875;
}

inline float fbm4(float x, float y) {
    float sum = 0.5 * valueNoise(x, y);
    sum += 0.25 * valueNoise(x * 2.03, y * 2.03);
    sum += 0.125 * valueNoise(x * 4.1209, y * 4.1209);
    sum += 0.0625 * valueNoise(x * 8.3654, y * 8.3654);
    return sum / 0.9375;
}

// Height field tuned against mockups/macos/auth-login-convergence.png and
// mockups/ios/auth-login-convergence.png.
// nx/ny are normalized panel coordinates.
inline float heightField(float nx, float ny, float aspect, float time) {
    // Anisotropic base coords: features stretched vertically so contours
    // flow top-to-bottom like the concept plate.
    float px = nx * aspect * 2.85 + time * 0.15;
    float py = ny * 1.42;

    // Domain warp for fingerprint/topo flow — stronger warp = less regular grid.
    float wx = fbm3(px * 0.9 + 1.3, py * 0.9 - 0.8) - 0.5;
    float wy = fbm3(px * 0.9 - 2.1, py * 0.9 + 3.4) - 0.5;
    px += 1.25 * wx;
    py += 1.25 * wy;

    float h = fbm4(px, py);

    // Portrait: lower-right gravity. Landscape: right-half bias.
    if (aspect < 0.85) {
        h += 0.06 * smoothstep(0.42, 0.95, nx) * smoothstep(0.32, 0.92, ny);
    } else {
        h += 0.06 * smoothstep(0.55, 0.92, nx);
    }

    return h;
}

} // namespace

[[ stitchable ]] half4 convergenceField(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float displayScale
) {
    const float levels = 76.0;

    float aspect = size.x / size.y;
    float nx = position.x / size.x;
    float ny = position.y / size.y;

    float h = heightField(nx, ny, aspect, time);

    // Distance (in device pixels) to the nearest contour line. fwidth()
    // gives the hardware screen-space derivative — no extra field samples.
    float g = h * levels;
    float frac = g - floor(g);
    float distToLine = 0.5 - abs(frac - 0.5);
    float dgPerPx = max(fwidth(g), 1e-6);
    float px = distToLine / dgPerPx;

    // Hairline: ~0.8 device-pixel half-width — concept plate reads darker.
    float halfWidth = 0.40 * displayScale;
    float ink = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, px);

    // Any sub-pixel contour stack becomes a moiré slab — taper steep slopes.
    float lineSpacingPx = 1.0 / dgPerPx;
    float cliffGuard = mix(0.22, 1.0, smoothstep(0.12, 0.58, lineSpacingPx));
    float steep = smoothstep(0.65, 1.25, dgPerPx);
    ink *= mix(1.0, cliffGuard, steep);

    float alpha = 0.85 * ink;
    alpha *= mix(1.0, 0.50, smoothstep(0.65, 1.25, dgPerPx));

    float x = position.x;
    float y = position.y;
    float panelW = size.x;
    float panelH = size.y;

    if (aspect < 0.85) {
        // iPhone portrait — dissolve under full-width copy column; field lower-right.
        alpha *= smoothstep(0.0, 0.72, nx);
        alpha *= mix(0.50, 1.0, smoothstep(panelH * 0.22, panelH * 0.42, y));
    } else {
        alpha *= smoothstep(300.0, 460.0, x);
    }
    alpha *= mix(0.55, 1.0, smoothstep(panelW - 40.0, panelW - 4.0, x));
    alpha *= mix(0.58, 1.0, smoothstep(0.0, 40.0, y));
    alpha *= mix(0.52, 1.0, smoothstep(panelH - 40.0, panelH - 4.0, y));

    half a = half(alpha);
    const half3 inkColor = half3(0.045h, 0.125h, 0.105h);
    return half4(inkColor * a, a);
}

// Meet venue map — DISTINCT from auth `convergenceField` (fBm topo isolines).
// Theme: gathering toward a place. Concept plate (ink crop):
//   continuous organic rings that PACK into the pin (denser near focus),
//   fill the right ~⅔ of ONE card, dissolve under left copy.
// Grammar: soft sink φ = (r+ε)^α — packs toward pin WITHOUT log singularity
// (log(r) + cliff guard produced the bright white hole).
// Plate: mockups/macos/concepts/mockup-meet-overview-convergence.png
[[ stitchable ]] half4 meetVenueConvergenceField(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float displayScale
) {
    const float levels = 48.0;

    float aspect = size.x / size.y;
    float nx = position.x / size.x;
    float ny = position.y / size.y;

    // Pin focus — must match SwiftUI pin (right third of card).
    const float cx = 0.82;
    const float cy = 0.50;
    float sx = (nx - cx) * aspect;
    float sy = ny - cy;
    float r = sqrt(sx * sx + sy * sy);
    float angle = atan2(sy, sx);

    // Organic radius warp — wavy continuous rings.
    float phase = time * 0.08;
    float warp = 0.0;
    warp += 0.050 * sin(angle * 3.0 + phase);
    warp += 0.030 * cos(angle * 5.0 - phase * 0.7);
    warp += 0.018 * sin(angle * 7.0 + phase * 0.5);
    float n = fbm3(angle * 0.7 + 0.2, r * 1.8 - phase) - 0.5;
    warp += 0.018 * n;

    float rw = max(r + warp, 0.0);

    // Soft sink — packs toward pin, finite gradient (no white hole).
    const float eps = 0.045;
    float h = pow(rw + eps, 0.52);

    float g = h * levels;
    float frac = g - floor(g);
    float distToLine = 0.5 - abs(frac - 0.5);
    float dgPerPx = max(fwidth(g), 1e-6);
    float linePx = distToLine / dgPerPx;

    float halfWidth = 0.38 * displayScale;
    float ink = 1.0 - smoothstep(halfWidth - 0.45, halfWidth + 0.45, linePx);

    // Very mild cliff — keep packed region near the pin.
    float steep = smoothstep(1.8, 3.2, dgPerPx);
    ink *= mix(1.0, 0.70, steep);

    float alpha = 0.32 * ink;

    // Tiny readability dip only — keep lines under the pin.
    alpha *= mix(0.75, 1.0, smoothstep(0.0, 0.025, r));

    // Dissolve under left copy — field is the right ~⅔.
    alpha *= smoothstep(0.14, 0.44, nx);

    alpha *= mix(0.75, 1.0, smoothstep(0.0, 0.02, nx) * smoothstep(1.0, 0.98, nx));
    alpha *= mix(0.75, 1.0, smoothstep(0.0, 0.03, ny) * smoothstep(1.0, 0.97, ny));

    half a = half(alpha);
    const half3 inkColor = half3(0.34h, 0.32h, 0.29h);
    return half4(inkColor * a, a);
}

// Circles room orbs — MorphingContours fingerprint (thewayofcode.com).
// Theme: each room has its own quiet identity. Soft, contained — never loud.
// Distinct from auth fBm topo and Meet sink-flow. Clipped to a circle in SwiftUI.
[[ stitchable ]] half4 circlesRoomOrbField(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float displayScale
) {
    const float levels = 28.0;

    float aspect = size.x / size.y;
    float nx = position.x / size.x;
    float ny = position.y / size.y;

    const float cx = 0.50;
    const float cy = 0.50;
    float dx = (nx - cx) * aspect;
    float dy = ny - cy;
    float r = sqrt(dx * dx + dy * dy);
    float angle = atan2(dy, dx);

    float phase = time * 0.15;
    float radiusWarp = 0.0;
    radiusWarp += 0.055 * sin(angle * 3.0 + phase * 2.0);
    radiusWarp += 0.032 * cos(angle * 5.0 - phase);
    radiusWarp += 0.018 * sin(angle * 8.0 + phase * 0.4);

    float h = (r + radiusWarp) * 1.25;

    float g = h * levels;
    float frac = g - floor(g);
    float distToLine = 0.5 - abs(frac - 0.5);
    float dgPerPx = max(fwidth(g), 1e-6);
    float linePx = distToLine / dgPerPx;

    float halfWidth = 0.36 * displayScale;
    float ink = 1.0 - smoothstep(halfWidth - 0.45, halfWidth + 0.45, linePx);

    float alpha = 0.28 * ink;
    alpha *= mix(0.0, 1.0, smoothstep(0.52, 0.46, r)); // soft circular mask

    half a = half(alpha);
    const half3 inkColor = half3(0.40h, 0.38h, 0.34h);
    return half4(inkColor * a, a);
}

// Circles placement atmosphere — soft sand-ripple behind the plate.
// Theme: quiet placement gravity. Whisper only — copy + cards own the screen.
// Distinct from auth (hero topo) and Meet (venue sink-flow).
[[ stitchable ]] half4 circlesPlacementField(
    float2 position,
    half4 currentColor,
    float2 size,
    float time,
    float displayScale
) {
    const float levels = 44.0;

    float aspect = size.x / size.y;
    float nx = position.x / size.x;
    float ny = position.y / size.y;

    // Horizontal sand ripples with gentle right-side gather (placement gravity).
    float px = nx * aspect * 2.0 + time * 0.06;
    float py = ny * 2.4;
    float wx = fbm3(px * 0.65 + 0.4, py * 0.65 - 1.1) - 0.5;
    float wy = fbm3(px * 0.65 - 1.6, py * 0.65 + 2.2) - 0.5;
    px += 0.85 * wx;
    py += 0.85 * wy;
    float h = fbm4(px, py);
    h += 0.04 * smoothstep(0.45, 0.95, nx) * smoothstep(0.20, 0.85, ny);

    float g = h * levels;
    float frac = g - floor(g);
    float distToLine = 0.5 - abs(frac - 0.5);
    float dgPerPx = max(fwidth(g), 1e-6);
    float linePx = distToLine / dgPerPx;

    float halfWidth = 0.30 * displayScale;
    float ink = 1.0 - smoothstep(halfWidth - 0.45, halfWidth + 0.45, linePx);

    float lineSpacingPx = 1.0 / dgPerPx;
    float cliffGuard = mix(0.35, 1.0, smoothstep(0.10, 0.50, lineSpacingPx));
    float steep = smoothstep(0.70, 1.40, dgPerPx);
    ink *= mix(1.0, cliffGuard, steep);

    // Atmosphere only — must not compete with "Your room." or room cards.
    float alpha = 0.18 * ink;
    alpha *= mix(0.10, 1.0, smoothstep(0.10, 0.48, nx));
    alpha *= mix(0.45, 1.0, smoothstep(0.0, 0.22, ny));

    half a = half(alpha);
    const half3 inkColor = half3(0.45h, 0.42h, 0.36h);
    return half4(inkColor * a, a);
}

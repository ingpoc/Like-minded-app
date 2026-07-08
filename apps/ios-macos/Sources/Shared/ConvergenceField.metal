#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Convergence field — thewayofcode.com-inspired topographic contour art shared
// by the iOS and macOS welcome screens. Per-pixel isoline rendering of a
// domain-warped fBm height field: contours flow top-to-bottom (anisotropic
// features), and a tanh ridge along a meandering curve bunches them into the
// dark convergence vein of the concept plate. Runs entirely on the GPU.

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

// Height field tuned against mockups/macos/concepts/mockup-auth-login-convergence.png
// and thewayofcode.com line-field grammar (dense hairlines, right-side gravity).
// nx/ny are normalized panel coordinates.
inline float heightField(float nx, float ny, float aspect, float time) {
    // Anisotropic base coords: features stretched vertically so contours
    // flow top-to-bottom like the concept plate.
    float px = nx * aspect * 2.85 + time * 0.15;
    float py = ny * 1.42;

    // Domain warp for fingerprint/topo flow — stronger warp = less regular grid.
    float wx = fbm3(px * 0.9 + 1.3, py * 0.9 - 0.8) - 0.5;
    float wy = fbm3(px * 0.9 - 2.1, py * 0.9 + 3.4) - 0.5;
    px += 1.35 * wx;
    py += 1.35 * wy;

    float h = fbm4(px, py);

    // Convergence ridge: tanh cliff along a meandering near-vertical curve
    // bunches contours into the dark vein (right-half gravity of the plate).
    float veinDrift = fbm3(ny * 1.55 + 12.7 + time * 0.2, 4.2) - 0.5;
    float vx = 0.70 + 0.16 * veinDrift;
    float sd = nx - vx;
    float veinY = exp(-pow((ny - 0.48) / 0.88, 2.0));
    h += 0.50 * veinY * tanh(sd / 0.030) * exp(-pow(sd / 0.20, 2.0));

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
    const float levels = 72.0;

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

    // Hairline: ~0.64 device-pixel half-width with a one-pixel AA feather.
    float halfWidth = 0.32 * displayScale;
    float ink = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, px);

    // Peak alpha raised vs early pass — concept + thewayofcode read denser.
    float alpha = 0.56 * ink;

    // Long, breathing fades. Left dissolves hard under the content column so
    // gravitas sits on the right; window rims keep a faint floor (not zero).
    alpha *= smoothstep(0.40, 0.68, nx);
    alpha *= mix(0.22, 1.0, smoothstep(1.0, 0.76, nx));
    alpha *= mix(0.24, 1.0, smoothstep(0.0, 0.22, ny));
    alpha *= mix(0.20, 1.0, smoothstep(1.0, 0.78, ny));

    half a = half(alpha);
    const half3 inkColor = half3(0.059h, 0.165h, 0.145h);
    return half4(inkColor * a, a);
}

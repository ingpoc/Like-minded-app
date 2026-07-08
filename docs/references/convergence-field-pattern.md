# Convergence field pattern — build learnings

How the animated topographic contour art on the macOS welcome screen
(`MacConvergenceField`) was built, what failed along the way, and how to
reproduce it (the iOS welcome screen will reuse the same shader).

- Shader (shared, GPU): `apps/ios-macos/Sources/Shared/ConvergenceField.metal`
- macOS host view: `apps/ios-macos/Sources/LikemindedMac/MacDesignSystem.swift` → `MacConvergenceField`
- Concept plate: `mockups/macos/concepts/mockup-auth-login-convergence.png`
- Visual grammar source: [thewayofcode.com](https://www.thewayofcode.com/) — calm generative line fields, cream paper, near-black-green ink

## 1. The pattern in one paragraph

Render **isolines (contour lines) of a procedural height field, per pixel, on
the GPU**. The height field is domain-warped fractal noise (fBm) with
vertically stretched features so contours flow top-to-bottom, plus a `tanh`
cliff along a meandering near-vertical curve that bunches contours into one
dark "convergence vein". Animate by sliding the noise domain very slowly over
time. Everything else is alpha shaping: hairline anti-aliasing and long edge
fades.

## 2. Architecture: why a Metal shader, not Canvas/CGContext

We first shipped a CPU renderer (150 polylines drawn into a `CGContext`,
re-rendered off-main and swapped ~2.5 fps). It worked but:

- ~9–16% of one core even after optimizations (coarser steps, lower fps).
- Fluidity capped by how often you can afford to re-render a bitmap.
- Debug builds are brutally slower for tight Swift math loops (fBm per
  vertex); profiling in debug misleads you.

The replacement is a SwiftUI `colorEffect` with a `[[ stitchable ]]` Metal
function. The GPU evaluates the whole field per pixel per frame; frame rate
and line density become nearly free. Remaining CPU cost (~10% in debug on a
120 Hz machine) is SwiftUI's `TimelineView` re-evaluation overhead, not
rendering — it shrinks with lower `minimumInterval` and in release builds.

**Learning:** for full-screen generative art, go straight to a shader.
CPU-side generative rendering is only worth it for static plates.

## 3. Height field recipe (`heightField` in the shader)

Layers, in order:

1. **Anisotropic base coordinates** — stretch features vertically so contours
   read as top-to-bottom flow, and scale x by the view aspect so the pattern
   doesn't distort with window size:
   `px = nx * aspect * 2.85 + time * 0.15;  py = ny * 1.42;`
   The x:y frequency ratio (~2.85 : 1.42) is what makes it "flow" instead of
   looking like a weather map.
2. **Domain warp** — sample fBm twice (offset seeds) and displace the
   coordinates before the final noise lookup. This turns blobby noise into
   fingerprint/topographic meanders: `px += 1.35 * wx; py += 1.35 * wy;`
   Warp strength ~1.35 is the character knob: lower = boring stripes,
   higher = turbulent scribble.
3. **fBm height** — 4 octaves of value noise (lacunarity ~2.03, gain 0.5).
   Use non-integer lacunarity/frequencies (2.03, 4.1209…) to avoid grid
   artifacts from axis-aligned value noise.
4. **Convergence vein** — add a `tanh` step along a meandering curve:
   - Curve x-position: `vx = 0.70 + 0.16 * fbm(ny…)` — 1-D noise over `ny`
     makes the vein wander; sitting near ~0.70 keeps gravity in the right half.
   - `h += 0.50 * veinY * tanh(sd / 0.030) * exp(-(sd / 0.20)^2)` where
     `sd = nx - vx`. The `tanh` cliff compresses many contour levels into a
     narrow band (= dense dark vein); the Gaussian envelope localizes it; the
     `veinY` vertical envelope fades it near top/bottom.

**Learning:** a "vein" is not drawn — it *emerges* from bunched isolines
wherever the field has a steep cliff. Steepness (`/ 0.030`) controls vein
darkness/density; amplitude (`0.50`) controls how many lines get pulled in.

## 4. Isoline rendering with `fwidth` (the key GPU trick)

```metal
float g = h * levels;                 // levels = 72 contour bands
float frac = g - floor(g);
float distToLine = 0.5 - abs(frac - 0.5);   // distance in "level" units
float dgPerPx = max(fwidth(g), 1e-6);       // level units per device pixel
float px = distToLine / dgPerPx;            // distance in device pixels
float ink = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, px);
```

- `fract` distance to the nearest integer level gives contour bands for free.
- `fwidth(g)` (hardware screen-space derivative) converts that distance to
  **device pixels**, giving constant-width hairlines regardless of local field
  slope — flat areas and cliff areas get the same ~0.64 px line. This is the
  standard anti-aliased isoline idiom; do **not** approximate the gradient by
  re-sampling the field 3× per pixel (we tried: slower and moiré-prone).
- `fwidth` **is** available in SwiftUI stitchable shaders (macOS 15 / iOS 18
  targets here) despite not being obvious from docs.
- Hairline width: `halfWidth = 0.32 * displayScale` with a ±0.5 px smoothstep
  feather. Pass `displayScale` in as a uniform — `position`/`size` in
  `colorEffect` are in view points scaled by the layer, and guessing the scale
  gives fat or shimmering lines.
- Where the field is steep (the vein), `dgPerPx` grows until lines are closer
  than a pixel; the AA math then naturally cross-fades them into a soft gray
  mass instead of a solid black slab. No special-casing needed.

## 5. Ink and edge fades (took three user rounds to get right)

- Ink color = palette near-black green `#0F2A25`; peak line alpha **0.56** —
  dense enough to match thewayofcode / concept plate, still soft behind copy
  because the left fade clears the content column.
- Return **premultiplied** color: `half4(inkColor * a, a)`.
- Edge behavior that finally matched the concept plate:

```metal
alpha *= smoothstep(0.40, 0.68, nx);                  // long dissolve toward content column
alpha *= mix(0.22, 1.0, smoothstep(1.0, 0.76, nx));   // right rim
alpha *= mix(0.24, 1.0, smoothstep(0.0, 0.22, ny));   // top rim
alpha *= mix(0.20, 1.0, smoothstep(1.0, 0.78, ny));   // bottom rim
```

**Learnings, in feedback order:**

1. No fade at all reads as "abruptly cut" lines (first complaint).
2. A *short* fade-to-zero (5% ramp) reads as a hard stop with a blank margin
   before the edge — worse than none, because faint lines drop below visibility
   well before the math reaches zero.
3. Early GPU pass at peak alpha **0.42** still read washed vs concept /
   thewayofcode — raise density (levels, alpha, vein) and push left-fade so
   gravitas sits on the right half.
4. What matches the plate: **long ramps that bottom out at a faint floor
   (`mix(0.20…0.24, 1.0, …)`) instead of zero**, so hairlines still kiss the
   window edge, just very quietly. Fade to zero only on the side that meets
   content (left), never on sides that meet the window rim.

## 6. Animation (subtle — social app, not a game)

Host view pattern (macOS; iOS identical with `UIScreen` scale):

```swift
TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
    let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(startDate)
    let fieldTime = 0.4 + elapsed * 0.05      // a feature crosses in ~2 min
    Rectangle()
        .fill(MacPalette.background)
        .visualEffect { [displayScale] content, proxy in
            content.colorEffect(ShaderLibrary.convergenceField(
                .float2(Float(proxy.size.width), Float(proxy.size.height)),
                .float(Float(fieldTime)),
                .float(displayScale)))
        }
}
.accessibilityHidden(true)
.allowsHitTesting(false)
```

- **Drift rate is the subtlety knob.** 0.3 units/s read as a flowing river
  (rejected twice); **0.05 units/s** finally read as "breathing". Time enters
  the field in two places: base-coordinate slide (`time * 0.15`) and vein
  wander (`time * 0.2`).
- Because motion is continuous in the shader, 20 fps is indistinguishable
  from 120 fps at this drift rate — cap `minimumInterval` low to save CPU.
- Use `visualEffect` + `proxy.size` for the size uniform, **not**
  `GeometryReader` (layout churn every timeline tick).
- Honor `accessibilityReduceMotion` by pausing the timeline and freezing
  `fieldTime`.

## 7. Tuning workflow that worked

1. **Prototype outside the app.** A throwaway Swift CLI (`/tmp/field_proto`)
   rendering the field to a PNG made parameter rounds seconds instead of
   full app builds. Tune structure there; port numbers to MSL last.
2. **Screenshot loop for parity:** build → `./script/verify_macos_screens.sh
   welcome` → read `output/validation/macos-screens/welcome.png` next to the
   concept plate. Crop strips (`sips -c … --cropOffset …`) to inspect edge
   fades at pixel level — full-frame eyeballing hides rim problems.
3. **Measure CPU on an optimized build** (`SWIFT_OPTIMIZATION_LEVEL=-O`);
   debug numbers for per-pixel/per-vertex math are 5–10× off.
4. Ledger: status lives in `validation/screens/auth.json` (`visual_parity`
   notes name the technique, capture, and intentional deltas vs the plate).

## 8. Pitfalls checklist

- Integer lacunarity in value-noise fBm → visible grid alignment. Use 2.03+.
- Vein via drawn strokes + sway (CPU version) → "twisted rope" braiding where
  lines cross; the isoline/tanh formulation cannot braid by construction.
- `halfWidth` not scaled by `displayScale` → fat lines on Retina, moiré.
- Fading line alpha to zero at window rims → perceived blank margin (see §5).
- `GeometryReader` inside `TimelineView` → layout work every frame.
- Forgetting `paused:` + frozen time for reduce-motion.
- Piping long-running capture scripts through `tail` → hung locks; redirect
  to a log file instead.

## 9. iOS port checklist

The `.metal` file already lives in `Sources/Shared` and compiles into both
targets (min iOS 18 for `colorEffect`/`visualEffect`).

1. Create an iOS twin of `MacConvergenceField` using the §6 pattern with
   `Float(UIScreen.main.scale)` (or `@Environment(\.displayScale)`).
2. Portrait phone aspect: the `aspect` uniform already keeps feature shape,
   but re-check the vein x-position (`0.62`) and the left content fade
   (`0.36–0.62`) against the iOS layout — on a narrow screen the field may
   sit behind content instead of beside it.
3. Re-run the fade tuning against the iOS mockup; rim floors (§5) are
   device-size dependent to the eye, ramps scale automatically.

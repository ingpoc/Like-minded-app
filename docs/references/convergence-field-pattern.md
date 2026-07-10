# Convergence field pattern — build learnings

GPU topographic isolines on cream for **macOS welcome** and **iOS auth gate**.
Shared shader + `ConvergenceFieldView`; platform layouts differ (§6, §9).

- Shader: `apps/ios-macos/Sources/Shared/ConvergenceField.metal`
- Host view: `apps/ios-macos/Sources/Shared/ConvergenceFieldView.swift` (`MacConvergenceField` on macOS is a palette wrapper)
- macOS layout: `MacScreens.swift` (`welcome`) + `MacRootView.swift` + window chrome (§6)
- iOS layout: `AuthGateView.swift` — field `.ignoresSafeArea()`, copy in safe area (§9)
- Reference plates: `mockups/macos/auth-login-convergence.png`, `mockups/ios/auth-login-convergence.png` (promoted from `mockups/*/concepts/` → ledger `mockup_ref`)
- Visual grammar: [thewayofcode.com](https://www.thewayofcode.com/) — calm line fields, cream paper, near-black-green ink

## 1. The pattern in one paragraph

Render **isolines (contour lines) of a procedural height field, per pixel, on
the GPU**. The height field is domain-warped fractal noise (fBm) with
vertically stretched features so contours flow top-to-bottom. A **gentle
right-side height bias** (not a `tanh` cliff) keeps gravitas on the right
without a mid-panel moiré stripe. Animate by sliding the noise domain very
slowly over time. Ink shaping: `fwidth` hairline AA, a **cliff guard** on
steep slopes, and **pixel-based** edge fades (left dissolve under copy;
short rim floors on the other three sides).

## 2. Architecture: why a Metal shader, not Canvas/CGContext

We first shipped a CPU renderer (150 polylines drawn into a `CGContext`,
re-rendered off-main and swapped ~2.5 fps). It worked but:

- ~9–16% of one core even after optimizations (coarser steps, lower fps).
- Fluidity capped by how often you can afford to re-render a bitmap.
- Debug builds are brutally slower for tight Swift math loops (fBm per
  vertex); profiling in debug misleads you.
- Stroke-based vein + sway → "twisted rope" braiding where lines cross.

The replacement is a SwiftUI `colorEffect` with a `[[ stitchable ]]` Metal
function. The GPU evaluates the whole field per pixel per frame; frame rate
and line density become nearly free. Remaining CPU cost is mostly SwiftUI's
`TimelineView` re-evaluation overhead, not rendering — cap `minimumInterval`
at 20 fps and profile in release (`SWIFT_OPTIMIZATION_LEVEL=-O`).

**Learning:** for full-screen generative art, go straight to a shader.
CPU-side generative rendering is only worth it for static plates.

## 3. Height field recipe (`heightField` in the shader)

Layers, in order:

1. **Anisotropic base coordinates** — stretch features vertically so contours
   read as top-to-bottom flow, and scale x by the view aspect so the pattern
   doesn't distort with window size:
   `px = nx * aspect * 2.85 + time * 0.15;  py = ny * 1.42;`
2. **Domain warp** — sample fBm twice (offset seeds) and displace coordinates
   before the final noise lookup:
   `px += 1.25 * wx; py += 1.25 * wy;`
   Warp ~1.25 is the current character knob (1.35 read turbulent; 1.1 read
   too regular). Non-integer lacunarity (2.03, 4.1209…) avoids grid artifacts.
3. **fBm height** — 4 octaves of value noise.
4. **Right-side bias (current)** — `h += 0.06 * smoothstep(0.55, 0.92, nx);`
   nudges contour density to the right without a cliff.

### Do **not** use a `tanh` convergence vein (retired 2026-07-09)

Early GPU passes added a meandering `tanh` ridge (`vx ≈ 0.70–0.76`,
amplitude `0.34–0.50`, cliff `/ 0.030–0.036`) to mimic the concept plate's
dark convergence band. It **emerges** from bunched isolines wherever the
field has a steep cliff — but on screen it reads as a vertical **moiré /
"mind-bending" dark stripe** mid-panel, especially when peak alpha is raised.

**Learning:** concept-plate vein density is achievable with levels + ink on a
smooth field. A `tanh` cliff is the wrong tool for a live UI background —
use cliff guard (§4) instead of intentional cliffs.

## 4. Isoline rendering with `fwidth` + cliff guard

```metal
const float levels = 76.0;
float g = h * levels;
float frac = g - floor(g);
float distToLine = 0.5 - abs(frac - 0.5);
float dgPerPx = max(fwidth(g), 1e-6);
float px = distToLine / dgPerPx;
float halfWidth = 0.40 * displayScale;
float ink = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, px);

// Cliff guard — kill sub-pixel stacks (warp pockets + any residual steepness)
float lineSpacingPx = 1.0 / dgPerPx;
float cliffGuard = mix(0.22, 1.0, smoothstep(0.12, 0.58, lineSpacingPx));
float steep = smoothstep(0.65, 1.25, dgPerPx);
ink *= mix(1.0, cliffGuard, steep);

float alpha = 0.85 * ink;
alpha *= mix(1.0, 0.50, smoothstep(0.65, 1.25, dgPerPx));
```

- `fwidth(g)` converts isoline distance to **device pixels** — hairlines stay
  ~0.8 px wide on Retina. Pass `displayScale` in; do not guess.
- **Cliff guard** only attenuates steep slopes (`dgPerPx` high). Flat field
  keeps full ink; do **not** apply a global moiré multiplier — that washed
  the whole pattern out when we tried to fix the vein.
- Peak alpha **0.85** and ink `#0B201A`-range read close to thewayofcode /
  concept; **0.42–0.62** read too faint on cream.

## 5. Ink and edge fades

- Return **premultiplied** color: `half4(inkColor * a, a)`.
- **Use pixel-based fades**, not normalized `nx`/`ny` ramps — on tall windows
  a `ny * 0.78` bottom fade wipes out hundreds of pixels of pattern.

Current edge recipe (points):

```metal
alpha *= smoothstep(300.0, 460.0, x);                              // left: clear copy column
alpha *= mix(0.55, 1.0, smoothstep(panelW - 40.0, panelW - 4.0, x));   // right rim
alpha *= mix(0.58, 1.0, smoothstep(0.0, 40.0, y));                     // top rim
alpha *= mix(0.52, 1.0, smoothstep(panelH - 40.0, panelH - 4.0, y));   // bottom rim
```

**Learnings, in feedback order:**

1. No fade at all → lines look abruptly cut at the window edge.
2. Short fade-to-zero at rims → blank margin (worse than none).
3. Rim floors (`mix(0.52…0.58, 1.0, …)`) keep hairlines kissing the edge
   quietly — good on top/right/bottom.
4. **Left must dissolve under the content column** (`smoothstep(300, 460, x)`).
   A uniform all-edge vignette (same ramp from every side) was tried and
   **reverted** — it let ink show behind buttons/copy and made "every line
   look dark" under the auth stack.
5. To soften only the outer rims further, widen the pixel ramps on
   top/right/bottom — do not symmetrically vignette the left edge.

## 6. Host view + welcome layout + unified title bar

### Shader host (`ConvergenceFieldView`)

Implementation: `Sources/Shared/ConvergenceFieldView.swift`. Key knobs:

```swift
TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { … }
Rectangle().fill(background).visualEffect { content, proxy in
    content.colorEffect(ShaderLibrary.convergenceField(
        .float2(Float(proxy.size.width), Float(proxy.size.height)),
        .float(fieldTime),
        .float(displayScale)))
}
```

- Drift **0.05 units/s** — breathing, not river flow.
- Size uniform from `visualEffect` + `proxy.size` — **not** `GeometryReader` inside `TimelineView`.

### Welcome screen must be full-bleed (`MacRootView` + `MacScreens`)

**Do not** put welcome inside the shared `ScrollView` + `minHeight: height - 72`
shell — that reserved empty space at the bottom on tall windows and added
54 pt top / 18 pt bottom padding.

Current pattern:

1. **`MacRootView`:** `displayedScreen == .welcome` → render `screenContent`
   directly (no scroll shell). Do **not** blanket `.ignoresSafeArea()` on
   welcome — copy must respect the top safe area under the traffic lights.
2. **`welcome` in `MacScreens.swift`:** `ZStack` with `ConvergenceFieldView`
   behind copy. Field uses `.ignoresSafeArea()` so isolines extend edge-to-edge
   including the title-bar region; the auth column stays in the safe area with
   `.padding(.leading, 56)` / `.padding(.top, 28)`.
3. **No `GeometryReader` in welcome** — the field fills via
   `.frame(maxWidth: .infinity, maxHeight: .infinity)` + `ignoresSafeArea`.
   A `GeometryReader` wrapper was retired; it sized the field to the content
   column on some layouts.

### Unified title bar (traffic lights on app chrome)

Goal: cream + field behind the red/yellow/green buttons — like Cursor — not a
blank white title-bar strip.

**AppKit (`MacWindowChromeHider` in `MacDesignSystem.swift`):**

```swift
window.styleMask.insert(.fullSizeContentView)
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
window.titlebarSeparatorStyle = .none
window.isMovableByWindowBackground = true
window.backgroundColor = MacWindowChrome.creamNSColor  // #FAF7F1 — matches MacPalette.background
window.isOpaque = true
```

**SwiftUI (`MacRootView` + `LikemindedMacApp`):**

```swift
.containerBackground(MacPalette.background, for: .window)
.toolbarBackground(.hidden, for: .windowToolbar)
.background(MacWindowChromeHider())  // on root in LikemindedMacApp
```

**Learning:** `fullSizeContentView` + transparent titlebar alone still shows
**white** if `window.backgroundColor` stays default and SwiftUI does not paint
the window container. Set **both** AppKit cream background and
`.containerBackground(…, for: .window)`. Hide the window toolbar or a grey
separator reappears.

### Window minimum size

SwiftUI `.frame(minWidth:minHeight:)` does **not** stop macOS resize.
`MacWindowChromeHider` sets `window.contentMinSize` and `window.minSize` from
`MacWindowMetrics` (currently **1200×820** default and min). Compare captures
at **min and tall** heights — rim fades and title-bar bleed only show on one
extreme.

### Canonical app bundle

Build output: `.build/macos/Build/Products/Debug/LikemindedMac.app` only
(`script/macos_canonical_app.sh`). Stale copies under other `.build/macos-*`
paths or Xcode DerivedData cause Spotlight "deleted" ghosts and old UI. After
shader/chrome edits: `macos_kill_all` → remove stale bundles → `macos_ensure_built`
→ `lsregister -f -R -trusted` on the canonical `.app`.

## 7. Tuning workflow that worked

1. **Screenshot loop:** build canonical app → launch welcome →
   `output/validation/macos-screens/welcome.png` (and `welcome-tall.png`)
   next to `mockups/macos/auth-login-convergence.png`. Compare at **min and
   tall** window sizes — resize bugs and title-bar bleed only show on one
   extreme.
2. Crop strips (`sips -c … --cropOffset …`) to inspect rim fades and the
   traffic-light band at pixel level; full-frame eyeballing hides edge problems.
3. **Measure CPU in release**; debug per-pixel math is 5–10× pessimistic.
4. Ledger owner: `validation/screens/auth.json` (`mockup_ref`,
   `visual_parity` / `ui_validation`).
5. Capture scripts: redirect to a log file; piping `verify_macos_screens.sh`
   through `tail` hung on `macos-app` locks.

## 8. Pitfalls checklist

| Pitfall | Symptom | Fix |
|--------|---------|-----|
| `tanh` vein cliff | Mid-panel dark moiré / "mind-bending" stripe | Remove cliff; use right bias + cliff guard |
| Global moiré multiplier | Whole field washed out / faint | Guard **only** steep slopes (`dgPerPx`) |
| Normalized edge fades | Pattern vanishes on tall windows | Pixel-based fades using `position` + `size` |
| Uniform all-edge vignette | Ink behind auth copy; "every line dark" | Left dissolve under content column |
| Welcome in `ScrollView` | Pattern stops before content bottom | Full-bleed welcome path in `MacRootView` |
| Welcome `.ignoresSafeArea()` on whole screen | Copy under traffic lights | `ignoresSafeArea` on **field only**; column in safe area |
| Blank white title-bar strip | Traffic lights on white, not cream/field | `window.backgroundColor` + `.containerBackground(…, for: .window)` + hidden toolbar |
| `fullSizeContentView` without container bg | Transparent titlebar still reads white | AppKit cream **and** SwiftUI `.containerBackground` |
| Field sized to content `ZStack` | Pattern height = column height | Field: `.frame(max…)` + `.ignoresSafeArea()` |
| `GeometryReader` in welcome layout | Field clipped or wrong height | Retired — use `ZStack` + infinite field frame |
| `GeometryReader` in `TimelineView` | CPU layout churn | `visualEffect` + `proxy.size` only |
| `halfWidth` without `displayScale` | Fat/shimmer lines on Retina | Pass scale uniform |
| Integer fBm lacunarity | Grid-aligned contours | Use 2.03, 4.1209, … |
| Peak alpha ≤ 0.62 | "Hardly visible" on cream | 0.85 + darker ink for shipping parity |
| SwiftUI min frame only | User can shrink window too small | `NSWindow.contentMinSize` in chrome hider |
| Stale `.app` bundles / DerivedData | Old UI, Spotlight "deleted" entries | One canonical path; `lsregister` after rebuild |

## 9. iOS auth gate

- **View:** `AuthGateView.swift` — `ConvergenceFieldView` full bleed; copy column in safe area.
- **Reference:** `mockups/ios/auth-login-convergence.png`
- **Shader:** portrait branch when `aspect < 0.85` — lower-right bias + `smoothstep(0, 0.72, nx)` left dissolve (§4); landscape/mac keeps pixel dissolve `300–460` pt.
- **Copy:** mac-aligned headline, promise rows, `AuthTermsFooter`; green Apple button stays iOS-native.

Other screens: do **not** reuse auth `ConvergenceFieldView` by default.
Pick a screen-themed field from §10–§11; keep content-screen fields quiet.

## 10. Field doctrine — theme, place, restraint

Inspiration: [thewayofcode.com](https://www.thewayofcode.com/) — cream paper,
fine hairlines, calm motion. Patterns support meaning; they never compete with
copy, cards, or CTAs.

| Screen | Theme (why a field) | Shader | Loudness | Where |
|--------|---------------------|--------|----------|-------|
| Auth / welcome | Arrival / gravitas | `convergenceField` | Hero (α≈0.85) | Full-bleed behind copy |
| Meet | Gathering toward a place | `meetVenueConvergenceField` | Whisper (α≈0.24) | Right half of Next-meetup card only |
| Circles | Quiet placement gravity | `circlesPlacementField` | Atmosphere (α≈0.18) | Soft behind plate; dissolve under copy |
| Circles orbs | Room identity | `circlesRoomOrbField` | Contained (α≈0.28) | Inside circular room marks only |

**Rules**

1. One grammar per screen — never reuse auth topo on Meet/Circles.
2. Content screens whisper; only auth may speak as a hero field.
3. Pattern must fit the screen metaphor (place / placement / identity).
4. If removing the field would not hurt understanding, it is too loud — soften.
5. Compare capture vs concept plate before claiming parity.

## 11. Meet venue field (`MacMeetVenueConvergenceField`)

Card atmosphere for Meet hero (`MacMeetOverviewConceptView`).

### Live pattern lock

**Source:** code-drawn, static, MorphingContours-inspired venue field in
`MacMeetVenueConvergenceField` (`MacDesignSystem.swift`). Do **not** use an
upscaled bitmap for this surface: fine hairline art softens immediately when the
app expands. The card should render lines at the actual card size.

Live SwiftUI pin + venue label sit on top at
`MacMeetVenueConvergenceField.pinPosition(in:)`, currently right-side focus
≈ `(0.76, 0.50)`.

### Use / do not use

| Use | Do not use |
|-----|------------|
| Static code-drawn contour field | Upscaled `MeetVenueFieldConcept` bitmap as live hero |
| Live pin/label overlay | Baking pin into artwork |
| ONE card, field behind copy | Separate map panel / seam |
| Subtle closed/wavy contours | Harsh radial spokes / starburst |
| Render-size drawing for min/max app widths | Fixed bitmap stretched to fill |

- Plate: `mockups/macos/concepts/mockup-meet-overview-convergence.png`
- Current evidence: `output/validation/macos-screens/meet-generated-min-1200x820.png`,
  `output/validation/macos-screens/meet-generated-max.png`

### Pattern criteria

- Subtle first: pattern supports the card; it must not become the card.
- Sharp at every size: draw with SwiftUI/Canvas at render size, not from an
  enlarged bitmap.
- No starburst: avoid strong radial spokes, dark cuts, or black-hole focus.
- Right-side focus: convergence aligns with the venue pin/label.
- Readable left copy: fade under title, date, avatars, and RSVP buttons.
- Expands with app width: the hero card keeps using available width.
- Cream-on-ink palette: warm cream background, very low-opacity near-black/green
  hairlines, no extra colors.
- Organic, not mechanical: slight wave/irregularity; no chart-like perfect rings.
- Static feel: no obvious animation.

### Pitfalls

| Pitfall | Symptom | Fix |
|--------|---------|-----|
| Bitmap cover source is too small | Sharpness drops on max-width app | Use render-size generated Canvas field |
| Radial line field | Overwhelming starburst behind pin | Use closed/wavy contour loops |
| Field too faint at max width | Hero looks empty | Slightly increase contour count/alpha/line width |
| Field too dark under copy | RSVP/title readability drops | Fade more aggressively on the left |
| Pin baked into artwork | Double pin / stale venue | Keep pin/label as live SwiftUI overlay |

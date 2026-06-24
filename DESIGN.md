---
version: "alpha"
name: "Likeminded"
description: "Operator-facing design system for an AI-native iPhone app that profiles people through voice conversation, places them into personality-fit circles, suggests interest-led communities, and helps real interaction happen."
source_of_truth:
  product_direction: "docs/product-direction.md"
  product_frame: "Talk -> Profile -> Circles -> Communities -> Hosted Interaction"
  placement_rule: "AI suggests and creates circles; user confirms meaningful placement and interaction"
  visual_reference: "/var/folders/d4/n827kdgs5hl0dj940t7t6wm00000gn/T/codex-clipboard-c6ec3489-f8aa-4f3e-845d-e70004056ee6.png"
colors:
  canvas: "#FAF7F1"
  surface: "#FFFDFC"
  surface-raised: "#FFFFFF"
  ink: "#102A25"
  subink: "#5F625D"
  muted: "#8A8A82"
  primary: "#0F4A3D"
  primary-deep: "#08382F"
  primary-soft: "#E5F0EA"
  success: "#3C9B5F"
  amber: "#C78310"
  coral: "#E98266"
  teal: "#2F7A78"
  rule: "#E6DFD5"
  shadow: "rgba(28, 24, 18, 0.10)"
typography:
  title-xl:
    fontFamily: "SF Pro Display"
    fontSize: "2rem"
    fontWeight: 700
    lineHeight: 1.04
    letterSpacing: "0"
  title-lg:
    fontFamily: "SF Pro Display"
    fontSize: "1.5rem"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "0"
  title-md:
    fontFamily: "SF Pro Display"
    fontSize: "1.0625rem"
    fontWeight: 650
    lineHeight: 1.18
    letterSpacing: "0"
  body:
    fontFamily: "SF Pro Text"
    fontSize: "0.9375rem"
    fontWeight: 400
    lineHeight: 1.35
    letterSpacing: "0"
  body-strong:
    fontFamily: "SF Pro Text"
    fontSize: "0.9375rem"
    fontWeight: 600
    lineHeight: 1.28
    letterSpacing: "0"
  caption:
    fontFamily: "SF Pro Text"
    fontSize: "0.8125rem"
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0"
  label:
    fontFamily: "SF Pro Text"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0"
  metric:
    fontFamily: "SF Pro Display"
    fontSize: "1.0625rem"
    fontWeight: 650
    lineHeight: 1.05
    letterSpacing: "0"
rounded:
  sm: "10px"
  md: "14px"
  lg: "18px"
  xl: "22px"
  pill: "999px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "28px"
components:
  app-shell:
    backgroundColor: "{colors.canvas}"
    horizontalPadding: "20px"
    topInset: "68px"
    bottomInset: "96px"
  top-bar:
    leftAction: "menu"
    rightAction: "contextual icon"
    iconColor: "{colors.ink}"
    notificationDot: "{colors.coral}"
  bottom-tabs:
    labels: ["Talk", "Circles", "Communities"]
    selectedColor: "{colors.primary}"
    inactiveColor: "{colors.ink}"
    backgroundColor: "{colors.surface}"
  hero-placement-card:
    backgroundColor: "{colors.primary-deep}"
    textColor: "#FFFFFF"
    borderRadius: "{rounded.xl}"
    shadow: "{colors.shadow}"
  raised-card:
    backgroundColor: "{colors.surface-raised}"
    borderColor: "{colors.rule}"
    borderRadius: "{rounded.lg}"
    shadow: "{colors.shadow}"
  primary-button:
    backgroundColor: "{colors.primary}"
    textColor: "#FFFFFF"
    borderRadius: "{rounded.md}"
  segmented-control:
    activeBorderColor: "{colors.primary}"
    activeBackgroundColor: "{colors.primary-soft}"
    inactiveBackgroundColor: "{colors.surface}"
---

# Likeminded Design Direction

Likeminded should feel like an AI social operator for human placement. The app does not behave like a generic social feed, dating app, community directory, or mental-health reflection app. It talks with the user, builds a living personality profile, creates and suggests personality-fit circles, suggests interest-led communities, and helps the first real interaction happen.

The supplied imagegen mockup is the active visual reference for the next prototype pass. Use it as inspiration, not a pixel contract.

## Product Posture

The core loop is:

1. Talk: AI voice conversation builds the user's personality profile.
2. Profile: the user reviews and corrects the living AI profile.
3. Circles: AI creates and suggests selective personality-fit circles.
4. Communities: AI suggests broader liking-based communities.
5. Hosted Interaction: AI encourages in-app meetings, evaluates host fit, and helps the group move toward real connection.

The placement rule is `AI suggests and creates; user confirms meaningful placement and interaction`. The system can propose circles, communities, hosts, meetings, and eventually offline plans, but the user must stay in control of commitment, sharing, and attendance.

## Navigation Model

The primary navigation should collapse around the actual loop:

- Talk: active AI voice conversation and profile building.
- Circles: personality-fit rooms, circle meetings, host signals, and people.
- Communities: interest-led spaces, community meetings, and events.
- Profile can be a secondary surface reached from Talk or account controls.

Avoid five equal tabs as the default product posture. Safety, settings, and profile controls remain accessible through top actions, contextual cards, or secondary surfaces; they should not dilute the social-operator loop.

## Visual Language

Use a warm cream canvas with quiet white cards and deep green moments of trust. The strongest card on the screen should usually be the placement or commitment card, not a prose section.

The design should be:

- clean, native, and compact,
- icon-led but not decorative,
- action-first with details available on demand,
- calm enough for reflection,
- operational enough to help the user decide what to do next.

Do not lean on oversized editorial serif type as the default. Serif or display moments may appear later as brand accents, but the current app should mostly use crisp SF-style native hierarchy.

## Screen Contracts

### Place

This is the current prototype's default home surface. In the next product pass, it should become a circle-placement surface under `Circles`. It should answer: where am I being placed, why, and what should I do next?

Required elements:

- top bar with menu and contextual notification/action icon,
- clear `Today` title and short subtitle,
- dark green `Next Placement` card,
- placement target such as `Ava into Creators Circle`,
- fit, trust, and confidence evidence,
- next action rows with icons,
- circle overview cards.

Keep the first viewport useful without scrolling. The primary action should never sit hidden behind the bottom tab bar.

### Connect

This surface should be folded into `Circles` and `Communities`. It should stay circle-first before people-first.

Required elements:

- `Connections` title,
- segmented control for circle view and people view,
- active circle selector,
- compact people cards with avatar, role, relationship strength, and placement confidence,
- one clear add or invite action.

People cards should show evidence, not bios. Prefer short labels like `Strong`, `Growing`, `92%`, and small confidence bars over paragraphs.

### Talk And Profile

The app should not feel like a written reflection or mental-health journal. Profile building should start with active AI voice conversation, then expose a reviewable profile.

Required elements:

- active voice conversation entry point,
- visible profile signals learned from the conversation,
- user correction controls,
- privacy state,
- one clear continue/save profile action.

Conversation can inform profile, circle placement, community suggestions, and host/interactions recommendations, but the screen must make privacy and user control visible before asking for vulnerable input.

## Components

### Placement Card

The placement card is the signature component.

- Use deep green fill.
- Use one circular icon target at the left.
- Show the placement sentence in plain language.
- Show three compact evidence fields: fit, trust, confidence.
- Use a chevron or clear affordance for detail.
- Avoid paragraph explanations in the default state.

### Action Rows

Action rows should be fast to scan.

- Square icon tile at left.
- Main action label.
- One short supporting line.
- Chevron at right.
- Use distinct but restrained icon colors.

### Circle Cards

Circle cards should prove that circles are a core object.

- Show circle name.
- Show small avatars or count.
- Show member count.
- Show state such as `Strong`, `Growing`, `Steady`.
- Keep cards horizontally scannable.

### Person Cards

Person cards should support relationship judgment.

- Avatar and online/status dot.
- Name and role.
- Relationship strength.
- Placement confidence.
- Small confidence bars or score.
- Overflow menu for secondary actions.

### Profile Cards

Profile cards should show what the AI learned from conversation. They should not feel like diary prompts.

- One profile signal group per card.
- Correction controls should be compact and bordered.
- Selected states use soft green fill or green border.
- Primary action uses deep green.
- Privacy note stays visible near profile save or correction.

## Copy Rules

Default copy should be short enough to scan in one glance.

Use:

- `Talk with AI`
- `Your AI Profile`
- `Next Placement`
- `Circle Overview`
- `Host Fit`
- `Meeting Energy`
- `Community Match`
- `Private until you share`
- `Placement Confidence`
- `Add to Circle`
- `Save Profile`

Avoid:

- long product explanations,
- generic social phrasing,
- startup verbs like `unlock` or `supercharge`,
- therapy-like vagueness,
- exposing internal task names or implementation details.

Details and rationale can exist behind disclosure, drill-in, or secondary states. They should not dominate the first viewport.

## Motion And Interaction

Motion should be restrained and native.

- Use subtle press states and sheet transitions.
- Avoid floating decorative animation.
- Do not move text or cards enough to harm readability.
- A screen should remain useful with motion disabled.

Interaction should make the next step obvious:

- Talk: speak with AI, review profile, correct profile.
- Circles: review fit, accept placement, join meeting, invite, or adjust placement.
- Communities: review interest match, join meeting, invite, or follow.

## Implementation Priorities

For the next SwiftUI pass:

1. Replace the Reflect framing with AI voice conversation and living profile review.
2. Separate Circles from Communities: circles are personality-fit; communities are liking-based.
3. Add in-app circle/community meeting concepts with transcript, host fit, vocality balance, and meeting energy.
4. Model hosts as AI-evaluated social operators, not just volunteers or frequent organizers.
5. Keep the operator placement model in the data and copy.
6. Verify on iPhone simulator screenshots that no primary action or text is hidden behind the tab bar.

## Avoid

Do not introduce:

- generic dashboards with equal-weight cards,
- paragraph-heavy first viewports,
- five-tab product structure as the main model,
- mental-health or diary framing,
- orange as the dominant brand accent,
- large serif type as the default UI voice,
- decorative blobs or ambient gradients,
- bottom controls that overlap the native tab bar,
- match browsing before placement is confirmed.

The app should feel practical, focused, and distinctly about AI helping likeminded people meet, talk, and build real relationships.

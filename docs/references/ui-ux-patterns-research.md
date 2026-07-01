# UI/UX Design Patterns Research — Likeminded App

Date: July 1, 2026
Sources: Apple HIG, WWDC 2023 (Explore SwiftUI Animation, Wind Your Way Through Advanced Animations, Animate with Springs), analysis of Hinge, Bumble, ChatGPT, Pi, Discord, Luma, Partiful, iMessage, Crystal, 16Personalities, Apple Fitness, Journal

## 1. Onboarding Form UI

### Pattern: Single-field-per-screen wizard
Apps: Hinge, Bumble, Headspace

Each field is its own screen. Text field centered, question above, keyboard slides up beneath. Progress indicator (thin dots or segmented bar) at top. Tapping Next slides current field out (left), next in (right). Keyboard stays focused between transitions.

SwiftUI: TabView with .tabViewStyle(.page(indexDisplayMode: .never)), .animation(.spring(response: 0.38, dampingFraction: 0.82), value: currentStep)

### Pattern: Inline date picker
Apps: Hinge DOB picker, Apple Fitness

Show scrolling wheels directly as content, not via popover. Wheels inset in rounded container, no labels. Compact 3-column picker.

SwiftUI: DatePicker with .datePickerStyle(.wheel) inside rounded container, or triple-column Picker.

### Pattern: Location as map pin drop
Apps: Hinge, Bumble

Map with approximate location centered. Subtle pin animation drops. "Use Current Location" button. No address text field. Map inset with corner radius, no chrome.

## 2. Voice/Audio Interface UI

### Pattern: Orb/pulsing sphere for listening state
Apps: ChatGPT voice mode, Pi (Inflection AI)

Smooth gradient-filled sphere. Pulses gently when idle, expands/contracts with voice amplitude when user speaks, contracts to small dot when processing. Radial gradient, not flat color. Subtle floating animation.

SwiftUI: Circle with RadialGradient, frame based on amplitude, .animation(.spring(response: 0.3, dampingFraction: 0.7), value: amplitude)

### Pattern: Status bar with clear state machine
Apps: ChatGPT voice, Voxer

Four visually distinct states: Idle (mic icon), Listening (orb pulses + level meter), Processing (orb shrinks, spinner), Complete (checkmark). Transitions cross-faded with spring.

SwiftUI: ZStack with all states rendered, opacity-driven, .animation(.easeInOut(duration: 0.25), value: state)

### Pattern: Compact waveform visualizer
Apps: Anchor, Voxer

Thin (24-32pt) bar showing last ~2 seconds as vertical bars. Rounded caps, accent color with gradient (opacity fades left to right).

SwiftUI: Canvas drawing bars from audio buffer, .timelineView(.periodic(from: .now, by: 0.05)) for 20fps updates.

## 3. Profile/Personality Display

### Pattern: Trait bars with gradient fills
Apps: Crystal, 16Personalities

Horizontal bar, gradient fill from personality type color to lighter tint. Rounded ends, midpoint marked. Trait name left, descriptor right ("Reserved" ← → "Outgoing"). No numbers.

SwiftUI: ZStack with Capsule background + Capsule fill (LinearGradient), width based on value.

### Pattern: Personality archetype card with radial visual
Apps: 16Personalities results, Crystal dashboard

Large card with type name + radar/spider chart (pentagon for Big Five). Thin stroke, transparent accent fill. 3-4 strengths as compact chips below.

SwiftUI: Custom PentagonChart Shape, .fill(.accentGreen.opacity(0.15)), .overlay(stroke).

### Pattern: "This is you" visual summary
Apps: Crystal

Single-sentence AI summary at top. Below: traits as horizontal bars. Warm, second-person tone.

## 4. Community/Circle Cards

### Pattern: Layered avatar stacks + topic tags
Apps: Discord, Geneva

Gradient background (not flat). Group name overlaid. Horizontal stack of 3-4 circular member avatars with overlap. "+X more" badge. 2-3 topic tags as pills. Member count as subtle secondary line.

### Pattern: Swipe to join
Apps: Geneva, Meetup

Cards swipable left/right. Right = join, left = dismiss. Card tilts (rotation), green glow on right during swipe.

SwiftUI: DragGesture with .rotationEffect and .offset, threshold check on end.

### Pattern: Horizontal scroll sections
Apps: Luma, Apple TV

Cards at ~85% screen width, peeking next card. Section headers with eyebrow + title. scrollTransition scales edge cards (0.95, opacity 0.8).

SwiftUI: ScrollView(.horizontal), .scrollTransition(.interactive, axis: .horizontal), .scrollTargetBehavior(.viewAligned)

## 5. Schedule/RSVP UI

### Pattern: Toggle-style RSVP with spring
Apps: Partiful, Luma

Single toggle: Going / Interested / Can't Go. Segmented pill look, selected state animates to fill. No confirmation dialog. Haptic on toggle.

SwiftUI: HStack of options, matchedGeometryEffect on selected capsule, .sensoryFeedback(.success, trigger: rsvpState), withAnimation(.spring(response: 0.35, dampingFraction: 0.8))

### Pattern: Event card with countdown
Apps: Luma, Partiful

Photo/gradient header, date/time line, live countdown if < 7 days, map thumbnail, RSVP toggle below. Feels like invitation, not calendar entry.

SwiftUI: VStack with gradient header, monospacedDigit countdown, Map(interactionModes: []) thumbnail.

### Pattern: Add to Calendar button
Apps: Luma

Plain-text button at bottom. EventKit integration. No custom calendar views.

## 6. Chat UI

### Pattern: Bubble-only view
Apps: iMessage, Telegram

Only message bubbles. No separators. No avatars in 1:1. Timestamps only on significant gaps. Max bubble width ~70%. Generous spacing (8-12pt). Subtle bubble shadows. Clean SF Pro 17pt. No borders, no dividers.

SwiftUI: LazyVStack(spacing: 10), HStack with Spacer for alignment, RoundedRectangle(cornerRadius: 18, style: .continuous).

### Pattern: Composer as part of view
Apps: iMessage, Telegram

Text input pinned at bottom with .regularMaterial background. Rounded text field, auto-expands 1-4 lines. Send button: arrow.up.circle.fill in accent. Not a UIToolbar.

SwiftUI: VStack with messageList + HStack composer, .background(.regularMaterial), TextField(axis: .vertical) with .lineLimit(1...4).

### Pattern: Typing indicator
Apps: iMessage, Telegram

Three small circles animating sequentially (1 → 2 → 3 → all off, loop). Inside bubble-shaped container.

SwiftUI: HStack of 3 Circles, .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.2), value: activeDot).

## 7. Tab Bar + Navigation Transitions

### Pattern: Custom tab bar with SF Symbol scale
Apps: Apple Fitness, Apple Journal

SF Symbols with scale bounce on selection (1.1 → 1.0 spring). Label appears only on selected tab. Frosted glass background (.ultraThinMaterial).

SwiftUI: Custom HStack, .scaleEffect(selection == tab ? 1.1 : 1.0), .symbolVariant(.fill for selected), .background(.ultraThinMaterial).

### Pattern: matchedGeometryEffect for transitions
Apps: Apple Photos, Apple Fitness rings

Shared element animates smoothly between positions. Selected card in list animates to become hero in detail view. #1 pattern for "Apple-polished" feel.

SwiftUI: @Namespace, .matchedGeometryEffect(id:in:isSource:) on both source and destination.

### Pattern: Push vs Sheet
Apps: Apple Settings (push), Apple Mail compose (sheet)

Push (.navigationDestination) for hierarchical data. Sheet (.sheet with .presentationDetents) for modal tasks. Sheets feel lighter, less committing.

## 8. Motion/Animation Principles

### Pattern: Spring as default
WWDC23 "Animate with springs"

Standard: .spring(response: 0.38, dampingFraction: 0.82)
Celebratory: .spring(response: 0.50, dampingFraction: 0.70)
Snappy: .spring(response: 0.30, dampingFraction: 0.85)

### Pattern: Staggered entrance
Apple Journal, Apple Fitness

Items animate in one at a time, 0.05-0.08s delay. Fade + slide up ~20pt.

SwiftUI: .opacity + .offset with .animation(.spring().delay(Double(index) * 0.06))

### Pattern: PhaseAnimator for multi-step
WWDC23 "Wind Your Way Through Advanced Animations"

Sequences like pulse → scale → reset. Replaces manual state-machine chaining.

SwiftUI: PhaseAnimator([0.0, 1.0, 0.5, 0.0], trigger:) { phase in ... } animation: { phase in ... }

### Pattern: ContentTransition
WWDC23 "Explore SwiftUI Animation"

.contentTransition(.numericText()) for counts, .contentTransition(.interpolate) for text cross-fade.

### Pattern: ScrollTransition
iOS 17+

Cards scale to 0.95 and dim to 0.8 opacity near edges. Creates depth and focus.

SwiftUI: .scrollTransition(.interactive, axis: .horizontal) { content, phase in ... }

### Pattern: Material backgrounds
Apple HIG

.background(.regularMaterial) for sheets, tab bar, floating elements. Blends with cream canvas, creates depth. .ultraThinMaterial for tab bar specifically.

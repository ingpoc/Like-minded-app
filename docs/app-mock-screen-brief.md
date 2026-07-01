# Likeminded — App Brief for Mock Screen Generation

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This brief is a product/design reference only.

## What is Likeminded

Likeminded is an AI-native iOS app that helps people who should meet actually meet. It uses a voice conversation with AI to understand your personality deeply, places you into personality-fit circles, suggests interest-led communities, and hosts in-app group video meetups where you meet the right people. The AI does the organizing — you just show up.

## Core Loop

1. You sign up and fill a quick onboarding form (name, gender, DOB, city, pincode)
2. You do a voice interview with AI — it discovers your personality, interests, and depth of each interest
3. AI places you in a circle (people with similar personality) and suggests communities (people with shared interests)
4. You RSVP "available this weekend" — one tap
5. AI forms groups of 10 (gender-balanced 5M/5F), picks a host, schedules the meetup
6. Saturday: community video meetup (different personalities, shared interest)
7. Sunday: circle video meetup (similar personalities, natural fit)
8. After each meetup: if you have Soulmate enabled, you can mark who you connected with. If both people mark each other, you match and can chat.

## Design Language

- **Canvas:** Warm cream (#FAF7F1)
- **Accent:** Deep green (#0F4A3D)
- **Surface:** Warm white (#FFFBFB)
- **Ink:** Dark green-black (#0F2A25)
- **Typography:** SF Pro (system native). Hero 32pt bold, section title 17pt semibold, body 15pt regular, metadata 13pt medium, eyebrow 11pt semibold small caps
- **Cards:** Rounded corners (16-24pt continuous), subtle 1pt border (#E6DFD5), no heavy shadows
- **Buttons:** Primary = filled accent green, white text, 18pt radius. Secondary = surface fill, ink text, 1pt border
- **Feel:** Polished, sophisticated, calm, warm. Not loud, not playful, not corporate. Think editorial magazine meets Apple Fitness.
- **Motion:** Spring animations everywhere. Tab switches, toggles, card entrances all use spring. Cards stagger in on appear (fade + slide up, 0.06s delay per card).

## Tabs (5 — bottom nav bar)

1. **Meet** (person.2.video icon) — RSVP, upcoming meetups, join video calls
2. **Circles** (person.3.fill icon) — your personality-fit circle + browse available
3. **Communities** (rectangle.3.group icon) — interest-based groups catalog
4. **Profile** (person.crop.circle icon) — voice interview, personality, interests
5. **Soulmate** (heart.circle icon) — only visible when enabled. Matches + chat

---

## Screen 1: Auth Gate (Sign In)

**Purpose:** First impression. Get the user signed in with Apple.

**Layout:**
- Full cream background
- "Likeminded" in hero typography, top-left
- Subtitle: "Start with a private AI voice profile. Your placement is created only after you sign in."
- Three feature labels with icons: "Voice profile" (waveform.circle), "Private profile review" (person.text.rectangle), "Circle placement" (person.3.fill)
- Sign in with Apple button (black, full width, 52pt height)
- Minimal, generous spacing, no images

---

## Screen 2: Onboarding Wizard (5 steps)

**Purpose:** Capture basic facts before the voice interview. 30 seconds of taps.

**Layout (per step):**
- Full cream background
- Progress dots at top: 5 thin capsules, filled = accent green, unfilled = muted
- One question centered on screen, in section title typography
- One input below the question
- "Continue" button at bottom (primary action button)
- Transitions between steps: current slides out left, next slides in right, spring animation

**Step contents:**
1. "What should we call you?" — single text field, placeholder "First name"
2. "I identify as..." — three large tappable cards stacked vertically: Male, Female, Non-binary. Selected card = accent green border + checkmark. Others = surface with border.
3. "When were you born?" — date wheel picker (Month/Day/Year) inset in a rounded white container, no labels above wheels
4. "Which city?" — text field with autocomplete dropdown
5. "Area pincode?" — numeric text field, placeholder "6 digits"

After step 5: automatically transitions to the voice interview hero in Profile — no review screen, no dead end.

---

## Screen 3: Profile Tab — Empty State (before voice interview)

**Purpose:** Guide the user into the voice interview. Nothing else to distract.

**Layout:**
- Standard screen container: eyebrow "PROFILE" in accent green small caps, subtitle "Who you are."
- Basic info row: name, gender, age, city as compact metadata text (e.g., "Priya · Female · 28 · Bangalore")
- Large voice orb hero card:
  - Deep green rounded card (24pt radius), full width
  - Pulsing radial gradient orb in center (accent green center fading to transparent)
  - Below orb: "Voice profile" eyebrow (white 72% opacity), "Tell me how you connect." (hero text, white)
  - Below: "Speak naturally. The profile updates as you talk." (body, white 82% opacity)
  - Primary button: "Start voice profile" (white text on darker green, waveform icon)
- Nothing else on screen. No signal read, no interests, no summary. Just the voice CTA.

---

## Screen 4: Profile Tab — During Voice Interview (listening state)

**Purpose:** Show the user the AI is actively listening. Visual feedback.

**Layout:**
- Same green hero card, but:
  - Orb is now expanded, pulsing with audio amplitude (slightly larger, reactive)
  - Thin audio level bar below the orb (vertical bars, accent green with gradient opacity)
  - Status text: "I am listening for fit." (hero, white)
  - Button changes to: "Stop and extract signals" (stop.fill icon)
- Below the hero card: a "Captured voice" section showing numbered signal rows as they're extracted (e.g., "1. Prefers slow, honest conversation", "2. Values steady and thoughtful pacing"). Each in a surface card with accent green number badge.
- Privacy strip at bottom: "Profile read is private. Circle placement needs confirmation." (lock.fill icon, accent green, on soft accent background)

---

## Screen 5: Profile Tab — After Profile Exists

**Purpose:** Show the user their living personality profile. Review, understand, edit.

**Layout:**
- Eyebrow "PROFILE", subtitle "Who you are."
- Basic info row (compact, tappable to edit): "Priya · Female · 28 · Bangalore"
- Compact "Update profile" button (secondary action, height ~52pt, not the big hero anymore)
- **Personality signals card:**
  - Eyebrow "SIGNALS", title "Living profile"
  - Signal tabs: three segmented pills (Communication / Energy / Trust). Selected = accent green fill, white text. Unselected = surface, ink text.
  - Below tabs: one signal summary row — icon (accent green in soft accent rounded square) + signal name + value + detail text
  - Big Five trait bars: 5 horizontal capsules stacked. Each bar = gradient fill (accent green to lighter), rounded ends. Left label (e.g., "Reserved") and right label (e.g., "Outgoing") in tiny text below. No percentage numbers.
  - Privacy strip
- **Interests card:**
  - Eyebrow "INTERESTS", title "What you're into"
  - Tag chips with depth encoding:
    - Deep (filled accent green, white text): "Jazz", "Essays", "Psychology"
    - Active (accent border, accent text): "Design", "Cooking"
    - Casual (muted bg, subink text): "Movies", "Trekking"
- **Editable summary card:**
  - Eyebrow "REFLECTION", title "Your read"
  - Text editor with model-generated summary (e.g., "You come alive in slow, emotionally honest conversations.")
  - "Save profile edits" secondary button
- **Tester feedback card** (for TestFlight MVP):
  - Rating stepper (1-5)
  - Text field: "What should improve before wider beta?"
  - "Send feedback" primary button

---

## Screen 6: Circles Tab — No Circle Yet

**Purpose:** Show available circles and guide toward placement.

**Layout:**
- Eyebrow "CIRCLES", subtitle "Choose your room."
- Empty state card: "No circle yet" (eyebrow "Talk first"), "Start in Profile." text
- "Available circles" section:
  - Section header: "Available circles" (eyebrow "BROWSE")
  - Horizontal scroll of 5 circle cards. Each card ~85% screen width, peeking the next card. Cards scale down slightly at edges (0.92 scale, 0.7 opacity).

**Circle card design:**
- Rounded rectangle (16pt), gradient background (unique per archetype — variations of green/teal/cream)
- Circle name in white, semibold (top-left)
- Room energy in white 70% opacity (below name)
- Theme tags as translucent white capsule pills (bottom-left)
- Member count: "18 members" in white 60% opacity (bottom-right)
- Fit score badge: small green capsule, "High fit" (top-right, if profile exists)

---

## Screen 7: Circles Tab — With Circle (accepted placement)

**Purpose:** Show your circle as a living room, not a dead-end "accepted" card.

**Layout:**
- Eyebrow "CIRCLES", subtitle "Your room."
- **Your circle card** (full width, featured):
  - Gradient background (circle's unique gradient)
  - Circle name in white, hero typography
  - Room energy in white 80% opacity
  - Theme tags as translucent pills
  - "Next meetup: Sunday 7pm" with calendar icon (white)
  - "12 members" with person.3 icon (white 60%)
  - Tap → circle detail view
- **Concern button** below the card: secondary action, "This doesn't feel like my circle" (hand.raised.slash icon). Subtle, not prominent.
- **Available circles** section below: same horizontal scroll as Screen 6

---

## Screen 8: Circle Detail View (pushed)

**Purpose:** Deep dive into a circle.

**Layout:**
- Pushed navigation (back button in nav bar)
- Hero section: circle name (hero text), room energy (body, subink)
- Description paragraph (body, ink)
- Meeting format row: icon + "Weekly structured check-ins with rotating facilitator"
- Themes: FlexibleTagLayout of theme tags
- Fit breakdown card: eyebrow "WHY YOU FIT", list of fit reasons with checkmark.seal icons:
  - "Your slow-trust pattern aligns with how this circle builds connection."
  - "Your analytical communication style matches this circle."
  - "Your low social energy fits the circle's pace."
- Upcoming meetup row (if scheduled): "Sunday, Jul 6 · 7:00 PM" with countdown
- "Leave circle" secondary button at bottom

---

## Screen 9: Meet Tab — No Upcoming Meetup (RSVP state)

**Purpose:** Get the user to RSVP for the weekend. One tap.

**Layout:**
- Eyebrow "MEET", subtitle "When you meet."
- **RSVP card** (full width, surface background, rounded 18pt):
  - Title: "Available this weekend?"
  - Two rows:
    - Row 1: "Saturday — Community meetup" + toggle pill on right (Available / Not). Toggle = segmented capsule, selected segment slides into place with spring. Haptic on tap.
    - Row 2: "Sunday — Circle meetup" + toggle pill on right
  - Below: "RSVP closes Friday midnight." (caption, subink)
- Empty state below: "No upcoming meetups yet." with caption "RSVP above and AI will schedule your meetup."
- Past meets section (if any): compact list rows

---

## Screen 10: Meet Tab — Upcoming Meetup Scheduled

**Purpose:** Show the user their scheduled meetup. Build anticipation.

**Layout:**
- Eyebrow "MEET", subtitle "When you meet."
- **Upcoming meetup card** (full width):
  - Gradient header strip (top, 8pt height, accent green)
  - Day/time: "Saturday, Jul 5 · 7:00 PM" (bodyStrong, ink)
  - Countdown: "2d 4h away" (metadata, accent green, monospacedDigit)
  - Host: "Host: Priya" with person.circle icon (accent green)
  - Group size: "10 participants (5M · 5F)" with person.3 icon (subink)
  - Community/circle name: "Jazz & Music Community" (sectionTitle, ink)
  - Join button: primary action, "Join meetup" (person.2.video icon). Disabled until meetup time. At meetup time: button pulses gently and activates.
- RSVP card below (if user hasn't RSVP'd for the other day)
- Past meets list below

---

## Screen 11: Meet Tab — Pre-Meet Teaser (Friday)

**Purpose:** Show group composition before the meetup. Reduce no-shows.

**Layout:**
- Eyebrow "MEET", subtitle "This weekend."
- **Pre-meet teaser card** (surface background, rounded 18pt):
  - Eyebrow: "YOUR SATURDAY MEET" (accent green)
  - Title: "Jazz & Music Community"
  - Composition preview: "5 people from 4 different circles. Two extroverts, three introverts. Host: Marco." (body, ink)
  - Group-level info only. No individual profiles. No photos.
  - "Join in 2 days" (caption, accent green)
- Same card for Sunday circle meet if scheduled:
  - Eyebrow: "YOUR SUNDAY MEET"
  - "5 people. You all share slow-trust patterns and analytical communication. Host: Priya."

---

## Screen 12: Group Video Call (LiveKit)

**Purpose:** 10-person group video call. Camera on, no voice-only.

**Layout:**
- Full screen, dark background (#1A1A1A or similar)
- **Participant grid:** LazyVGrid, 2 columns, 5 rows. Each cell = participant video tile (camera feed, rounded corners 12pt). Active speaker gets a subtle accent green border.
- **Host indicator:** small "Host" badge (accent green capsule) on host's tile
- **Self view:** your own camera feed in a small Picture-in-Picture tile (bottom-right corner, 120x160pt, rounded 12pt)
- **Bottom control bar** (frosted glass material background):
  - Mic toggle (mic.fill / mic.slash.fill)
  - Camera toggle NOT available — camera stays on
  - "Leave" button (red, phone.down.fill icon)
- No chat, no reactions, no screen share. Just video + audio.

---

## Screen 13: Post-Meet Soulmate Selection Dialog

**Purpose:** After a meetup, if Soulmate is enabled, ask who you connected with.

**Layout:**
- Sheet presentation (bottom sheet, rounded top corners)
- Title: "Did you connect with someone?" (sectionTitle, ink)
- Subtitle: "Tap the people you felt a real connection with." (body, subink)
- List of names (opposite-sex group members who also have Soulmate enabled):
  - Each row: name (bodyStrong), with a circle checkbox on the right
  - Multi-select: can check none, one, or multiple
  - Names only. No photos. No profiles.
- "Submit" primary button at bottom
- "Skip" text button below
- If only one person selects the other: nothing happens. Silent. No notification.
- If both select each other: match appears in Soulmate tab.

---

## Screen 14: Communities Tab

**Purpose:** Browse and join interest-based communities.

**Layout:**
- Eyebrow "COMMUNITIES", subtitle "What you're into."
- **Your communities** section (if joined any):
  - Section header: "Your communities" (eyebrow "JOINED")
  - Compact cards: name, member count, "Joined" badge (accent green capsule)
- **Browse** section:
  - Section header: "Browse communities" (eyebrow "DISCOVER")
  - LazyVStack of community cards (full width):

**Community card design:**
- Rounded rectangle (16pt), gradient background (unique per community — warm tones, not all green)
- Community name in white, semibold
- Summary in white 80% opacity (e.g., "People building useful AI products and tools.")
- Theme tags as translucent white pills (e.g., "AI", "Products", "UX")
- Member count: "18 members" (white 60%)
- Join button: small primary button, "Join" (person.badge.plus icon, white text)
- If joined: button changes to "Joined" (checkmark, no action)
- Fit label if profile interests match: "Strong fit" (accent green, top-right)

---

## Screen 15: Community Detail View (pushed)

**Purpose:** Deep dive into a community.

**Layout:**
- Pushed navigation (back button)
- Hero: community name (hero text), summary (body, subink)
- Themes: tag chips
- Member count: "18 members" (metadata, subink)
- Upcoming Saturday meetup row (if scheduled): "Saturday, Jul 5 · 7:00 PM" with countdown
- "Leave community" secondary button at bottom (if joined) OR "Join community" primary button (if not joined)

---

## Screen 16: Soulmate Tab — Matches List

**Purpose:** Show mutual matches. Entry point to interest profile + chat.

**Layout:**
- Eyebrow "SOULMATE", subtitle "Who you connected with."
- Top-right toolbar: chat bubble icon (bubble.right) → opens conversation list
- **Matches list** (LazyVStack):
  - Each row: name (bodyStrong), "Met at Jazz & Music meetup, Jul 5" (caption, subink)
  - Tap row → Soulmate Match Detail view
- Empty state: "No matches yet." + "Enable Soulmate and join meetups to find connections." (body, subink) + illustration or icon (heart.circle, accent green, large)

---

## Screen 17: Soulmate Match Detail (before chat)

**Purpose:** See the other person's interests before deciding to chat.

**Layout:**
- Pushed navigation (back button)
- Top-right: chat bubble icon (bubble.right) → opens chat with this person
- Hero: name (hero text), "Met at Jazz & Music meetup" (metadata, subink)
- **Interests section:**
  - Eyebrow "INTERESTS", title "What they're into"
  - Interest tag chips with depth encoding (same as Profile):
    - Deep (filled accent, white text): "Jazz", "Cooking"
    - Active (accent border, accent text): "Design", "Books"
    - Casual (muted bg, subink text): "Trekking"
- **Likes section:**
  - Eyebrow "LIKES"
  - Tag chips: "Coltrane", "Slow Sundays", "Hand-written letters"
- **Dislikes section:**
  - Eyebrow "DISLIKES"
  - Tag chips: "Small talk", "Loud places"
- "Start chatting" primary button at bottom (message.fill icon) → opens chat view
- No personality signals shown. No hidden signals. No photos. Just interests + likes + dislikes.

---

## Screen 18: Chat View (1:1 with match)

**Purpose:** Text chat between matched soulmates.

**Layout:**
- Pushed navigation (back button, match name as nav title)
- **Message list** (ScrollView, LazyVStack spacing 10pt):
  - Outgoing messages: accent green bubble, white text, trailing-aligned. Rounded 18pt continuous. Max width 70% of screen.
  - Incoming messages: surface (warm white) bubble, ink text, leading-aligned. Same shape.
  - No separators. No avatars. No timestamps on every message (only on significant gaps).
  - Generous spacing between messages.
- **Typing indicator** (when other person is typing): three small dots animating sequentially, inside a surface bubble (same shape as incoming messages). Leading-aligned.
- **Composer** (pinned at bottom, .regularMaterial frosted glass background):
  - TextField (plain style, rounded 22pt, surface background), expands 1-4 lines. Placeholder: "Message"
  - Send button: arrow.up.circle.fill (accent green, title2 size). Disabled when text is empty.

---

## Screen 19: Conversation List (from top-right chat icon)

**Purpose:** See all chat conversations. Resume any chat.

**Layout:**
- Pushed navigation (back button, "Chats" as nav title)
- LazyVStack of conversation rows:
  - Name (bodyStrong, ink)
  - Last message preview (caption, subink, truncated to 1 line)
  - Timestamp (metadata, muted — e.g., "2h", "Yesterday", "Mon")
  - Unread indicator: small accent green dot if unread
- Tap row → Chat View (Screen 18)

---

## Screen 20: Settings (profile toolbar)

**Purpose:** Account controls + Soulmate toggle.

**Layout:**
- Pushed navigation (back button, "Settings" as nav title)
- **Soulmate section:**
  - Toggle: "Enable Soulmate" (switch, accent green when on)
  - Description: "Opt in to find connections after meetups. Only visible when enabled." (caption, subink)
- **Account section:**
  - "Sign out" (secondary button, accent green text)
- **About section:**
  - App version (metadata, muted)
  - Privacy policy link

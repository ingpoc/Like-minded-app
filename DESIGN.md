# Likeminded Design Language

## Control Owner

Global `/Users/gurusharan/.codex/AGENTS.md` owns instruction control. This file owns Like-minded app design language for iOS and macOS. Visual references live in `mockups/ios/` and `mockups/macos/`.


1. Core Design Idea

Likeminded should feel like a calm, intelligent social space for people who are meant to meet.

It is not a dating app clone, not a loud community app, and not a corporate productivity tool. It should feel like:

* a private salon
* a thoughtful living room
* an editorial Apple-quality experience
* a quiet AI companion that organizes human connection
* a warm place where people feel selected, not sorted

The app should communicate:
“You do not need to chase the right people. Likeminded quietly helps you arrive in the right room.”

2. Emotional Principles

Every screen should feel:

Calm

No clutter, no noisy feeds, no aggressive notifications, no endless scrolling unless browsing is the explicit task.

Intentional

Every card should answer: “Why am I seeing this?”
Every recommendation should feel curated, not algorithmically sprayed.

Human

The product is AI-native, but the UI should not feel robotic. Avoid generic “AI assistant” aesthetics, neon gradients, sci-fi visuals, or chatbot-heavy layouts.

Premium but warm

The design should feel sophisticated and high-trust, but not cold or overly corporate.

Slightly magical

Use subtle radial glows, soft liquid glass, layered cards, and organic gradient fields to suggest that the AI is quietly understanding patterns beneath the surface.

3. Visual Metaphor

The main visual metaphor is:

Rooms, circles, signals, and resonance.

Use visual motifs like:

* soft circular glows
* layered rings
* topographic line patterns
* blurred landscape gradients
* translucent glass tiles
* gentle light sources
* subtle heart or orb shapes only where emotionally appropriate

Avoid:

* dating-app swipes as the primary design metaphor
* loud avatars and photo-first layouts
* gamified badges
* overly playful illustrations
* generic AI sparkle overload
* hard dashboards full of metrics

4. Color Direction

The palette should feel organic, warm, and premium.

Primary background

Warm cream / ivory.
Use it as the main canvas.

Recommended values:

* #FAF7F1
* #F7F1E8
* #FFFDF8

Primary accent

Deep forest green.
Use for main buttons, active navigation, key states, and important cards.

Recommended values:

* #0F4A3D
* #073C32
* #123F35

Text / ink

Use near-black with green undertone.

Recommended values:

* #0F2A25
* #17211E
* #1C1B18

Surface

Warm white, slightly translucent where appropriate.

Recommended values:

* #FFFBF7
* #FFFDF9
* rgba(255, 251, 247, 0.78)

Secondary tones

Use muted sage, clay, ochre, mist blue, and soft rose only as supporting gradient tones.

Examples:

* Sage: #C8D8C7
* Clay: #C46F4A
* Ochre: #D7B56D
* Mist blue: #B9C9C9
* Soft rose: #D9A0A7

Never use bright saturated colors unless needed for destructive actions.

5. Typography

Use system typography: SF Pro on iOS and macOS.

The typography should feel editorial, spacious, and calm.

Preferred hierarchy

Hero title:

* 30–36pt on iOS
* 36–48pt on macOS
* Semibold or bold
* Use short poetic phrases

Examples:

* “When you meet.”
* “Who you are.”
* “Your room.”
* “What you’re into.”
* “Who you connected with.”

Eyebrow labels:

* 11–12pt
* Semibold
* Uppercase
* Letter spacing
* Deep green

Body:

* 15–16pt on iOS
* 15–17pt on macOS
* Regular
* High readability

Metadata:

* 12–13pt
* Medium
* Muted ink

Avoid long technical titles. The interface should speak like a calm host, not a SaaS dashboard.

Copy rules:

* one subtitle per screen
* model prose only in Profile
* meetup info only in Meet
* interest tags only in Communities and Soulmate match detail
* hidden placement signals stay hidden outside Profile

6. Layout Philosophy

iOS

Use a 5-tab bottom navigation:

* Meet
* Circles
* Communities
* Profile
* Soulmate

Meet owns RSVP, upcoming and past meetups, and live-call entry. Circles owns the user's personality-fit circle, available circles, and the concern action. Communities owns the backend interest catalog and join state. Profile owns onboarding, voice interview, private signals, and interests. Soulmate appears only when enabled and owns opt-in matches and chat.

Tabs should feel light, glassy, and native.

macOS

Avoid a heavy left sidebar unless the screen truly needs it. Prefer a floating liquid-glass tile navigation near the bottom or bottom-center, matching the iOS tab metaphor.

The mac app should feel like an expanded spatial version of the iOS app, not a separate enterprise dashboard.

Screen structure

Most screens should follow:

1. Small eyebrow
2. Large editorial title
3. One dominant primary card
4. Supporting cards or rows
5. Floating glass navigation

Use generous margins and whitespace.
Avoid dense tables unless the task explicitly requires management or search.

7. Card System

Cards are the main UI building block.

Default card

* Warm white or translucent surface
* Rounded corners: 18–28pt
* Subtle 1pt border
* Very soft shadow
* No harsh outlines

Hero card

Used for:

* upcoming meetup
* active circle
* community detail
* voice profile
* soulmate overview

Hero cards may use:

* deep green gradient
* soft landscape-like background
* topographic line pattern
* glowing orb or light field
* white text

Glass card

Used for:

* navigation
* settings groups
* secondary controls
* overlays

Glass cards should be translucent, lightly blurred, and warm.
They should never look like frosted corporate dashboards.

8. Navigation

The navigation should feel like a calm control dock.

iOS

Bottom tab bar:

* rounded floating pill
* warm translucent glass
* selected tab uses deep green icon/text
* unselected tabs use muted ink

macOS

Use bottom floating tile navigation:

* centered pill or tile dock
* same sections as iOS
* selected item has soft green fill or icon accent
* keep it lightweight and spatial

Do not use a permanent sidebar as the default navigation pattern unless the screen is a deep management screen.

9. Motion Principles

Motion should feel like breathing, not bouncing.

Use:

* spring transitions
* fade + slide up for cards
* staggered card entrances
* subtle pulsing for voice orb
* sliding segmented controls
* soft hover lift on macOS
* gentle button press scale

Avoid:

* fast flashy animations
* confetti
* gamified reward motion
* excessive AI sparkles

10. Voice Profile Design

The voice profile is the emotional center of the app.

It should feel like the user is being gently understood.

Visual elements:

* deep green hero panel
* animated circular orb
* soft radial glow
* audio bars
* short extracted signal rows
* privacy reassurance

Language should be calm and intimate:

* “Tell me how you connect.”
* “I am listening for fit.”
* “Speak naturally. The profile updates as you talk.”
* “Profile read is private.”

Avoid making it look like a productivity transcription tool.

11. Circles Design

Circles are not groups. They are rooms.

A circle should feel like a place with emotional texture.

Use:

* names like “The Quiet Builders,” “The Thinkers’ Room,” “Open Hearts”
* landscape-inspired gradients
* room energy descriptors
* small theme chips
* “Why you fit” explanations

The user should feel:
“This room understands my pace.”

Avoid showing too many member profiles or turning circles into social feeds.

12. Communities Design

Communities are interest-led gathering spaces.

They should feel slightly more active than circles but still curated.

Use:

* rich gradient cards
* interest tags
* member count
* join/joined states
* fit labels where relevant

Communities can be browsable, but they should not feel like a marketplace of random groups.

13. Meet Design

Meet is about anticipation.

It should make the weekend feel organized and calm.

Important states:

* RSVP card
* upcoming meetup card
* pre-meet teaser
* live call
* post-meet reflection

The meetup card should be one of the most polished components in the app.

Use:

* date/time clearly
* countdown
* host
* group size
* community or circle context
* primary “Join meetup” button

Do not expose individual profiles before the meetup.
Use group-level previews only.

14. Soulmate Design

Soulmate should feel private, intentional, and non-desperate.

It should not look like Tinder, Bumble, Hinge, or a swipe-first dating app.

Principles:

* mutual selection only
* no public likes
* no pressure
* no ranking people
* no photos required in core selection flow
* names and interests over superficial browsing

The visual tone may be slightly warmer, deeper, and more intimate:

* darker plum/green background
* soft heart resonance motif
* glass match cards
* quiet chat entry points

Language examples:

* “Who you connected with.”
* “Matches are mutual.”
* “Only visible when both of you choose each other.”

15. Chat Design

Chat should be simple, quiet, and elegant.

Use:

* warm background
* green outgoing bubbles
* warm white incoming bubbles
* no loud separators
* minimal timestamps
* generous spacing
* simple composer

Avoid:

* reactions
* stickers
* gamified prompts
* overly busy chat UI

16. macOS Adaptation

The mac app should not simply stretch iOS screens.

It should use desktop space for:

* side-by-side content
* richer cards
* broader grids
* larger hero panels
* preview panels
* floating glass nav

But it should preserve:

* same emotional tone
* same colors
* same card language
* same terminology
* same navigation model

Good macOS layout pattern:

* large content canvas
* floating bottom nav
* 2-column or 3-column card layouts
* glass panels
* warm blurred background fields
* native macOS window controls
* soft depth

Avoid making the mac app look like a web admin dashboard.

17. Component Rules

Buttons

Primary:

* deep green fill
* white text
* rounded pill or 18–22pt radius
* calm, confident

Secondary:

* warm surface
* ink or deep green text
* subtle border

Destructive:

* use muted red sparingly

Toggles

Use native switches or segmented capsules.
Toggles should feel tactile and springy.

Chips

Use chips for:

* interests
* traits
* themes
* fit signals

Depth encoding:

* Deep interest: filled green
* Active interest: green outline
* Casual interest: muted warm fill

Lists

Lists should look like grouped warm cards, not raw table views.

18. Copywriting Rules

The app voice should be:

* calm
* precise
* emotionally intelligent
* private
* never needy
* never overly cute

Good copy:

* “Your room.”
* “When you meet.”
* “People who move at your pace.”
* “Profile read is private.”
* “A space for slow, honest conversations.”

Avoid:

* “Find your perfect match now!”
* “You have been ranked!”
* “AI has analyzed you!”
* “Swipe to discover people!”
* “Unlock premium connection!”

19. Privacy Language

Privacy should be visible but not scary.

Use quiet reassurance:

* “Your profile read is private.”
* “Circle placement needs confirmation.”
* “Soulmate is only visible when enabled.”
* “No one sees your signals.”

Do not overload screens with legal copy.

20. What New Screens Should Follow

When generating any new screen, the agent should ask:

1. What is the user trying to feel here?
2. Is this screen helping them arrive in the right room?
3. Is the AI quietly organizing, rather than taking over?
4. Is the layout calm and sparse?
5. Is there one clear primary action?
6. Does the screen avoid generic dating/social/dashboard patterns?
7. Does it use glass, warmth, green, and editorial typography consistently?
8. Does the screen preserve privacy and intentionality?

21. Summary Sentence for the Agent

Design every Likeminded screen as a calm, editorial, AI-native social space where people are gently understood, placed into the right rooms, and guided toward meaningful real-time connection without noise, pressure, or superficial discovery.

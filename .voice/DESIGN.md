# Likeminded Product Design and Experience Philosophy

## 1. Control Owner and Evidence Boundary

This file is the sole owner of Likeminded's product design philosophy,
experience philosophy, visual direction, and journey-level build handoffs for
iOS and macOS.

It does not own implementation constants, API contracts, release scope, privacy
policy text, mockups, or validation status. Those remain in:

- product promise and MVP scope: [GOAL.md](../GOAL.md);
- release scope:
  [production-contract.json](../validation/production-contract.json);
- screen and flow status: [validation/screens](../validation/screens/);
- visual references: [iOS mockups](../mockups/ios/) and
  [macOS mockups](../mockups/macos/);
- implementation tokens and components:
  [PrototypeComponents.swift](../apps/ios-macos/Sources/LikemindedApp/Views/Shared/PrototypeComponents.swift);
- public privacy policy:
  [privacy-policy-testflight.md](../docs/references/privacy-policy-testflight.md).

### Decision status

#### Confirmed

Source: the product promise in [GOAL.md](GOAL.md) and the invited-beta boundary
in [production-contract.json](validation/production-contract.json). These are
confirmed because they are current canonical product and release decisions.

- Voice-led understanding, AI-prepared placement, small circles, interest-led
  communities, scheduled meetings, and optional mutual Soulmate connection form
  the product loop.
- AI may prepare and suggest; the person confirms consequential sharing,
  placement, attendance, introductions, and deletion.
- The current audience is a small invited beta proving that loop on Apple
  platforms without payments or engagement-maximizing mechanics.
- The visual character is warm, restrained, editorial, private, and native.

#### Inferred from confirmed principles and platform guidance

Source: the confirmed product principles above, representative current captures,
and Apple's current layout and navigation guidance. These are safe inferences
because they preserve the same human outcomes while using native platform
conventions.

- iOS uses persistent tabs only at top-level roots.
- macOS preserves the same destinations and hierarchy through native adaptive
  sidebar, toolbar, window, menu, and keyboard behavior. A floating bottom dock
  is not the default because critical macOS controls should not depend on the
  bottom edge remaining visible.
- Exact colors, type sizes, radii, and component constants belong to the shared
  implementation-token owner, not this document.

#### Unresolved but non-blocking for the invited beta

- The final voice-interview question strategy and ideal number of turns require
  observed completion and correction data.
- The long-term audience beyond the invited beta requires evidence from the
  placement and meeting loop.

## 2. Product Promise and Non-Goals

**Product promise:** Likeminded helps people who should meet actually meet,
talk, and build relationships by privately understanding them and preparing the
right human context.

**First impression:** this feels like a quiet host who understands the purpose of
the visit, protects the person's dignity, and offers one clear next step.

Likeminded is not:

- a dating-app clone or swipe marketplace;
- a loud social feed or popularity system;
- a personality-scoring dashboard;
- a chatbot whose interface is the destination;
- a corporate scheduling or community-management tool;
- an AI demonstration, advertising surface, or engagement trap.

## 3. Governing Design Philosophy

**Technology should recede so human connection can emerge.** Likeminded quietly
understands people, helps them arrive in the right room, and preserves their
control at every meaningful step.

Design succeeds when people feel understood without feeling inspected, guided
without feeling managed, and selected without feeling ranked.

### Principles

1. **Human connection is the material.** Organize around people, rooms,
   conversation, anticipation, and reflection rather than model output or
   feature inventory.
2. **A person is never a score.** Private signals may support explanations but
   never become rankings, desirability measures, or compatibility percentages.
3. **One meaningful thing at a time.** Each screen has one human outcome, one
   dominant object, and one unmistakable primary action.
4. **AI is legible, not theatrical.** Show what was understood, why it matters,
   relevant uncertainty, and how to correct or decline.
5. **Control lives beside consequence.** Confirmation explains scope and outcome,
   not merely the button label.
6. **Native familiarity carries a distinctive feeling.** Use platform conventions
   for navigation, input, feedback, windows, and accessibility. Let identity come
   from pacing, language, and the rooms-and-resonance metaphor.
7. **Accessibility is equal expression.** Voice, motion, color, pointer, or vision
   is never the only path to meaning, control, correction, or recovery.
8. **Remove before decorating.** Every element must help someone understand,
   decide, act, or recover.

### Anti-principles

Never optimize for compulsive return, public comparison, artificial scarcity,
streaks, infinite consumption, manipulative urgency, or opaque automation.

### Award-caliber operating contract

“Award-caliber” is an internal quality bar, not a claim that the product has won
or will win an award. Every design decision must satisfy these principles:

1. **Purpose before surface.** Name the human outcome, dominant object, and one
   primary action before arranging the screen. Remove anything that competes
   with that outcome.
2. **Attention is finite.** The first viewport introduces one promise, one
   dominant object, and one obvious next step. Secondary facts, explanation,
   history, and management use progressive disclosure instead of crowding the
   customer’s first decision.
3. **Hierarchy is measurable.** A five-second glance must reveal where the
   person is, what matters now, and what to do next. Size, contrast, spacing,
   grouping, and order must agree rather than create competing focal points.
4. **Space carries meaning.** Tight spacing expresses one relationship; larger
   spacing separates decisions. Empty space is intentional only when it improves
   focus, rhythm, or emotion—not when it leaves a desktop composition unfinished.
5. **Control has one owner.** A setting, state change, or consequence appears in
   one canonical place. Other screens may explain or link to it only when that is
   necessary for the current decision; they do not duplicate management UI.
6. **Native, not identical.** Preserve the same human outcome, terminology,
   trust boundary, and state across iOS and macOS while adapting navigation,
   density, input, windows, keyboard, pointer, and disclosure to each platform.
7. **Trust is an interaction quality.** Sensitive inference and relationship
   choices show source, uncertainty, privacy scope, correction, defer, and
   recovery at the moment each becomes relevant.
8. **Inclusion is foundational craft.** Standard and Accessibility text sizes,
   VoiceOver, Increased Contrast, Differentiate Without Color, Reduce Motion,
   keyboard, pointer, and non-voice paths are designed and tested—not treated as
   final polish.
9. **Distinctiveness comes from behavior.** The signature is the quiet-host
   feeling, living reflection, and considered reveal. Ornament never substitutes
   for a memorable human transition or thoughtful use of Apple technologies.
10. **Completeness beats a beautiful happy path.** Loading, empty, partial,
    offline, error, correction, defer, destructive, and return states receive the
    same language, accessibility, and visual care as the ready state.

#### Layout contract

- **iPhone:** one reading column, comfortable safe-area participation, no
  persistent navigation over content, one dominant action per decision, and
  short supporting evidence. If a card needs a dense explanation, reveal the
  remainder in detail or behind an explicit expansion control.
- **macOS:** use the available width and height to create deliberate columns,
  preview/detail relationships, and breathing room. Scale the dominant object
  for the window; do not leave a phone-sized card stranded in a desktop canvas.
- **Both:** minimum 44×44pt touch targets where applicable; readable content may
  scroll, but names, privacy consequences, primary actions, and return paths must
  never be obscured or truncated. A hero receives deliberate space at most once.
- Any intentional exception belongs in the screen ledger with a customer reason
  and fresh visual evidence.

## 4. Experience Philosophy and Journey Arc

**Experience thesis:** move a person from uncertainty to a prepared human
connection while making the system's understanding, authority, and next action
clear and correctable.

Every important journey follows the human arc:

> uncertain → understood → placed → prepared → connected → reflected

- Teach through use rather than feature tours.
- Ask for information and permissions only when their value is clear.
- Put “Why this?” beside a recommendation and “What happens next?” beside a
  commitment.
- Distinguish what the person said from what the system inferred.
- Let people pass, defer, correct, or say “Not now” without penalty.
- Preserve completed work through loading, interruption, denial, and failure.
- End loops with a human outcome: a confirmed room, prepared meeting,
  conversation started, or reflection captured.

## 5. Audience, Context, and Trust Posture

The current audience is a small, invited TestFlight cohort evaluating a novel and
emotionally sensitive placement loop. People may be unfamiliar with personality
inference, may use the app in private or noisy environments, and may move between
phone and desktop before or during a scheduled meeting.

Design for:

- varied comfort with AI, voice recording, group meetings, and dating-adjacent
  experiences;
- intermittent connectivity and interrupted interviews or calls;
- privacy-sensitive use around other people;
- text expansion, different names and cultures, assistive technology, keyboard,
  pointer, and alternative input;
- occasional high-consideration decisions rather than high-frequency engagement.

The product earns trust by limiting claims, making audience and retention scope
visible at the point of consequence, preserving corrections, and allowing safe
exit without shame.

## 6. Product Objects and Information Architecture

The primary objects are:

- **Living profile:** private, correctable interpretations from voice and choices.
- **Circle:** a small personality-fit room proposed or confirmed for the person.
- **Community:** a browsable interest-led gathering space.
- **Meeting:** a scheduled circle or community interaction with RSVP, live room,
  and recap states.
- **Connection:** an optional mutual Soulmate relationship and its conversation.
- **Notification:** a human event or required action, never a personality report.

### iOS navigation

Use five stable top-level destinations: Meet, Circles, Communities, Profile, and
Soulmate when enabled. Tabs navigate only; they contain no create, RSVP, record,
call, or submit action. Hide them for prerequisite onboarding, focused creation,
chat, destructive confirmation, and full-screen calls.

Pushed details use native back navigation and preserve their tab context. Forms
use visible Cancel or Back plus a clear submit action. Chat uses a safe-area
composer.

### macOS navigation

Preserve the same product destinations and terminology through native adaptive
macOS navigation. Prefer a sidebar or toolbar that can collapse when appropriate,
with menu commands and keyboard shortcuts for frequent destinations.

Use desktop space for side-by-side content, preview panels, broader grids, and
window restoration. Do not force iOS tab geometry onto macOS, place critical
navigation at the bottom edge, or turn the app into an admin dashboard.

Every reachable screen provides orientation, a reliable return path, and
unobscured access to its final content and primary action.

## 7. Disclosure and Interaction Principles

Disclosure depends on when information changes a decision:

| Level | Rule |
| --- | --- |
| Persistent | Needed to orient, understand the current state, or take the next safe action |
| Contextual | Appears beside the decision whose consequence it explains |
| On demand | Useful for confidence or management but not required immediately |
| Interruptive | Blocks progress for consent, safety, permission, failure, or irreversible consequence |
| Remove | Does not help understanding, decision, action, or recovery |

The first viewport reveals orientation, human outcome, dominant object, current
state or consequence, and one primary action. History, explanation, filters,
rosters, legal detail, and secondary management appear later or on demand.

Every input receives immediate, proportionate feedback. Latency that exceeds a
moment exposes progress, cancellation when possible, and an honest recovery path.
No control may appear active if it is a placeholder.

## 8. AI Authority and Recovery

| Authority | System may | Person must be able to |
| --- | --- | --- |
| Understand | Extract tentative private signals from provided content | Review, correct, remove, or retry |
| Suggest | Prepare circles, communities, hosts, people, and next steps | See why, decline, defer, or request another option |
| Prepare | Draft placement, meeting context, prompts, and recaps | Preview and edit before consequential sharing |
| Act | Refresh private suggestions and perform reversible preparation | Understand the action and undo or recover |
| Commit | Never commit sharing, placement, attendance, introduction, or deletion alone | Give explicit approval with audience and consequence visible |

System interpretation is visually and verbally distinct from user-provided fact.
Failure never turns uncertainty into certainty. If model, network, or tool work
fails, preserve user input, explain what remains true, and offer retry, correction,
or safe exit.

## 9. Critical-Journey Build Handoffs

These contracts preserve product intent. Implementation and current proof status
remain with their linked owners.

### Shared handoff rules

- Each entry route exposes a unique semantic arrival marker.
- Persistent navigation participates in layout and never covers content.
- Async hydration may enrich content but must not move a focused or consequential
  control without preserving context.
- Every journey supports standard and Accessibility text sizes, VoiceOver,
  Reduce Motion, Increased Contrast, keyboard or pointer where applicable, and a
  non-voice correction path.
- Back, cancel, interruption, and relaunch preserve completed work unless privacy
  or explicit cancellation requires clearing it.
- Offline and timeout states preserve entered content and the last confirmed
  state, identify what may be stale, and never simulate a successful mutation.
- The outcome, hierarchy, and trust boundary remain the same on iOS and macOS;
  navigation, windows, keyboard, pointer, and presentation adapt natively.

| Journey | Entry and arrival | Primary action and postcondition | States and recovery |
| --- | --- | --- | --- |
| Sign in and restore | Signed-out launch; Apple sign-in promise is visible | Sign in; authenticated session restores without repeating setup | Cancel preserves signed-out state; revoked credentials sign out; transient checks preserve the session |
| Voice to placement | Signed-in person without a completed living profile; private voice prompt is visible | Finish or preview the interview, review interpretations, then confirm or decline placement | Permission denial offers text/retry; interruption preserves progress; inference remains correctable |
| Circle decision | Proposed or confirmed circle; room identity and reason are visible | Enter, confirm, request refresh, or raise concern; placement state updates visibly | Loading never implies placement; failure preserves the prior room; refresh explains its consequence |
| Community participation | Community browse or detail; join state is visible | Join, leave, create, or schedule an event; persisted membership or event is visible on return | Either initial membership state is valid; failed mutation restores the prior state and offers retry |
| Scheduled meeting | RSVP or upcoming meeting; time, room, people, and current availability are visible | RSVP, join, control media, leave, and rejoin; connection state and exit remain visible | Permission, connecting, reconnecting, room unavailable, and failed join provide retry and safe exit |
| Mutual connection | Soulmate opt-in or pending selection; mutual/private rule is visible | Select or pass; a mutual result creates a private conversation | No match is neutral; selection is correctable before commitment; failed send preserves the draft |
| Account safety | Settings, report/block, or deletion entry; scope and consequence are visible | Confirm report, block, sign out, or deletion; protected access reflects the result | Cancellation changes nothing; failed deletion preserves account and session; destructive success is explicit |

### Dependency and acceptance owners

| Concern | Owner and required evidence |
| --- | --- |
| Product and MVP scope | [GOAL.md](GOAL.md); journey remains inside the invited-beta promise |
| Release boundary | [production contract](validation/production-contract.json); deferred features stay absent or honestly unavailable |
| Native screen behavior | [screen ledgers](validation/screens/); semantic postcondition plus current-source proof |
| Visual references | [iOS](mockups/ios/) and [macOS](mockups/macos/) mockups; standard and Accessibility capture comparison |
| Components and tokens | [PrototypeComponents.swift](apps/ios-macos/Sources/LikemindedApp/Views/Shared/PrototypeComponents.swift); build plus representative rendered readback |
| Privacy language and lifecycle | [privacy policy owner](docs/references/privacy-policy-testflight.md); public policy and in-app consequence agree |

## 10. Visual Identity and Theme

Likeminded is restrained, warm, editorial, airy, serious without coldness, and
familiar in operation while distinctive in emotional pacing.

The visual metaphor is **rooms, circles, signals, and resonance**. Use layered
rings, topographic lines, soft landscape fields, restrained translucency, and
gentle light where they explain relationship or space. Avoid generic AI sparkles,
gamified badges, photo-first dating layouts, hard dashboards, and ornamental
glass.

### Signature experiences

**Living reflection:** during and after voice conversation, sparse words and
phrases reflect what the person chose to share. Every interpretation remains
reviewable and correctable, and meaning remains complete without motion.

**Considered reveal:** a circle or relationship suggestion reveals shared human
texture, the room or people, and then the reason for fit. It feels like a thoughtful
introduction, never an algorithmic result or reward.

## 11. Semantic Visual System

This document owns semantic behavior; the shared component source owns exact
implementation values.

- **Color:** warm cream canvas, deep green action and selected state, dark green
  or near-black ink, warm light surfaces, and muted natural supporting tones.
  Destructive state uses a distinct accessible red role.
- **Typography:** one short editorial serif display voice and a native sans-serif
  interface voice. Long copy, controls, status, and forms remain sans-serif.
- **Spacing:** compact relationships are tight; sections breathe; a hero receives
  deliberate space at most once per screen. Empty space never substitutes for
  hierarchy.
- **Geometry:** calm rounded surfaces, native controls, subtle borders, and depth
  only when it clarifies grouping or elevation.
- **Imagery:** atmospheric room and landscape imagery may establish texture;
  people are not reduced to a photo marketplace.
- **Iconography:** use familiar platform symbols with visible labels for
  navigation and ambiguous actions.

Names, destructive consequences, privacy scope, recovery, and primary actions
never truncate. Text reflows rather than shrinking to preserve composition.

## 12. Motion, Haptics, and Sound

Motion explains, confirms, or preserves continuity. Use restrained fades,
position changes, and rare spring response for direct manipulation. Voice activity
may pulse gently; a relationship reveal may receive one deliberate transition.

Reduced Motion replaces pulsing, parallax, and travel with opacity or no animation.
Haptics and sound confirm only meaningful state changes and always have visible
or textual equivalents. Never use confetti, reward motion, or continuous
decorative animation.

## 13. Content Voice and Terminology

The voice is calm, precise, emotionally intelligent, private, and never needy,
technical, judgmental, or overly cute.

Prefer invitations and plain consequences:

- “Your room.”
- “When you meet.”
- “Your profile read is private.”
- “Matches are mutual.”
- “What we understood.”

Avoid ranking, certainty, urgency, or generic AI language such as “perfect match,”
“AI analyzed you,” “unlock,” or “high compatibility.” Errors say what remains
safe, what failed, and what the person can do next.

## 14. Accessibility and Inclusion

- Minimum interactive target is 44×44pt on touch platforms.
- Every nondecorative control has a meaningful label, value, hint when needed,
  and logical reading order.
- State uses text or symbol in addition to color.
- Accessibility text sizes preserve every consequence, primary action, and return
  path without overlap.
- Voice has text, review, correction, and retry alternatives.
- Live meetings provide understandable permission, connection, participant,
  media-control, and exit states without relying on audio or video alone.
- macOS supports keyboard navigation, focus visibility, pointer, menus, window
  resizing, and restoration.
- Dates, names, relationship language, and examples allow localization and
  cultural variation without stereotyping.

## 15. Responsive and Platform Adaptation

Preserve human outcome, object hierarchy, terminology, trust boundary, and state
across platforms. Do not force identical layouts.

On iPhone, prioritize one-column comprehension, reachable controls, safe-area
participation, and full-scroll access. On macOS, reflow into columns or
master-detail presentation when width supports it, use native window and command
behavior, and avoid bottom-edge dependence.

The first content baseline follows the platform safe area or navigation region.
Scrollable content reserves the measured height of every persistent element plus
comfortable separation. Keyboard, pointer, sheet, window chrome, and text growth
must not hide the primary action or final row.

## 16. State, Privacy, Safety, and Dignity

Every applicable journey defines initial, empty, loading, partial, ready, success,
offline, reconnecting, permission-denied, blocked, error, correction, deletion,
and return states. Empty states explain value and one next action. Errors preserve
completed work and provide an honest recovery path.

| Data class | Design rule |
| --- | --- |
| User-provided profile content | Show its private scope and allow review, correction, and deletion |
| System interpretations | Label as working interpretations; expose reason, uncertainty, correction, and removal |
| Voice and transcripts | Explain active processing, retention owner, and deletion path before or beside use |
| Communities, meetings, and messages | Show audience and sharing consequence before publication or send |
| Live audio and video | Request permission in context; distinguish local preview, connecting, live, and ended states |
| Account and authentication | Keep sign-out reversible; make deletion scope explicit and preserve state on failure |

Blocking, reporting, moderation, withdrawal, and deletion are reachable near the
relevant person, room, content, or account. Declined, unmatched, empty, and failure
states never shame the person.

## 17. Screen-Family Hierarchy

| Family | Immediately visible | Later or on demand | Never dominant |
| --- | --- | --- | --- |
| Authentication | Promise, one supporting sentence, Apple sign-in, privacy reassurance | Alternatives, terms, recovery | Feature checklist or future inventory |
| Onboarding | Current step, why it matters, one action, progress, optional skip | Interview, interests, placement explanation | Tabs or recording before consent |
| Meet | Next state, date/time, RSVP or join, reliable exit when live | History, attendance, notes, recap | Personality signals or competing heroes |
| Circles | Current room, status, reason, enter or review action | Alternatives, fit explanation, concern | Scores, full roster, unqualified fit claims |
| Communities | Joined state, browse distinction, clear join or create action | Filters, resources, members, event creation | Personality composition or marketplace density |
| Profile | Private summary, completion, review or update action | Signals, interests, transcript, settings | Public-looking scores or fixed declarations |
| Soulmate | Opt-in, mutual/private rule, matches or selection | History, explanation, settings | Ranking, swipes, guaranteed-match language |
| Chat | Person, relationship context, messages, return, composer | Calls, info, report/block | Global dock or purposeless blank space |
| Notifications | Human events, unread state, direct destination | Preferences and history | Inferred personality labels |
| Settings | Identity, privacy, accessibility, support | Legal and advanced controls | Equal emphasis for routine and destructive actions |

## 18. New-Screen Decision Filter

Before accepting a new screen or interaction, ask:

1. What human outcome does it advance now?
2. What should the person understand, feel, and do without instruction?
3. Is there one dominant object and one primary action?
4. Can anything be removed without weakening trust or recovery?
5. Does AI explain understanding, reason, uncertainty, and next action?
6. Is consequential control beside the consequence?
7. Are entry, postcondition, error, correction, and return explicit?
8. Does it adapt to supported text sizes, assistive technology, reduced motion,
   increased contrast, keyboard, pointer, and non-color cues?
9. Does evidence prove the named state rather than merely show a successful
   launch or build?
10. Does it avoid generic dating, feed, chatbot, dashboard, and AI-demo patterns?

A screen fails if it is attractive but obscures the next action, feels native but
emotionally generic, or completes a task while weakening trust.

## 19. Validation and Governance

Build success is not visual or behavioral proof. Each named route must expose a
unique semantic marker and achieve its expected postcondition.

Acceptance requires independent evidence for:

- philosophical fit and the intended human outcome;
- understandable, controllable, recoverable journey behavior;
- hierarchy, visual craft, responsiveness, and platform adaptation;
- representative end-to-end accessibility behavior;
- AI explanation, consent, correction, and reversal;
- current-source standard and Accessibility captures compared with the canonical
  reference, including the full scroll extent.

Do not stamp a pass from a screenshot when the flow requires interaction or
persistence. Do not treat an accepted input dispatch as an outcome. Async controls
must be visible and stable enough to activate semantically; fixture state must not
assume a previous test's final condition.

### Mandatory agent design workflow

For every visual or interaction change, agents must:

1. Load the target screen ledger, its declared source files, this design owner,
   and only the named reference capture.
2. State the customer job, dominant object, primary action, and applicable trust
   consequence in one sentence before editing.
3. Classify proposed content as persistent, contextual, on demand, interruptive,
   or remove. Delete duplication before adding layout.
4. Reuse the existing semantic tokens and components, then implement the smallest
   cross-platform change that preserves the same outcome without forcing the same
   geometry.
5. Build the changed platform and capture the current source at the default size,
   full scroll extent, and representative Accessibility text size. Capture the
   paired platform when parity is part of the change.
6. Prove every consequential or stateful control through its named ledger flow;
   screenshots alone prove only appearance.
7. Freeze the references and current captures into one immutable review packet.
   Run fresh, independent UI and UX reviews after every source change.
8. Accept only when no P0–P2 review issue remains, content clears persistent
   navigation, accessibility evidence is current, and the ledger records the
   source hash and intentional differences.

An agent may call a screen **award-caliber ready** only when the complete workflow
above passes for its full state set. The product may be called **award-caliber
ready** only when every supported screen family and critical journey passes on
both platforms. “Award-winning” remains reserved for actual external recognition.

## 20. Explicit Deferrals and Reconsideration Triggers

| Deferred | Reconsider when |
| --- | --- |
| Payments and subscriptions | The invited beta proves recurring value and the user explicitly authorizes monetization work |
| Push-notification delivery | Scheduled-meeting retention requires it and notification scope is approved |
| Public TestFlight link or open discovery | Invite-only safety, moderation, and support operations are proven |
| Full community engine | Browsing, joining, moderation, and event creation are reliable with the invited cohort |
| Server-to-server Apple events | Native lifecycle coverage is proven and scale requires stronger off-device revocation handling |
| Final voice-interview script | Completion, correction, abandonment, and placement-quality evidence is available |

## 21. Research Basis

This direction follows current Apple guidance for hierarchy, layout, onboarding,
accessibility, adaptive navigation, and platform-specific behavior. Apple Design
Award work is inspiration for focus, inclusivity, interaction, and craft, never
a visual template.

- <https://developer.apple.com/design/human-interface-guidelines>
- <https://developer.apple.com/design/human-interface-guidelines/design-principles>
- <https://developer.apple.com/design/human-interface-guidelines/accessibility>
- <https://developer.apple.com/design/human-interface-guidelines/onboarding>
- <https://developer.apple.com/design/human-interface-guidelines/layout>
- <https://developer.apple.com/design/human-interface-guidelines/tab-bars>
- <https://developer.apple.com/design/awards/>
- <https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/>

## Summary for Agents

Design every Likeminded experience so technology recedes, the next human step is
clear, and people feel understood, in control, and quietly guided toward the right
room.

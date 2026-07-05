#!/usr/bin/env node
// Scaffolds the validation artifact tree from the screen inventories.
// One MD + one JSON per screen. All `result` fields start as "pending".
// Re-run any time; overwrites only its own generated files.

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname);
const IOS = path.join(ROOT, "ios");
const MAC = path.join(ROOT, "macos");

function ensureDir(d) {
  fs.mkdirSync(d, { recursive: true });
}

// ---------- Screen definitions ----------
// Each screen: { id, name, source, mockup (nullable), entry[], backend[], controls[], notes }
// controls[]: { id, type, label, expected, stub?:bool, blocker?:string }

const iosScreens = [
  {
    id: "01-auth-gate",
    name: "Auth Gate (Sign in with Apple)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/AuthGateView.swift"],
    mockup: "mockups/ios/01-04-onboarding-voice-meet-soulmate.png",
    entry: ["App launch when no signed-in session"],
    backend: ["Apple Sign In credential → AuthSessionStore.signIn"],
    controls: [
      { id: "sign-in-apple", type: "button", label: "Sign in with Apple", expected: "Authenticates via Apple ID, creates session, advances to onboarding or app", blocker: "Real Apple ID unavailable in simulator without TestFlight creds" },
      { id: "promise-rows", type: "display", label: "Voice profile / Private by design / Circle placement rows", expected: "Display-only promise copy" },
    ],
  },
  {
    id: "02-onboarding",
    name: "Onboarding Wizard (name → gender → DOB → city → pincode)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/OnboardingView.swift"],
    mockup: "mockups/ios/01-04-onboarding-voice-meet-soulmate.png",
    entry: ["First launch after sign-in", "Profile tab when basicInfo is nil"],
    backend: ["POST /v1/me/profile (via appState.completeOnboarding)"],
    controls: [
      { id: "progress-dots", type: "display", label: "Progress dots", expected: "Reflects current step" },
      { id: "field-name", type: "text", label: "Your name (step 0)", expected: "Capture name, enables Continue when non-empty" },
      { id: "field-gender", type: "button-group", label: "Gender cards (step 1)", expected: "Selects one of Male/Female/Non-binary/Prefer not to say" },
      { id: "field-dob", type: "picker", label: "Date of birth wheel (step 2)", expected: "Capture DOB" },
      { id: "field-city", type: "text", label: "City (step 3)", expected: "Capture city" },
      { id: "field-pincode", type: "text", label: "Pincode numeric (step 4)", expected: "Capture pincode (numeric)" },
      { id: "continue", type: "button", label: "Continue / Start voice profile", expected: "Advances step; on last step saves profile and starts voice session" },
    ],
  },
  {
    id: "03-profile-empty",
    name: "Profile (empty — voice interview hero)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/ProfilePrototypeView.swift (VoiceProfileView)"],
    mockup: "mockups/ios/01-04-onboarding-voice-meet-soulmate.png",
    entry: ["Profile tab after onboarding, before voice session"],
    backend: ["GET /v1/me/profile"],
    controls: [
      { id: "pencil-settings", type: "nav-link", label: "Pencil icon → Settings", expected: "Pushes SettingsPrototypeView" },
      { id: "start-voice", type: "button", label: "Start voice profile", expected: "Opens voice session sheet and calls startVoiceSession" },
    ],
  },
  {
    id: "04-profile-populated",
    name: "Profile (populated — signals + interests + update)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/ProfilePrototypeView.swift (VoiceProfileView)"],
    mockup: "mockups/ios/17-20-profile-community-settings.png",
    entry: ["Profile tab when profile exists"],
    backend: ["GET /v1/me/profile"],
    controls: [
      { id: "update-profile", type: "button", label: "Update profile", expected: "Reopens voice session sheet" },
      { id: "signal-pills", type: "display", label: "Communication/Energy/Trust pills", expected: "Show profile signals (display only, no tap)" },
      { id: "comm-read-card", type: "display", label: "Communication read card with chevron", expected: "Display only; chevron is decorative, no tap action (STUB)" },
      { id: "trait-bars", type: "display", label: "Big Five TraitBars", expected: "Render trait bars from slice.signals.bigFive" },
      { id: "interest-chips", type: "display", label: "Interest tag chips", expected: "Render interests with depth encoding" },
    ],
  },
  {
    id: "05-profile-concern",
    name: "Profile (re-interview prompt when concernFlag set)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/ProfilePrototypeView.swift"],
    mockup: "mockups/ios/29-profile-concern.png",
    entry: ["Auto-routed here from Circles concern button"],
    backend: ["GET /v1/me/profile (concernFlag)"],
    controls: [
      { id: "start-reinterview", type: "button", label: "Start re-interview", expected: "Opens voice session sheet, calls startReinterview (appends signals)" },
    ],
  },
  {
    id: "06-voice-session-sheet",
    name: "Voice Profile Session Sheet",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/ProfilePrototypeView.swift (VoiceProfileSessionSheet)"],
    mockup: "mockups/ios/01-04-onboarding-voice-meet-soulmate.png",
    entry: ["Sheet from Profile Start voice / Update / Re-interview"],
    backend: ["POST /v1/realtime/calls", "POST /v1/realtime/profile-placement"],
    controls: [
      { id: "voice-orb", type: "display", label: "Voice orb (idle/listening/processing/captured)", expected: "Animates with audio amplitude" },
      { id: "stop", type: "button", label: "Stop", expected: "Calls stopVoiceSession; persists profile" },
      { id: "done", type: "button", label: "Done", expected: "Dismisses sheet" },
    ],
  },
  {
    id: "07-meet",
    name: "Meet (RSVP + upcoming + past)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/MeetView.swift"],
    mockup: "mockups/ios/05-08-circles-meet-communities.png",
    entry: ["Meet tab"],
    backend: ["GET /v1/meetings/upcoming", "GET /v1/meetings/past", "POST /v1/meetings/rsvp"],
    controls: [
      { id: "bell", type: "button", label: "Bell icon (top-right)", expected: "Opens NotificationsView sheet; badge shows unread" },
      { id: "rsvp-sat-yes", type: "button", label: "Saturday Available", expected: "POST rsvp community available=true" },
      { id: "rsvp-sat-no", type: "button", label: "Saturday Not", expected: "POST rsvp community available=false" },
      { id: "rsvp-sun-yes", type: "button", label: "Sunday Available", expected: "POST rsvp circle available=true" },
      { id: "rsvp-sun-no", type: "button", label: "Sunday Not", expected: "POST rsvp circle available=false" },
      { id: "join-upcoming", type: "nav-link", label: "Join live room (upcoming)", expected: "Pushes GroupVideoCallView; disabled until meetup time", blocker: "LiveKit server + LIVEKIT_* env not provisioned locally" },
      { id: "past-row", type: "nav-link", label: "Past meet row", expected: "Pushes PastMeetDetailView" },
    ],
  },
  {
    id: "08-past-meet-detail",
    name: "Past Meet Detail (recap)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/MeetView.swift (PastMeetDetailView)"],
    mockup: "mockups/ios/09-12-meet-video-postmeet.png",
    entry: ["Past meet row on Meet tab"],
    backend: ["POST /v1/meetings/:id/recap-note"],
    controls: [
      { id: "reflection-note", type: "text", label: "Reflection note field", expected: "Editable text bound to reflectionNote" },
      { id: "save-note", type: "button", label: "Save note", expected: "Persists note via recap-note endpoint" },
      { id: "select-connections", type: "button", label: "Select connections (when soulmate enabled)", expected: "Opens SoulmateSelectionDialog" },
    ],
  },
  {
    id: "09-group-video-call",
    name: "Group Video Call (LiveKit)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/MeetView.swift (GroupVideoCallView)"],
    mockup: "mockups/ios/09-12-meet-video-postmeet.png",
    entry: ["Join live room from Upcoming meet card"],
    backend: ["POST /v1/meetings/:id/join (LiveKit token)"],
    controls: [
      { id: "tiles", type: "display", label: "Participant tiles grid", expected: "LazyVGrid of Participant camera tiles" },
      { id: "mute", type: "button", label: "Mic mute toggle", expected: "Toggles localParticipant microphone" },
      { id: "leave", type: "button", label: "Leave (destructive)", expected: "Disconnects room" },
    ],
    notes: "Entire screen blocked locally without LiveKit server + LIVEKIT_URL/API_KEY/SECRET.",
  },
  {
    id: "10-circles",
    name: "Circles (your circle + available + concern)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/CommunitiesPrototypeView.swift (CirclesPrototypeView)"],
    mockup: "mockups/ios/05-08-circles-meet-communities.png",
    entry: ["Circles tab"],
    backend: ["GET /v1/me/placement", "GET /v1/circles"],
    controls: [
      { id: "hero-circle", type: "button", label: "Your circle hero card", expected: "Opens CircleDetailView fullScreenCover" },
      { id: "concern-btn", type: "button", label: "This doesn't feel like my circle", expected: "Reveals concern TextField" },
      { id: "concern-field", type: "text", label: "Concern text field", expected: "Capture concern detail" },
      { id: "concern-submit", type: "button", label: "Continue in Profile", expected: "Sends concern, sets concernFlag, routes to Profile" },
      { id: "browse-card", type: "button", label: "Available circle card", expected: "Opens CircleDetailView fullScreenCover" },
      { id: "plus-icon", type: "display", label: "+ icon (top-right)", expected: "DISPLAY ONLY — plain Image, no Button, no action (STUB)" },
    ],
  },
  {
    id: "11-circle-detail",
    name: "Circle Detail (fullScreenCover)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/CommunitiesPrototypeView.swift (CircleDetailView)"],
    mockup: "mockups/ios/05-08-circles-meet-communities.png",
    entry: ["Your circle hero card", "Available circle card"],
    backend: ["GET /v1/circles/:id"],
    controls: [
      { id: "back", type: "button", label: "Back to circles", expected: "Dismisses cover" },
      { id: "detail-rows", type: "display", label: "Members / socialFormat rows with chevron", expected: "Display only; chevron decorative, no tap (STUB)" },
      { id: "leave-circle", type: "button", label: "Leave circle", expected: "STUB — bare SecondaryActionButton label, no Button/action wired" },
    ],
  },
  {
    id: "12-communities",
    name: "Communities (browse + search)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/CommunitiesPrototypeView.swift (CommunitiesPrototypeView)"],
    mockup: "mockups/ios/05-08-circles-meet-communities.png",
    entry: ["Communities tab"],
    backend: ["GET /v1/communities", "GET /v1/me/communities"],
    controls: [
      { id: "search", type: "text", label: "Search communities", expected: "Filters catalog by name/summary/themes" },
      { id: "joined-card", type: "nav-link", label: "Your communities card", expected: "Pushes CommunityDetailView" },
      { id: "browse-card", type: "nav-link", label: "Browse community card", expected: "Pushes CommunityDetailView" },
    ],
  },
  {
    id: "13-community-detail",
    name: "Community Detail",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/CommunitiesPrototypeView.swift (CommunityDetailView)"],
    mockup: "mockups/ios/13-16-soulmate-chat.png",
    entry: ["Community card nav"],
    backend: ["GET /v1/communities/:id", "POST /v1/communities/:id/join", "POST /v1/communities/:id/leave"],
    controls: [
      { id: "back", type: "button", label: "Back chevron", expected: "Dismisses/pops" },
      { id: "ellipsis", type: "display", label: "Ellipsis icon", expected: "STUB — Image only, no Button/action" },
      { id: "join-leave", type: "button", label: "Join community / Leave community", expected: "Toggles membership via backend; updates member count" },
    ],
  },
  {
    id: "14-soulmate",
    name: "Soulmate (overview + matches)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SoulmateView.swift (SoulmatePrototypeView)"],
    mockup: "mockups/ios/13-16-soulmate-chat.png",
    entry: ["Soulmate tab (visible when soulmateEnabled)"],
    backend: ["GET /v1/me/soulmate/status", "GET /v1/me/soulmate/matches"],
    controls: [
      { id: "enable-toggle", type: "toggle", label: "Enable Soulmate", expected: "Shows/hides tab; POST /soulmate/enable" },
      { id: "post-meet-select", type: "button", label: "Post-meet selection (when pending)", expected: "Opens SoulmateSelectionDialog" },
      { id: "match-row", type: "nav-link", label: "Match row", expected: "Pushes SoulmateMatchDetailView" },
      { id: "conversations-icon", type: "nav-link", label: "Conversations icon (bubble.right)", expected: "Pushes ConversationListView" },
    ],
  },
  {
    id: "15-soulmate-match-detail",
    name: "Soulmate Match Detail",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SoulmateView.swift (SoulmateMatchDetailView)"],
    mockup: "mockups/ios/13-16-soulmate-chat.png",
    entry: ["Soulmate match row"],
    backend: ["GET /v1/me/soulmate/matches/:id"],
    controls: [
      { id: "start-chat", type: "nav-link", label: "Start chat", expected: "Pushes ChatView(match:)" },
      { id: "chat-icon", type: "nav-link", label: "Chat icon (top-right)", expected: "Pushes ChatView(match:)" },
      { id: "interest-chips", type: "display", label: "Interest chips (depth-encoded)", expected: "Shows other person's interests" },
    ],
  },
  {
    id: "16-chat",
    name: "Chat (match thread)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SoulmateView.swift (ChatView)"],
    mockup: "mockups/ios/13-16-soulmate-chat.png",
    entry: ["SoulmateMatchDetail Start chat / Chat icon", "ConversationList row"],
    backend: ["GET /v1/me/soulmate/matches/:id/messages", "POST /v1/me/soulmate/matches/:id/messages"],
    controls: [
      { id: "message-list", type: "display", label: "Message bubbles", expected: "Green outgoing / warm incoming; polls every 3s" },
      { id: "draft", type: "text", label: "Message input (vertical)", expected: "Editable draft, lineLimit 1...4" },
      { id: "send", type: "button", label: "Send (arrow.up.circle.fill)", expected: "POST message; disabled when draft empty" },
    ],
  },
  {
    id: "17-conversations",
    name: "Conversations List",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SoulmateView.swift (ConversationListView)"],
    mockup: "mockups/ios/13-16-soulmate-chat.png",
    entry: ["Soulmate tab conversations icon"],
    backend: ["GET /v1/me/soulmate/matches"],
    controls: [
      { id: "conv-row", type: "nav-link", label: "Conversation row", expected: "Pushes ChatView for that match" },
    ],
  },
  {
    id: "18-soulmate-selection",
    name: "Soulmate Selection Dialog (post-meet)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SoulmateView.swift (SoulmateSelectionDialog)"],
    mockup: "mockups/ios/30-soulmate-selection.png",
    entry: ["Past meet detail Select connections", "Soulmate Post-meet selection"],
    backend: ["POST /v1/me/soulmate/select"],
    controls: [
      { id: "match-toggle", type: "button", label: "Potential match row (multi-select)", expected: "Toggles selection in selectedUserIds" },
      { id: "submit", type: "button", label: "Submit", expected: "POST selection; creates mutual matches; disabled when empty" },
    ],
  },
  {
    id: "19-notifications",
    name: "Notifications + Activity",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/NotificationsView.swift"],
    mockup: "mockups/ios/31-notifications.png",
    entry: ["Bell icon on Meet tab"],
    backend: ["GET /v1/me/notifications"],
    controls: [
      { id: "filter-pills", type: "button-group", label: "All / Meets / Matches / Messages", expected: "Filters notification list" },
      { id: "done", type: "button", label: "Done", expected: "Dismisses sheet" },
      { id: "row", type: "display", label: "Notification row", expected: "Display only; no tap action wired (STUB)" },
    ],
  },
  {
    id: "20-settings",
    name: "Settings",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SettingsPrototypeView.swift"],
    mockup: "mockups/ios/17-20-profile-community-settings.png",
    entry: ["Profile pencil icon"],
    backend: ["POST /v1/feedback (contact support)", "POST /v1/me/soulmate/enable (toggle)", "DELETE /v1/me/account"],
    controls: [
      { id: "soulmate-toggle", type: "toggle", label: "Enable Soulmate", expected: "Toggles soulmate tab visibility" },
      { id: "how-it-works", type: "button", label: "How it works", expected: "Opens SettingsInfoSheet" },
      { id: "sign-out", type: "button", label: "Sign out (destructive)", expected: "Shows confirmation; on confirm calls signOut" },
      { id: "delete-account", type: "button", label: "Delete account (destructive)", expected: "Shows confirmation; on confirm calls DELETE /v1/me/account and clears local session" },
      { id: "privacy", type: "button", label: "Privacy policy", expected: "Opens PrivacyPolicySheet" },
      { id: "help", type: "button", label: "Help & FAQ", expected: "Opens SettingsInfoSheet" },
      { id: "support", type: "button", label: "Contact support", expected: "Opens ContactSupportSheet" },
    ],
  },
  {
    id: "21-settings-privacy",
    name: "Privacy Policy Sheet",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SettingsPrototypeView.swift (PrivacyPolicySheet)"],
    mockup: "mockups/ios/32-settings-privacy.png",
    entry: ["Settings Privacy policy row"],
    backend: [],
    controls: [
      { id: "done", type: "button", label: "Done", expected: "Dismisses sheet" },
    ],
  },
  {
    id: "22-settings-info",
    name: "Settings Info Sheet (How it works / Help & FAQ)",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SettingsPrototypeView.swift (SettingsInfoSheet)"],
    mockup: "mockups/ios/33-settings-info.png",
    entry: ["Settings How it works / Help & FAQ rows"],
    backend: [],
    controls: [
      { id: "done", type: "button", label: "Done", expected: "Dismisses sheet" },
    ],
  },
  {
    id: "23-settings-support",
    name: "Contact Support Sheet",
    source: ["apps/ios-macos/Sources/LikemindedApp/Views/SettingsPrototypeView.swift (ContactSupportSheet)"],
    mockup: "mockups/ios/34-settings-support.png",
    entry: ["Settings Contact support row"],
    backend: ["POST /v1/feedback"],
    controls: [
      { id: "message", type: "text", label: "What needs help? field", expected: "Editable support message" },
      { id: "send", type: "button", label: "Send support note", expected: "POST feedback; disabled when empty" },
      { id: "done", type: "button", label: "Done", expected: "Dismisses sheet" },
    ],
  },
];

const macScreens = [
  {
    id: "01-welcome",
    name: "Welcome / Sign in with Apple",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (welcome)"],
    mockup: "mockups/macos/01-04-auth-meet-circles-profile.png",
    entry: ["App launch when not signed in"],
    backend: ["Apple Sign In via appState.signInWithApple"],
    controls: [
      { id: "sign-in-apple", type: "button", label: "Sign in with Apple", expected: "Authenticates and loads profile+placement", blocker: "Real Apple ID unavailable without TestFlight creds" },
    ],
  },
  {
    id: "02-meet-overview",
    name: "Meet Overview",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (meetOverview)"],
    mockup: "mockups/macos/01-04-auth-meet-circles-profile.png",
    entry: ["Meet tab", "⌘1"],
    backend: ["GET /v1/meetings/upcoming", "GET /v1/meetings/past", "POST /v1/meetings/rsvp"],
    controls: [
      { id: "join-meetup", type: "button", label: "Join meetup (hero)", expected: "Navigate → meetRecap (when upcoming exists)", blocker: "LiveKit join not exercised; route goes to recap, not video room, in this build" },
      { id: "rsvp-sat-yes", type: "button", label: "Saturday Available pill", expected: "POST rsvp community available=true" },
      { id: "rsvp-sat-no", type: "button", label: "Saturday Not pill", expected: "POST rsvp community available=false" },
      { id: "rsvp-sun-yes", type: "button", label: "Sunday Available pill", expected: "POST rsvp circle available=true" },
      { id: "rsvp-sun-no", type: "button", label: "Sunday Not pill", expected: "POST rsvp circle available=false" },
      { id: "past-row", type: "button", label: "Past meeting row", expected: "Navigate → meetRecap" },
    ],
  },
  {
    id: "03-circles-room",
    name: "Circles Room",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (circlesRoom)"],
    mockup: "mockups/macos/01-04-auth-meet-circles-profile.png",
    entry: ["Circles tab", "⌘2"],
    backend: ["GET /v1/me/placement", "GET /v1/circles"],
    controls: [
      { id: "concern-btn", type: "button", label: "This doesn't feel like my circle", expected: "Calls reportCircleConcern('') — STUB: empty string, no input field wired" },
      { id: "circle-card", type: "display", label: "Circle cards (horizontal scroll)", expected: "STUB — plain VStack, not a Button, no tap action" },
    ],
  },
  {
    id: "04-circle-detail",
    name: "Circle Detail (communityDetail memberMode)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (circleDetail → communityDetail(memberMode:true))"],
    mockup: "mockups/macos/05-08-chat-communities-detail-recap.png",
    entry: ["Circle card (currently inert — see circlesRoom STUB)"],
    backend: ["GET /v1/circles/:id"],
    controls: [
      { id: "view-members", type: "display", label: "View members button", expected: "STUB — suppressed when memberMode; screen has ZERO interactive controls" },
    ],
    notes: "Entire screen non-interactive in current build. Reuses communityDetail body with memberMode:true which suppresses the only button.",
  },
  {
    id: "05-profile-edit",
    name: "Profile Edit (trait sliders)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (profileEdit)"],
    mockup: "mockups/macos/09-12-profile-soulmate-discover-detail.png",
    entry: ["Profile share-profile flow"],
    backend: [],
    controls: [
      { id: "comm-pills", type: "display", label: "Communication/Energy/Trust pills", expected: "STUB — hard-coded 'Communication' selected, no action" },
      { id: "trait-sliders", type: "slider", label: "5 trait sliders (Reserved/Outgoing, Analytical/Intuitive, Low/High Energy, Steady/Spontaneous, Slow/Fast Trust)", expected: "STUB — all 5 share single local profileTraitValue=0.55; not persisted" },
      { id: "save", type: "button", label: "Save profile edits", expected: "Navigate → myProfile; does NOT actually save trait values" },
    ],
  },
  {
    id: "06-chat",
    name: "Chat (Chats, compact:false)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (chat(title:'Chats', compact:false))"],
    mockup: "mockups/macos/05-08-chat-communities-detail-recap.png",
    entry: ["Title-action button (bubble icon) from most screens", "Soulmate Detail Message"],
    backend: ["GET /v1/me/soulmate/matches/:id/messages", "POST /v1/me/soulmate/matches/:id/messages"],
    controls: [
      { id: "match-row", type: "button", label: "Match row (left list)", expected: "Sets selectedChatMatchId; loads messages" },
      { id: "draft", type: "text", label: "Message input (MacChatComposer)", expected: "Editable draft" },
      { id: "send", type: "button", label: "Send (arrow.up.circle.fill)", expected: "POST message + reload; disabled when !canSend" },
    ],
  },
  {
    id: "07-communities-browse",
    name: "Communities Browse",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (communitiesBrowse)"],
    mockup: "mockups/macos/05-08-chat-communities-detail-recap.png",
    entry: ["Communities tab", "⌘3"],
    backend: ["GET /v1/communities"],
    controls: [
      { id: "search", type: "text", label: "Search communities", expected: "Filters catalog by name/summary/themes" },
      { id: "filter-pills", type: "display", label: "All/Trending/Nearby/New pills", expected: "STUB — 'All' hard-coded selected, no action" },
      { id: "create-card", type: "display", label: "Create a community card", expected: "STUB — plain VStack, not a Button, no tap action" },
      { id: "community-card", type: "button", label: "Community card", expected: "Navigate → communityDetail" },
    ],
  },
  {
    id: "08-community-detail",
    name: "Community Detail",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (communityDetail(memberMode:false))"],
    mockup: "mockups/macos/05-08-chat-communities-detail-recap.png",
    entry: ["Community card nav"],
    backend: ["GET /v1/communities/:id"],
    controls: [
      { id: "view-members", type: "button", label: "View members", expected: "Navigate → communityMembers" },
      { id: "event-rows", type: "display", label: "Upcoming event rows", expected: "STUB — static rows, no tap" },
    ],
  },
  {
    id: "09-community-members",
    name: "Community Members",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (communityMembers)"],
    mockup: "mockups/macos/13-16-community-members-event-messages-activity.png",
    entry: ["Community Detail View members"],
    backend: ["GET /v1/communities/:id/members"],
    controls: [
      { id: "sidebar-nav", type: "display", label: "About/Events/Members/Resources/Highlights/Settings sidebar", expected: "STUB — static Labels, not buttons, no nav" },
      { id: "search", type: "text", label: "Search members", expected: "Filters filteredCommunityMembers" },
      { id: "filter-pills", type: "display", label: "All/Active now/Most active pills", expected: "STUB — 'All' hard-coded selected, no action" },
      { id: "member-rows", type: "display", label: "Member rows", expected: "STUB — static, no tap action" },
    ],
  },
  {
    id: "10-create-event",
    name: "Create Event",
    source: [
      "apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (createEvent)",
      "apps/ios-macos/Sources/LikemindedMac/MacAppState.swift (createMeeting)",
    ],
    mockup: "mockups/macos/22-create-event.png",
    entry: ["Communities create-event route", "--mac-screen createEvent"],
    backend: ["POST /v1/meetings"],
    controls: [
      { id: "type-meetup", type: "button", label: "Meetup", expected: "Selects Meetup" },
      { id: "type-listening", type: "button", label: "Listening Session", expected: "Selects Listening Session" },
      { id: "type-jam", type: "button", label: "Jam Session", expected: "Selects Jam Session" },
      { id: "fields", type: "text", label: "Event name, Date, Time, Location, Details", expected: "Editable fields drive preview/create payload" },
      { id: "add-cover", type: "button", label: "Add cover", expected: "Adds thematic cover to preview" },
      { id: "add-tags", type: "button", label: "Add tags", expected: "Adds visible preview tags" },
      { id: "create", type: "button", label: "Create event", expected: "Persists meeting via POST /v1/meetings" },
    ],
    notes: "Functional create-event shipped. Remaining: visual parity vs 22-create-event.png and CUA text-field typing proof.",
  },
  {
    id: "11-meet-recap",
    name: "Meet Recap",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (meetRecap)"],
    mockup: "mockups/macos/05-08-chat-communities-detail-recap.png",
    entry: ["Meet Overview Join/past row"],
    backend: ["POST /v1/meetings/:id/recap-note"],
    controls: [
      { id: "recap-note", type: "text", label: "Add a private note", expected: "Editable bound to recapNote" },
      { id: "save-note", type: "button", label: "Save note", expected: "Persist via recap-note endpoint; disabled when no meeting/saving" },
      { id: "message-match", type: "button", label: "Message (per connected match)", expected: "Navigate → messages" },
    ],
  },
  {
    id: "12-my-profile",
    name: "My Profile (view)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (myProfile(editing:false))"],
    mockup: "mockups/macos/09-12-profile-soulmate-discover-detail.png",
    entry: ["Profile tab", "⌘4"],
    backend: ["GET /v1/me/profile"],
    controls: [
      { id: "share-profile", type: "button", label: "Share profile", expected: "Navigate → profileSignals" },
      { id: "signal-cards", type: "display", label: "5 personality signal cards", expected: "STUB — static, no tap" },
      { id: "interest-tags", type: "display", label: "Top interests + vibe", expected: "STUB — static" },
    ],
  },
  {
    id: "13-profile-onboarding",
    name: "Profile Onboarding",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (profileOnboarding)"],
    mockup: "mockups/macos/17-20-profile-onboarding-detail-settings.png",
    entry: ["(Mac onboarding entry)"],
    backend: [],
    controls: [
      { id: "step-rows", type: "display", label: "1 About you / 2 Voice profile / 3 Join first circle", expected: "STUB — static, no tap" },
      { id: "form-lines", type: "display", label: "About-you formLines (name/city/gender) + interest tags", expected: "STUB — static text, not editable" },
      { id: "continue", type: "button", label: "Continue", expected: "Navigate → profileSignals" },
    ],
  },
  {
    id: "14-profile-signals",
    name: "Profile Signals (myProfile editing:true)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (myProfile(editing:true))"],
    mockup: "mockups/macos/09-12-profile-soulmate-discover-detail.png",
    entry: ["Continue from profileOnboarding", "Share profile from myProfile"],
    backend: [],
    controls: [
      { id: "share-profile", type: "button", label: "Share profile", expected: "STUB — navigates to itself; effectively no-op" },
    ],
  },
  {
    id: "15-soulmate-overview",
    name: "Soulmate Overview",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (soulmateOverview)"],
    mockup: "mockups/macos/09-12-profile-soulmate-discover-detail.png",
    entry: ["Soulmate tab", "⌘5 (when enabled)"],
    backend: ["POST /v1/me/soulmate/enable"],
    controls: [
      { id: "enable-toggle", type: "toggle", label: "Enable Soulmate", expected: "Toggles soulmate via backend" },
      { id: "how-it-works", type: "button", label: "How it works (underlined)", expected: "Navigate → soulmateDiscover" },
    ],
  },
  {
    id: "16-soulmate-discover",
    name: "Soulmate Discover",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (soulmateDiscover)"],
    mockup: "mockups/macos/09-12-profile-soulmate-discover-detail.png",
    entry: ["Soulmate Overview How it works"],
    backend: ["GET /v1/me/soulmate/status", "GET /v1/me/soulmate/matches"],
    controls: [
      { id: "distance-slider", type: "slider", label: "Distance slider", expected: "STUB — '25 km' label static; local binding, not persisted, doesn't filter" },
      { id: "filter-pills", type: "display", label: "All/Nearby/Interests pills", expected: "STUB — 'All' hard-coded, no action" },
      { id: "new-matches", type: "button", label: "New matches", expected: "Calls fetchSoulmateStatus" },
      { id: "match-card", type: "button", label: "Match card", expected: "Navigate → soulmateDetail" },
    ],
  },
  {
    id: "17-soulmate-detail",
    name: "Soulmate Detail",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (soulmateDetail)"],
    mockup: "mockups/macos/09-12-profile-soulmate-discover-detail.png",
    entry: ["Soulmate Discover match card"],
    backend: ["GET /v1/me/soulmate/matches/:id"],
    controls: [
      { id: "message", type: "button", label: "Message", expected: "Navigate → chat" },
      { id: "about-panels", type: "display", label: "About / You both like / Compatibility (92% hard-coded)", expected: "STUB — static panels, no controls" },
    ],
  },
  {
    id: "18-messages",
    name: "Messages (compact chat)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (chat(title:'Messages', compact:true))"],
    mockup: "mockups/macos/13-16-community-members-event-messages-activity.png",
    entry: ["Title-action bubble icon", "Meet Recap Message buttons"],
    backend: ["GET/POST /v1/me/soulmate/matches/:id/messages"],
    controls: [
      { id: "match-row", type: "button", label: "Match row", expected: "Sets selectedChatMatchId" },
      { id: "draft", type: "text", label: "Message input", expected: "Editable draft" },
      { id: "send", type: "button", label: "Send", expected: "POST message + reload" },
      { id: "close", type: "button", label: "xmark (title action)", expected: "Navigate → returnScreen ?? meetOverview" },
    ],
  },
  {
    id: "19-notifications",
    name: "Notifications + Activity",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (notifications)"],
    mockup: "mockups/macos/13-16-community-members-event-messages-activity.png",
    entry: ["(Mac notifications entry — title action / command)"],
    backend: ["GET /v1/me/notifications"],
    controls: [
      { id: "notif-filter-pills", type: "display", label: "All/Unread/Mentions pills", expected: "STUB — 'All' hard-coded, no action" },
      { id: "mark-all-read", type: "button", label: "Mark all as read", expected: "STUB — local clear only (appState.notifications=[]); no backend call" },
      { id: "activity-filter-pills", type: "display", label: "All/Circles/Communities pills", expected: "STUB — 'All' hard-coded, no action" },
      { id: "enable", type: "button", label: "Enable", expected: "Misleading: actually calls fetchNotifications (refresh), not system-enable" },
      { id: "rows", type: "display", label: "Notification/activity rows", expected: "STUB — static, no tap" },
    ],
  },
  {
    id: "20-settings-soulmate",
    name: "Settings (Soulmate)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift (settingsSoulmate)"],
    mockup: "mockups/macos/17-20-profile-onboarding-detail-settings.png",
    entry: ["myProfile gearshape title action"],
    backend: ["POST /v1/me/soulmate/enable", "DELETE /v1/me/account", "appState.signOut()"],
    controls: [
      { id: "sidebar", type: "display", label: "Settings sidebar rows", expected: "Displays current Account/Soulmate settings plus planned/static rows without fake tap affordances" },
      { id: "log-out", type: "button", label: "Log out", expected: "Opens confirmation; Sign out → appState.signOut()" },
      { id: "delete-account", type: "button", label: "Delete account", expected: "Opens confirmation; Delete account → DELETE /v1/me/account and clears local session" },
      { id: "soulmate-toggle", type: "toggle", label: "Enable Soulmate", expected: "Toggles soulmate via backend" },
      { id: "age-range", type: "display", label: "Age range", expected: "Displays default beta range without local-only slider" },
      { id: "visibility", type: "display", label: "Visibility", expected: "Displays Circles only without local-only radio buttons" },
    ],
  },
  {
    id: "21-meet-video-call",
    name: "Meet Video Call (LiveKit parity — mockup 21)",
    source: ["apps/ios-macos/Sources/LikemindedMac/MacScreens.swift"],
    mockup: "mockups/macos/21-meet-video-call.png",
    entry: ["Join meetup from Meet (parity target, Phase 10)"],
    backend: ["POST /v1/meetings/:id/join (LiveKit token)"],
    controls: [
      { id: "join-room", type: "button", label: "Join meetup", expected: "Calls POST /meetings/:id/join, opens in-app LiveKit room with camera on", blocker: "No LiveKit server provisioned; macOS parity is Phase 10 unchecked" },
      { id: "tiles", type: "display", label: "Participant tiles", expected: "Camera tiles grid" },
      { id: "mute", type: "button", label: "Mute toggle", expected: "Toggles local mic" },
      { id: "leave", type: "button", label: "Leave", expected: "Disconnects room" },
    ],
    notes: "mockups/macos/21-meet-video-call.png exists but implementation is Phase 10 unchecked. Likely not reachable in current build.",
  },
];

// ---------- JSON-only ledger (no sibling .md — MD was a stale duplicate owner) ----------

function emitJSON(s, platform) {
  return {
    screen: s.name,
    platform,
    source_files: s.source,
    source_hash: "",
    mockup_ref: s.mockup,
    mockup_missing: !s.mockup,
    entry_points: s.entry,
    backend_dependencies: s.backend,
    controls: s.controls.map((c) => ({
      id: c.id,
      type: c.type,
      label: c.label,
      expected: c.expected,
      result: c.blocker ? "blocked" : "pending",
      evidence: "",
      blocker: c.blocker || "",
      stub: !!c.blocker ? false : /STUB/.test(c.expected) || c.expected.includes("STUB"),
      last_tested_at: "",
      tested_source_hash: "",
      last_test_method: ""
    })),
    visual_parity: { result: "pending", notes: "" },
    notes: s.notes || "",
  };
}

ensureDir(IOS);
ensureDir(MAC);

function writePlatform(screens, platform, dir) {
  screens.forEach((s) => {
    const jsonPath = path.join(dir, `${s.id}.json`);
    // Never overwrite evidence ledgers; only scaffold missing JSON.
    if (fs.existsSync(jsonPath)) return;
    fs.writeFileSync(jsonPath, `${JSON.stringify(emitJSON(s, platform), null, 2)}\n`);
  });
}

writePlatform(iosScreens, "ios", IOS);
writePlatform(macScreens, "macos", MAC);

// ---------- README from on-disk JSON (single status owner) ----------

function loadLedgers(dir) {
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .map((f) => {
      const data = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
      return { id: f.replace(/\.json$/, ""), file: f, data };
    });
}

function linkRows(ledgers, platform) {
  return ledgers
    .map((row) => {
      const name = row.data.screen || row.id;
      return `- [${name}](${platform}/${row.file})`;
    })
    .join("\n");
}

const iosLedgers = loadLedgers(IOS);
const macLedgers = loadLedgers(MAC);

const readme = `# Validation index

**Not a status owner.** Pass/fail/stale live in \`validation/<platform>/*.json\` only.

| Need | Command |
|------|---------|
| Route | \`npm run goal:next\` |
| One screen | \`npm run ledger:screen -- --platform ios\\|macos --screen <id> --section ui\\|controls\\|all\` |
| Gap audit (all open) | \`npm run ledger:open\` |
| Stale after edits | \`npm run ledger:stale\` |

Regenerate this link list: \`node validation/_generate.js\` (never overwrites JSON evidence).

## iOS (${iosLedgers.length})

${linkRows(iosLedgers, "ios")}

## macOS (${macLedgers.length})

${linkRows(macLedgers, "macos")}

Conventions: \`docs/workflows/validation.md\`.
`;

fs.writeFileSync(path.join(ROOT, "README.md"), readme);

console.log(`JSON ledgers: ${iosLedgers.length} iOS + ${macLedgers.length} macOS (existing evidence preserved).`);
console.log(`README index written from on-disk JSON.`);

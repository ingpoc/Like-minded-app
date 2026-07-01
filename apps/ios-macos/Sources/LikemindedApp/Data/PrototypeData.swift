import Foundation

enum PrototypeData {
    static let profileSummary = """
    Slow trust, honest conversation, and steady warmth stand out.
    """

    static let profileValues = ["Depth", "Kindness", "Curiosity", "Emotional Honesty"]

    static let reflectionPrompts = [
        ReflectionPrompt(
            prompt: "What kind of conversations make you feel fully seen?",
            note: "Deepens the private read."
        ),
        ReflectionPrompt(
            prompt: "Which friendships have felt energizing rather than draining?",
            note: "Sharpens room fit."
        ),
        ReflectionPrompt(
            prompt: "When do you want space, and when do you want closeness?",
            note: "Sets pacing and consent."
        )
    ]

    static let communities = [
        CommunityRecommendation(
            id: "builders",
            name: "AI Builders",
            summary: "People building useful AI products and tools.",
            fitLabel: "High fit",
            membersOnline: 18,
            themes: ["AI", "Products", "UX"]
        ),
        CommunityRecommendation(
            id: "longform",
            name: "Longform Reading",
            summary: "Essays, psychology, and slow ideas.",
            fitLabel: "Strong fit",
            membersOnline: 9,
            themes: ["Essays", "Psychology", "Slow living"]
        ),
        CommunityRecommendation(
            id: "gentle",
            name: "Slow Dating",
            summary: "Consent-first dating with clear pacing.",
            fitLabel: "Promising",
            membersOnline: 6,
            themes: ["Compatibility", "Rituals", "Care"]
        )
    ]

    static let matches = [
        MatchRecommendation(
            id: "avery",
            name: "Avery",
            compatibility: 92,
            headline: "Warm, reflective, direct.",
            explanation: "Shared depth, steadiness, and curiosity.",
            nextStep: "Offer a guided first conversation."
        ),
        MatchRecommendation(
            id: "riley",
            name: "Riley",
            compatibility: 86,
            headline: "Playful surface, serious core.",
            explanation: "More spontaneity, still aligned on trust.",
            nextStep: "Share a compatibility snapshot before chat."
        )
    ]

    static let chats = [
        ChatPreview(
            id: "avery-chat",
            name: "Avery",
            status: "Mutual interest confirmed",
            lastMessage: "I liked your answer about conversations that feel slow and alive.",
            timestamp: "Now"
        ),
        ChatPreview(
            id: "riley-chat",
            name: "Riley",
            status: "Waiting for guided opener",
            lastMessage: "Likeminded can draft a first question when you're ready.",
            timestamp: "2h"
        )
    ]

    static let privacyControls = [
        PrivacyControl(
            id: "reflection-visible",
            title: "Private reflection visible to me",
            detail: "Your AI profile stays editable and private before anything is shared.",
            isEnabled: true
        ),
        PrivacyControl(
            id: "match-explanation",
            title: "Share match explanation after consent",
            detail: "Only reveal compatibility reasoning once both people opt in.",
            isEnabled: false
        ),
        PrivacyControl(
            id: "voice-mode",
            title: "Voice onboarding enabled",
            detail: "Let the app request a realtime voice session when you start a profile conversation.",
            isEnabled: true
        )
    ]

    static let reflectPlaceConnectSlice = ReflectPlaceConnectSlice(
        journey: [
            MVPJourneyStep(
                id: "reflect",
                title: "Reflect",
                detail: "Three answers shape a private profile.",
                systemImage: "sparkles"
            ),
            MVPJourneyStep(
                id: "place",
                title: "Place",
                detail: "One room is placed first, then gently confirmed.",
                systemImage: "person.3"
            ),
            MVPJourneyStep(
                id: "connect",
                title: "Connect",
                detail: "Open a guided path when fit is clear.",
                systemImage: "bubble.left.and.bubble.right"
            )
        ],
        profile: SynthesizedProfile(
            profileId: "mock-profile-001",
            displayName: "Likeminded Preview",
            basicInfo: nil,
            values: ["depth", "kindness", "curiosity"],
            communicationStyle: "reflective",
            emotionalRhythm: "steady",
            relationshipIntent: "deep-connection",
            interests: [
                Interest(area: "connection", label: "long walks", depth: .active),
                Interest(area: "mind", label: "books", depth: .deep),
                Interest(area: "work", label: "founder stories", depth: .casual)
            ],
            privacy: ProfilePrivacy(
                aiReflectionVisibleToUser: true,
                matchExplanationVisibleToMatches: false
            ),
            reflection: ProfileReflection(
                summary: "You come alive in slow, emotionally honest conversations.",
                strengths: [
                    "prefers emotionally honest conversation",
                    "values steady and thoughtful pacing",
                    "shows curiosity about inner life and compatibility"
                ],
                nextQuestion: "What kind of conversations make you feel most understood?"
            )
        ),
        placement: CirclePlacement(
            rule: "auto-place-user-confirm",
            confidenceLabel: "High",
            fitReasons: [
                "You prefer slow, honest conversation.",
                "Your answers favor warmth and meaningful work.",
                "You want closeness with room to reflect."
            ],
            sourceReflectionSignals: [
                "slow trust",
                "emotionally honest conversation",
                "meaningful work",
                "clear pacing"
            ],
            primaryCircle: PlacementCircle(
                id: "community-builders-001",
                name: "Reflective Builders",
                emotionalPace: "Deliberate",
                interactionIntent: "Creative collaboration",
                socialFormat: "Micro-circle of 4-6",
                riskLevel: "Low",
                privacyLevel: "Starter circle",
                shortPromise: "Ambitious people with emotional range.",
                roomEnergy: "Warm feedback without performance.",
                easiestFirstAction: "Reply with one unfinished question.",
                fitLabel: "High fit",
                placementReason: "Your reflection points to meaningful work, honest feedback, and steady pace.",
                membersOnline: 18,
                themes: ["Founders", "Meaningful work", "Honest feedback"]
            ),
            secondaryCircles: [
                PlacementCircle(
                    id: "community-readers-002",
                    name: "Longform Thinkers",
                    emotionalPace: "Slow",
                    interactionIntent: "Intellectual companionship",
                    socialFormat: "Recurring salon",
                    riskLevel: "Low",
                    privacyLevel: "Starter circle",
                    shortPromise: "Layered thoughts over fast churn.",
                    roomEnergy: "Patient, bookish, quietly expansive.",
                    easiestFirstAction: "Share one line that stayed with you.",
                    fitLabel: "Strong fit",
                    placementReason: "Your answers show nuance and slow trust.",
                    membersOnline: 9,
                    themes: ["Essays", "Psychology", "Slow living"]
                ),
                PlacementCircle(
                    id: "community-gentle-003",
                    name: "Gentle Romantics",
                    emotionalPace: "Steady",
                    interactionIntent: "Romantic exploration",
                    socialFormat: "1:1 intros",
                    riskLevel: "Sensitive",
                    privacyLevel: "Explicit opt-in",
                    shortPromise: "Intimacy without rush.",
                    roomEnergy: "Soft, deliberate, emotionally careful.",
                    easiestFirstAction: "Read the room agreement.",
                    fitLabel: "Promising",
                    placementReason: "Romantic potential needs explicit opt-in.",
                    membersOnline: 6,
                    themes: ["Compatibility", "Rituals", "Care"]
                )
            ],
            userState: .proposed,
            actions: PlacementActionGroup(
                primaryAction: "Accept this room",
                swapAction: "Try another room",
                deferAction: "Defer for now"
            )
        ),
        connectionPath: ConnectionPath(
            matchId: "match-001",
            displayName: "Avery",
            compatibility: 92,
            explanation: "Shared appetite for reflective conversation and steady emotional rhythm.",
            nextStep: "Offer a guided first conversation.",
            consentState: "mutual-interest-required"
        ),
        signals: nil,
        hiddenSignals: nil
    )
}

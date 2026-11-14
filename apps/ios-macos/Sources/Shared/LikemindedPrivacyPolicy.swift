import Foundation

enum LikemindedPrivacyPolicy {
    static let title = "Likeminded TestFlight Privacy Policy"
    static let publicURL = URL(string: "https://likeminded-api.onrender.com/privacy")!

    static let intro =
        "Effective July 21, 2026. Likeminded is a voice-first social app for private profile creation, AI-assisted circle placement, communities, scheduled group meets, recaps, and one-to-one matching."

    static let sections: [(title: String, items: [String])] = [
        (
            "Data Collected",
            [
                "Apple identifier and email or name only when Apple provides them",
                "App-generated device identifier, profile information, manually entered city, interests, private profile signals, and voice transcripts",
                "Community, event, meetup, recap, match, chat, report, and feedback content",
                "Voice audio for AI interviews and audio/video streamed for LiveKit group meets; LiveKit video is not recorded in this MVP"
            ]
        ),
        (
            "How Data Is Used",
            [
                "To authenticate and restore your account on iOS and macOS",
                "To create private profiles and personalize circle placement",
                "To operate communities, scheduled meets, recaps, matching, chat, safety reporting, and tester support",
                "OpenAI processes AI voice interviews; LiveKit processes group-room media; Google processes authentication only when selected"
            ]
        ),
        (
            "Your Controls",
            [
                "You can review and edit your profile at any time",
                "You can leave communities and manage or delete your data in Settings",
                "Apple accounts reauthenticate and revoke Apple access before deletion completes",
                "Likeminded does not sell data or use it for advertising or cross-app tracking"
            ]
        )
    ]

    static let footer =
        "Use TestFlight feedback or the operator contact listed in App Store Connect for privacy questions."
}

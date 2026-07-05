import Foundation

enum LikemindedPrivacyPolicy {
    static let title = "Likeminded TestFlight Privacy Policy"

    static let intro =
        "Likeminded is a voice-first conversation app designed to help you form meaningful connections. This policy describes how we collect, use, and protect your data when you use the TestFlight version of Likeminded."

    static let sections: [(title: String, items: [String])] = [
        (
            "Data Collected",
            [
                "Voice conversations (audio) during calls",
                "Profile information you provide",
                "Profile signals generated from conversations (communication style, energy, interests)",
                "Basic account and device information (email, device type, app version)",
                "Usage data to help improve the app"
            ]
        ),
        (
            "How Data Is Used",
            [
                "To enable and improve voice conversations",
                "To generate and refine profile signals",
                "To recommend and match you with like-minded people",
                "To maintain safety, security, and prevent abuse",
                "To improve Likeminded's features and performance"
            ]
        ),
        (
            "Your Controls",
            [
                "You can review and edit your profile at any time",
                "You can manage or delete your data in Settings",
                "You can request deletion of your data at any time",
                "You can leave any community at any time"
            ]
        )
    ]

    static let footer =
        "We take your privacy seriously. We never sell your data. For questions, contact us anytime at hello@likeminded.app."

    static let contactEmail = "hello@likeminded.app"
}

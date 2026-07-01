import SwiftUI

@main
struct LikemindedMacApp: App {
    var body: some Scene {
        WindowGroup {
            MacRootView()
                .frame(minWidth: 1120, minHeight: 720)
        }
        .commands {
            CommandMenu("Prototype") {
                Button("Meet") {
                    NotificationCenter.default.post(name: .macPrototypeSelectMeet, object: nil)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Circles") {
                    NotificationCenter.default.post(name: .macPrototypeSelectCircles, object: nil)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Communities") {
                    NotificationCenter.default.post(name: .macPrototypeSelectCommunities, object: nil)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Profile") {
                    NotificationCenter.default.post(name: .macPrototypeSelectProfile, object: nil)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Soulmate") {
                    NotificationCenter.default.post(name: .macPrototypeSelectSoulmate, object: nil)
                }
                .keyboardShortcut("5", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let macPrototypeSelectMeet = Notification.Name("macPrototypeSelectMeet")
    static let macPrototypeSelectCircles = Notification.Name("macPrototypeSelectCircles")
    static let macPrototypeSelectCommunities = Notification.Name("macPrototypeSelectCommunities")
    static let macPrototypeSelectProfile = Notification.Name("macPrototypeSelectProfile")
    static let macPrototypeSelectSoulmate = Notification.Name("macPrototypeSelectSoulmate")
}


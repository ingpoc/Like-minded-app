import SwiftUI

struct SettingsPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var showingSignOutConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var activeSheet: SettingsSheet?

    var body: some View {
        ScreenContainer(title: "Soulmate", subtitle: "Settings") {
            settingsSection("Soulmate") {
                VStack(spacing: 0) {
                    Toggle(isOn: soulmateToggleBinding) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Enable Soulmate")
                                .font(PrototypeTypography.bodyStrong)
                                .foregroundStyle(PrototypePalette.ink)
                            Text("Opt in to find connections after meetups.\nOnly visible when enabled.")
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.subink)
                        }
                    }
                    .tint(PrototypePalette.accent)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Enable Soulmate")

                    Divider().overlay(PrototypePalette.rule)

                    SettingsRow(icon: "heart", title: "How it works") {
                        activeSheet = .howItWorks
                    }
                }
            }

            settingsSection("Account") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Sign out", role: .destructive) {
                        showingSignOutConfirm = true
                    }

                    Divider().overlay(PrototypePalette.rule)

                    SettingsRow(title: isDeletingAccount ? "Deleting account" : "Delete account", role: .destructive) {
                        showingDeleteConfirm = true
                    }
                    .disabled(isDeletingAccount)
                }
            }

            settingsSection("About") {
                VStack(spacing: 0) {
                    HStack {
                        Text("App version")
                        Spacer()
                        Text("1.0.0 (100)")
                            .foregroundStyle(PrototypePalette.subink)
                    }
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.ink)
                    .padding(.vertical, 14)

                    Divider().overlay(PrototypePalette.rule)

                    SettingsRow(title: "Privacy policy") {
                        activeSheet = .privacy
                    }
                }
            }

            settingsSection("Support") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Help & FAQ") {
                        activeSheet = .help
                    }
                    Divider().overlay(PrototypePalette.rule)
                    SettingsRow(title: "Contact support") {
                        activeSheet = .support
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Sign out of Likeminded?",
            isPresented: $showingSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                appState.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to restore your profile and placement.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    _ = await appState.deleteAccount()
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your profile, placement, transcript, feedback, Soulmate, chat, community, and meetup data from this backend.")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .howItWorks:
                SettingsInfoSheet(
                    title: "How Soulmate works",
                    sections: [
                        ("Opt in", ["Turn Soulmate on only when you want post-meet matching.", "The Soulmate tab appears after the backend saves your preference."]),
                        ("Choose after meetups", ["After a scheduled meet, pick people you would like to continue with.", "No one sees the choice unless both people select each other."]),
                        ("Chat when mutual", ["Mutual selections create a backend chat thread.", "Messages persist and are only available to the matched pair."])
                    ]
                )
            case .privacy:
                PrivacyPolicySheet()
            case .help:
                SettingsInfoSheet(
                    title: "Help & FAQ",
                    sections: [
                        ("Voice profile", ["Complete onboarding, then start the voice interview from Profile.", "Retake it when your circle placement feels off."]),
                        ("Meetups", ["Saturday is community-focused; Sunday is circle-focused.", "RSVPs and scheduled rooms sync through the backend."]),
                        ("Troubleshooting", ["If data looks stale, sign out and sign back in.", "Use Contact support to send a DB-backed tester note."])
                    ]
                )
            case .support:
                ContactSupportSheet()
                    .environmentObject(appState)
            }
        }
    }

    private var soulmateToggleBinding: Binding<Bool> {
        Binding(
            get: { appState.soulmateEnabled },
            set: { newValue in
                Task { await appState.setSoulmateEnabled(newValue) }
            }
        )
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        }
    }
}

private struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Likeminded TestFlight Privacy Policy")
                        .font(PrototypeTypography.cardTitle)
                        .foregroundStyle(PrototypePalette.ink)

                    Text("Likeminded uses voice conversation to build private profile signals and suggest a starter circle placement.")
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.ink)

                    policySection("Data Collected", items: [
                        "Sign in with Apple identifier, and email/name only when Apple provides them.",
                        "Voice interview transcript generated during onboarding.",
                        "Profile signals inferred from onboarding, such as communication style, social energy, trust pattern, and personality traits.",
                        "Circle placement, placement actions, and tester feedback.",
                        "Basic technical metadata needed to run the service, such as app version and request timing."
                    ])

                    policySection("How Data Is Used", items: [
                        "To create and restore the tester's private profile.",
                        "To suggest a starter circle based on personality fit.",
                        "To improve placement and host selection across the TestFlight cohort.",
                        "Profile signals are never shown to other testers."
                    ])

                    policySection("Your Controls", items: [
                        "You can re-take the voice interview at any time from Profile.",
                        "You can flag a circle that does not feel right and prompt a re-evaluation.",
                        "Soulmate is opt-in only and visible when both people choose each other.",
                        "Delete account removes your backend tester data and clears this device session."
                    ])
                }
                .padding(20)
            }
            .background(PrototypePalette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PrototypePalette.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func policySection(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)
            ForEach(items, id: \.self) { item in
                Text("•  \(item)")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private enum SettingsSheet: Identifiable {
    case howItWorks
    case privacy
    case help
    case support

    var id: String {
        switch self {
        case .howItWorks: return "howItWorks"
        case .privacy: return "privacy"
        case .help: return "help"
        case .support: return "support"
        }
    }
}

private struct SettingsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let sections: [(String, [String])]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.0)
                                .font(PrototypeTypography.eyebrow)
                                .foregroundStyle(PrototypePalette.accent)
                            ForEach(section.1, id: \.self) { item in
                                Text("•  \(item)")
                                    .font(PrototypeTypography.body)
                                    .foregroundStyle(PrototypePalette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PrototypePalette.background.ignoresSafeArea())
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PrototypePalette.accent)
                }
            }
        }
    }
}

private struct ContactSupportSheet: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var status: String?
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Send a tester support note. It is saved through the authenticated feedback API.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)

                TextField("What needs help?", text: $message, axis: .vertical)
                    .font(PrototypeTypography.body)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(5...8)

                if let status {
                    Text(status)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.accent)
                }

                Spacer()

                Button {
                    Task { await send() }
                } label: {
                    PrimaryActionButton(title: isSending ? "Sending" : "Send support note", systemImage: "paperplane.fill")
                }
                .buttonStyle(.plain)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(20)
            .background(PrototypePalette.background.ignoresSafeArea())
            .navigationTitle("Contact support")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PrototypePalette.accent)
                }
            }
        }
    }

    private func send() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        await appState.submitFeedback(rating: 3, message: "Support request: \(trimmed)")
        message = ""
        status = "Support note saved."
        isSending = false
    }
}

private struct SettingsRow: View {
    enum Role {
        case `default`
        case destructive
    }

    var icon: String?
    let title: String
    var role: Role = .default
    var action: (() -> Void)?

    private var titleColor: Color {
        return role == .destructive ? PrototypePalette.coral : PrototypePalette.ink
    }

    private var iconColor: Color {
        return PrototypePalette.accent
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(titleColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PrototypePalette.subink)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

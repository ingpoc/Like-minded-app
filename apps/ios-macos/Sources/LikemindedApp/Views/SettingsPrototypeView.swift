import SwiftUI

struct SettingsPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var showingSignOutConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var activeSheet: SettingsSheet?
    @State private var appleSignInController = AppleSignInController()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
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

                        Divider().overlay(PrototypePalette.rule)

                        NavigationLink {
                            SoulmateDiscoveryPreferencesView()
                        } label: {
                            SettingsRowLabel(icon: "slider.horizontal.3", title: "Discovery preferences")
                        }
                        .buttonStyle(.plain)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 180)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .prototypeBackNavigation()
        .task {
            await appState.fetchSoulmateStatus()
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--likeminded-start-settings-info") {
                activeSheet = .howItWorks
            }
            #endif
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--likeminded-start-settings-support") {
                activeSheet = .support
            }
            #endif
        }
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
                    _ = await appState.deleteAccount(using: appleSignInController)
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
                    sections: SettingsInfoContent.howSoulmateWorks,
                    privacyNote: SettingsInfoContent.soulmatePrivacyNote
                )
            case .privacy:
                PrivacyPolicySheet()
            case .help:
                SettingsInfoSheet(
                    title: "Help & FAQ",
                    sections: SettingsInfoContent.helpFAQ
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
                .accessibilityLabel(title)

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

private struct SoulmateDiscoveryPreferencesView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var isSavingSoulmatePrefs = false
    @State private var soulmatePrefsStatus: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Enable to discover compatible people across your circles. We prioritize quality, authenticity and your comfort.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    soulmateFeatureCard(
                        icon: "sparkle",
                        title: "Intentional matches",
                        detail: "Curated people who align with your values and vibe."
                    )
                    soulmateFeatureCard(
                        icon: "shield.checkered",
                        title: "Your comfort first",
                        detail: "You decide what to share and who can see you."
                    )
                    soulmateFeatureCard(
                        icon: "lock",
                        title: "Private by design",
                        detail: "We never reveal your data without your permission."
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Discovery preferences")
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(PrototypePalette.ink)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who can discover you")
                            .font(PrototypeTypography.metadata.weight(.semibold))
                        Picker("Who can discover you", selection: discoveryBinding) {
                            Text("People in my circles").tag("circles")
                            Text("People in my circles + circle of circles").tag("circles_extended")
                            Text("People in my communities").tag("communities")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .accessibilityLabel("Who can discover you")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Age range")
                            .font(PrototypeTypography.metadata.weight(.semibold))
                        PrototypeAgeRangeSlider(
                            minAge: ageMinBinding,
                            maxAge: ageMaxBinding
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visibility")
                            .font(PrototypeTypography.metadata.weight(.semibold))
                        PrototypeRadioCard(
                            title: "Visible only after both like",
                            detail: "Profiles stay hidden until you both express interest.",
                            selected: soulmateVisibilityIsPrivate
                        ) {
                            appState.soulmatePreferences.visibility = "matches_only"
                        }
                        PrototypeRadioCard(
                            title: "Visible in discover",
                            detail: "Eligible matches can see you in Discover.",
                            selected: !soulmateVisibilityIsPrivate
                        ) {
                            appState.soulmatePreferences.visibility = "circles_communities"
                        }
                    }

                    Button(isSavingSoulmatePrefs ? "Saving…" : "Save preferences") {
                        Task {
                            isSavingSoulmatePrefs = true
                            let saved = await appState.saveSoulmatePreferences(appState.soulmatePreferences)
                            isSavingSoulmatePrefs = false
                            soulmatePrefsStatus = saved ? "Preferences saved." : appState.soulmateError
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PrototypePalette.accent)
                    .accessibilityLabel("Save preferences")

                    if let soulmatePrefsStatus {
                        Text(soulmatePrefsStatus)
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 180)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .navigationTitle("Discovery preferences")
        .navigationBarTitleDisplayMode(.inline)
        .prototypeBackNavigation()
        .task {
            await appState.fetchSoulmateStatus()
        }
    }

    private var soulmateVisibilityIsPrivate: Bool {
        appState.soulmatePreferences.visibility != "circles_communities"
    }

    private var discoveryBinding: Binding<String> {
        Binding(
            get: { appState.soulmatePreferences.discovery },
            set: { appState.soulmatePreferences.discovery = $0 }
        )
    }

    private var ageMinBinding: Binding<Int> {
        Binding(
            get: { appState.soulmatePreferences.ageMin },
            set: { appState.soulmatePreferences.ageMin = min($0, appState.soulmatePreferences.ageMax) }
        )
    }

    private var ageMaxBinding: Binding<Int> {
        Binding(
            get: { appState.soulmatePreferences.ageMax },
            set: { appState.soulmatePreferences.ageMax = max($0, appState.soulmatePreferences.ageMin) }
        )
    }

    private func soulmateFeatureCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text(detail)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(LikemindedPrivacyPolicy.title)
                        .font(PrototypeTypography.cardTitle)
                        .foregroundStyle(PrototypePalette.ink)

                    Text(LikemindedPrivacyPolicy.intro)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.ink)

                    ForEach(LikemindedPrivacyPolicy.sections, id: \.title) { section in
                        policySection(section.title, items: section.items)
                    }

                    Text(LikemindedPrivacyPolicy.footer)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.ink)

                    Link("Open public privacy policy", destination: LikemindedPrivacyPolicy.publicURL)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.accent)
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

private struct SettingsInfoSection: Identifiable {
    let eyebrow: String
    let icon: String
    let title: String
    let bullets: [String]

    var id: String { eyebrow }
}

private enum SettingsInfoContent {
    static let soulmatePrivacyNote =
        "Your privacy is built in. Selections are private and visible only to admins after the window closes."

    static let howSoulmateWorks: [SettingsInfoSection] = [
        SettingsInfoSection(
            eyebrow: "Opt in",
            icon: "heart",
            title: "Turn Soulmate on",
            bullets: [
                "Go to Settings and enable Soulmate.",
                "Only visible when enabled.",
                "You can turn it off anytime."
            ]
        ),
        SettingsInfoSection(
            eyebrow: "Choose after meetups",
            icon: "person.2",
            title: "Post-meet selection",
            bullets: [
                "After a meetup, select the people you'd like to connect with.",
                "Your choices stay private.",
                "Selections close after 24 hours."
            ]
        ),
        SettingsInfoSection(
            eyebrow: "Chat when mutual",
            icon: "bubble.left.and.bubble.right",
            title: "Mutual matches create chat",
            bullets: [
                "If they select you too, it's a match!",
                "You'll unlock a chat to get to know each other better.",
                "No match? No worries. It stays private."
            ]
        )
    ]

    static let helpFAQ: [SettingsInfoSection] = [
        SettingsInfoSection(
            eyebrow: "Voice profile",
            icon: "waveform",
            title: "Build your signals",
            bullets: [
                "Complete onboarding, then start the voice interview from Profile.",
                "Retake it when your circle placement feels off."
            ]
        ),
        SettingsInfoSection(
            eyebrow: "Meetups",
            icon: "calendar",
            title: "Saturday and Sunday rooms",
            bullets: [
                "Saturday is community-focused; Sunday is circle-focused.",
                "RSVPs and scheduled rooms sync through the backend."
            ]
        ),
        SettingsInfoSection(
            eyebrow: "Troubleshooting",
            icon: "wrench.and.screwdriver",
            title: "When data looks stale",
            bullets: [
                "Sign out and sign back in to refresh your profile.",
                "Use Contact support to send a DB-backed tester note."
            ]
        )
    ]
}

private struct SettingsInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let sections: [SettingsInfoSection]
    var privacyNote: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        if index > 0 {
                            Divider()
                                .overlay(PrototypePalette.rule)
                                .padding(.vertical, 22)
                        }

                        settingsInfoSection(section)
                    }

                    if let privacyNote {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock")
                                .font(PrototypeTypography.metadata)
                                .foregroundStyle(PrototypePalette.subink)
                                .padding(.top, 2)
                            Text(privacyNote)
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.subink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 28)
                    }
                }
                .padding(20)
            }
            .background(PrototypePalette.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PrototypePalette.accent)
                        .accessibilityLabel("Done")
                }
            }
        }
    }

    private func settingsInfoSection(_ section: SettingsInfoSection) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(PrototypePalette.accentSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: section.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PrototypePalette.accent)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(section.eyebrow.uppercased())
                    .font(PrototypeTypography.eyebrow)
                    .foregroundStyle(PrototypePalette.accent)

                Text(section.title)
                    .font(PrototypeTypography.cardTitle)
                    .foregroundStyle(PrototypePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(section.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.ink)
                            Text(bullet)
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct SettingsRowLabel: View {
    var icon: String?
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(PrototypePalette.accent)
            }

            Text(title)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.ink)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityLabel(title)
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

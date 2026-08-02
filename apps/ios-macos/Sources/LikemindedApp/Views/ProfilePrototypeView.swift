import SwiftUI

private enum ProfileRoute: Hashable {
    case edit
    case signals
    case settings
}

struct ProfileSignalLabel: Identifiable {
    let title: String
    let value: String
    var id: String { title }
}

enum ProfileSignalFormatting {
    static func display(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "From voice profile" }
        switch value.lowercased() {
        case "slowtrust": return "Slow trust"
        case "fasttrust": return "Fast trust"
        default: break
        }
        return value
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }

    static func cards(from signals: ProfileSignals?) -> [ProfileSignalLabel] {
        guard let signals else {
            return [
                ProfileSignalLabel(title: "Communication", value: "From voice profile"),
                ProfileSignalLabel(title: "Energy", value: "From voice profile"),
                ProfileSignalLabel(title: "Trust", value: "From voice profile"),
                ProfileSignalLabel(title: "Mindset", value: "From voice profile"),
                ProfileSignalLabel(title: "Humor", value: "From voice profile")
            ]
        }
        return [
            ProfileSignalLabel(title: "Communication", value: display(signals.communicationStyle?.primary)),
            ProfileSignalLabel(title: "Energy", value: display(signals.socialEnergy)),
            ProfileSignalLabel(title: "Trust", value: display(signals.trustPattern)),
            ProfileSignalLabel(title: "Mindset", value: display(signals.attachment)),
            ProfileSignalLabel(title: "Humor", value: display(signals.humorStyle))
        ]
    }
}

struct VoiceProfileView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var showingVoiceSession = false
    @State private var showSettingsForValidation = false
    @State private var profilePath = NavigationPath()
    @State private var didOpenProfileRouteForValidation = false

    var body: some View {
        NavigationStack(path: $profilePath) {
            ScreenContainer(
                title: "Profile",
                subtitle: "Your profile, in context.",
                caption: "What we understand about you—and how it shapes your placement."
            ) {
                profileHeader

                if shouldShowOnboarding {
                    OnboardingView()
                } else if shouldShowVoiceEmptyHero {
                    profileVoiceEmptyState
                } else {
                    if appState.concernFlag {
                        placementConcernCard
                    }
                    livingProfile
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .edit:
                    ProfileEditView()
                case .signals:
                    ProfileSignalsView()
                case .settings:
                    SettingsPrototypeView()
                }
            }
            .sheet(isPresented: $showingVoiceSession) {
                VoiceProfileSessionSheet()
                    .environmentObject(appState)
            }
            .task {
                if appState.isSignedIn {
                    await appState.fetchCircles()
                    await appState.fetchMeetings()
                    await appState.fetchSoulmateStatus()
                }
            }
            .onAppear {
                openVoiceSessionForValidationIfNeeded()
                openSettingsForValidationIfNeeded()
                openProfileRouteForValidationIfNeeded()
            }
            .background {
                NavigationLink(isActive: $showSettingsForValidation) {
                    SettingsPrototypeView()
                } label: {
                    EmptyView()
                }
                .hidden()
            }
        }
    }

    private func openProfileRouteForValidationIfNeeded() {
        #if DEBUG
        guard !didOpenProfileRouteForValidation else { return }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--likeminded-start-profile-edit") {
            profilePath.append(ProfileRoute.edit)
            didOpenProfileRouteForValidation = true
        } else if args.contains("--likeminded-start-profile-signals") {
            profilePath.append(ProfileRoute.signals)
            didOpenProfileRouteForValidation = true
        }
        #endif
    }

    private func openSettingsForValidationIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--likeminded-start-settings")
            || args.contains("--likeminded-start-settings-support")
            || args.contains("--likeminded-start-settings-info") {
            showSettingsForValidation = true
        }
        #endif
    }

    private func openVoiceSessionForValidationIfNeeded() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--likeminded-start-voice-session") else { return }
        appState.seedVoiceSessionPreviewIfNeeded()
        showingVoiceSession = true
        if !args.contains("--likeminded-dev-voice-preview") {
            Task { await appState.startVoiceSession() }
        }
        #endif
    }

    private var profileHeader: some View {
        let info = appState.slice?.profile.basicInfo ?? appState.basicInfo
        let name = info?.name ?? "Your profile"
        let location = info?.city ?? "Your location"
        let summary = appState.slice?.profile.reflection.summary
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                DoodlePortrait(assetName: DoodleArt.portrait(for: info?.gender), size: 76)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(name)
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(PrototypePalette.ink)
                    Label(location, systemImage: "mappin")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)
                    Label("Voice-informed profile", systemImage: "waveform")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.accent)
                }

                Spacer(minLength: 0)

                Button {
                    profilePath.append(ProfileRoute.settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)
                        .frame(width: 44, height: 44)
                        .background(PrototypePalette.background, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("title-settings")
            }

            if let summary, !summary.isEmpty {
                Text(summary)
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if info != nil {
                HStack(spacing: 10) {
                    Button {
                        profilePath.append(ProfileRoute.edit)
                    } label: {
                        Label("Edit profile", systemImage: "square.and.pencil")
                            .font(PrototypeTypography.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(PrototypePalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("open-profile-update-options")

                    Button {
                        showingVoiceSession = true
                        Task { await appState.startReinterview() }
                    } label: {
                        Label("Re-interview", systemImage: "arrow.clockwise")
                            .font(PrototypeTypography.button)
                            .foregroundStyle(PrototypePalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(PrototypePalette.surface, in: Capsule())
                            .overlay(Capsule().stroke(PrototypePalette.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Re-interview to update profile")
                }
            }
        }
        .padding(16)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }

    private var shouldShowOnboarding: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--likeminded-force-onboarding") {
            return true
        }
        #endif
        return appState.slice == nil && appState.basicInfo == nil
    }

    private var shouldShowVoiceEmptyHero: Bool {
        if PrototypeAppState.devProfileEmptyPreview {
            return appState.basicInfo != nil
        }
        return appState.slice == nil && appState.basicInfo != nil
    }

    private var profileVoiceEmptyState: some View {
        ProfileVoiceEmptyCard(
            isLoading: appState.isStartingVoice,
            onStartVoice: {
                showingVoiceSession = true
                Task { await appState.startVoiceSession() }
            }
        )
    }

    private var placementConcernCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Circle feels off".uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            Text(appState.displayPlacementConcern)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.ink)

            Button {
                showingVoiceSession = true
                Task { await appState.startReinterview() }
            } label: {
                PrimaryActionButton(
                    title: appState.isStartingVoice ? "Opening voice" : "Re-interview for placement",
                    systemImage: "waveform"
                )
                .contentTransition(.opacity)
            }
            .buttonStyle(.plain)
            .disabled(appState.isStartingVoice)
            .accessibilityLabel("Start re-interview")
        }
        .padding(16)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }

    private var livingProfile: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Why this placement")
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)

                Text("Context for your circle—not proof of personality.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(appState.currentPlacement.fitReasons.prefix(3).enumerated()), id: \.offset) { index, reason in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: ["person.2", "target", "mountain.2"][index])
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PrototypePalette.accent)
                            .frame(width: 30, height: 30)
                            .background(PrototypePalette.accentSoft, in: Circle())
                            .accessibilityHidden(true)
                        Text(reason)
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

            }
            .padding(18)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Voice-informed signals")
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(PrototypePalette.ink)
                    Spacer(minLength: 12)
                    Button("Review all") {
                        profilePath.append(ProfileRoute.signals)
                    }
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(PrototypePalette.accent, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review signals")
                    .accessibilityIdentifier("review-private-signals")
                }
                Text("Inferences from your interview and activity—not a diagnosis.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(Array(ProfileSignalFormatting.cards(from: appState.slice?.signals).prefix(2))) { item in
                        profileSignalPill(item)
                    }
                }
            }
            .padding(14)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))

            VStack(alignment: .leading, spacing: 14) {
                Text("Top interests")
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)
                let interests = appState.slice?.profile.interests.map(\.label) ?? []
                if interests.isEmpty {
                    Text("Interests appear after your voice profile.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                } else {
                    TokenRow(items: interests)
                }
            }
            .padding(18)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        }
    }

    private func profileSignalPill(_ item: ProfileSignalLabel) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)
            Text(item.value)
                .font(PrototypeTypography.bodyStrong)
                .foregroundStyle(PrototypePalette.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(8)
        .background(PrototypePalette.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.value)")
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileVoiceEmptyCard: View {
    var isLoading = false
    var onStartVoice: () -> Void = {}

    var body: some View {
        VStack(spacing: 26) {
            VoiceListeningCard()
                .padding(.top, 8)

            VStack(spacing: 12) {
                Text("Voice profile".uppercased())
                    .font(PrototypeTypography.eyebrow)
                    .foregroundStyle(.white.opacity(0.78))

                Text("Tell me how\nyou connect.")
                    .font(PrototypeTypography.hero)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Speak naturally. The profile updates as you talk.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }

            Button(action: onStartVoice) {
                Label(
                    isLoading ? "Opening voice profile" : "Start voice profile",
                    systemImage: "waveform"
                )
                .font(PrototypeTypography.button)
                .foregroundStyle(PrototypePalette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.88))
                .clipShape(Capsule(style: .continuous))
                .contentTransition(.opacity)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .accessibilityLabel("Start voice profile")
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(PrototypePalette.roomGradient(0))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TypedProfileUpdateSheet: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss

    let signal: ProfileSignalLabel?
    @State private var draft: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(signal: ProfileSignalLabel? = nil, initialValue: String) {
        self.signal = signal
        _draft = State(initialValue: initialValue)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(signal == nil ? "Type an update" : "Correct \(signal!.title.lowercased())")
                        .font(PrototypeTypography.pageTitle)
                        .foregroundStyle(PrototypePalette.ink)
                        .accessibilityAddTraits(.isHeader)

                    Text(
                        signal == nil
                            ? "This updates your private profile summary. Only you can see it."
                            : "Replace this interpretation with words that fit you better, or remove it."
                    )
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)

                    ZStack(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text(signal == nil ? "Write what you want Likeminded to understand…" : "Write what fits you better…")
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.muted)
                                .padding(.horizontal, 17)
                                .padding(.vertical, 20)
                                .accessibilityHidden(true)
                        }
                        TextEditor(text: $draft)
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.ink)
                            .frame(minHeight: 150)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel(signal == nil ? "Typed profile update" : "\(signal!.title) correction")
                            .accessibilityIdentifier("profile-typed-update-field")
                    }
                    .background(PrototypePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.amber)
                    }

                    Button {
                        isSaving = true
                        Task {
                            let saved: Bool
                            if let signal {
                                saved = await appState.correctProfileSignal(signal.title, value: draft)
                            } else {
                                saved = await appState.updateProfileSummary(draft)
                            }
                            isSaving = false
                            if saved {
                                dismiss()
                            } else {
                                errorMessage = "Could not save this update. Please try again."
                            }
                        }
                    } label: {
                        PrimaryActionButton(title: isSaving ? "Saving update" : "Save typed update", systemImage: "checkmark")
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("profile-typed-update-save")

                    if let signal {
                        Button("Remove this interpretation") {
                            isSaving = true
                            Task {
                                if await appState.dismissProfileSignal(signal.title) {
                                    dismiss()
                                } else {
                                    isSaving = false
                                    errorMessage = "Could not remove this interpretation. Please try again."
                                }
                            }
                        }
                        .font(PrototypeTypography.button)
                        .foregroundStyle(PrototypePalette.amber)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .accessibilityIdentifier("profile-typed-update-remove")
                    }
                }
                .padding(20)
            }
            .background(PrototypePalette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .toolbarBackground(PrototypePalette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}

private struct VoiceProfileSessionSheet: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    @State private var showingTypedUpdate = false

    private var voiceFailed: Bool {
        appState.realtimeStatus == RealtimeVoicePhase.failed.rawValue
    }

    private var statusLine: String {
        switch appState.realtimeStatus {
        case RealtimeVoicePhase.streaming.rawValue:
            return "I am listening for fit."
        case RealtimeVoicePhase.connecting.rawValue, RealtimeVoicePhase.stopping.rawValue:
            return appState.realtimeStatus + "…"
        case RealtimeVoicePhase.stopped.rawValue:
            return "Review captured signals."
        case RealtimeVoicePhase.failed.rawValue:
            return "Voice issue — try again."
        default:
            return appState.capturedVoiceSignals.isEmpty ? "Tell me how you connect." : "Review captured signals."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("PROFILE")
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(.white.opacity(0.72))
                        Text("Voice profile")
                            .font(PrototypeTypography.display)
                            .foregroundStyle(.white)
                            .dynamicTypeSize(.xSmall ... .accessibility1)
                        if !voiceFailed {
                            Text(statusLine)
                                .font(PrototypeTypography.body)
                                .foregroundStyle(.white.opacity(0.82))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 280)
                        }
                    }
                    .padding(.top, 8)

                    VoiceListeningCard(
                        isActive: appState.isVoiceStreaming || appState.realtimeStatus == RealtimeVoicePhase.streaming.rawValue,
                        isFailed: voiceFailed
                    )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Voice orb")
                        .accessibilityValue(voiceFailed ? "Recording off" : (appState.isVoiceStreaming ? "Listening" : appState.realtimeStatus))

                    if !voiceFailed {
                        VoiceWaveformBars(isActive: appState.isVoiceStreaming || appState.realtimeStatus == RealtimeVoicePhase.streaming.rawValue)
                            .frame(height: 36)
                            .accessibilityHidden(true)
                    }

                    if voiceFailed {
                        Text("Voice could not start. Nothing was recorded or changed.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.amber)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                    }

                    if !appState.capturedVoiceSignals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Captured signals")
                                .font(PrototypeTypography.metadata)
                                .foregroundStyle(.white.opacity(0.7))

                            ForEach(Array(appState.capturedVoiceSignals.enumerated()), id: \.offset) { index, signal in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(PrototypeTypography.metadata.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(PrototypePalette.success.opacity(0.85), in: Circle())

                                    Text(signal)
                                        .font(PrototypeTypography.body)
                                        .foregroundStyle(.white.opacity(0.92))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Button {
                                        appState.removeCapturedVoiceSignal(at: index)
                                    } label: {
                                        Text("Remove")
                                            .font(PrototypeTypography.caption)
                                            .foregroundStyle(PrototypePalette.amber)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove captured signal \(index + 1)")
                                }
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if voiceFailed {
                        Button {
                            appState.resetVoiceSession()
                            Task { await appState.startVoiceSession() }
                        } label: {
                            Label("Try voice again", systemImage: "arrow.clockwise")
                                .font(PrototypeTypography.button)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(PrototypePalette.actionGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Try voice again")
                        .accessibilityIdentifier("voice-profile-retry")

                        Button {
                            showingTypedUpdate = true
                        } label: {
                            Label("Type an update", systemImage: "keyboard")
                                .font(PrototypeTypography.button)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("voice-profile-type-update")
                    } else if !appState.didPersistVoiceProfile {
                        Button {
                            Task { await appState.stopVoiceSession() }
                        } label: {
                            Label("Stop listening", systemImage: "stop.fill")
                                .font(PrototypeTypography.button)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(PrototypePalette.actionGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Stop listening")
                    }

                    Button {
                        Task {
                            if appState.didPersistVoiceProfile {
                                if await appState.completeVoiceSession() {
                                    dismiss()
                                }
                            } else {
                                appState.resetVoiceSession()
                                dismiss()
                            }
                        }
                    } label: {
                        Label(
                            appState.didPersistVoiceProfile ? "Save voice profile" : "Back to profile",
                            systemImage: appState.didPersistVoiceProfile ? "checkmark" : "arrow.left"
                        )
                            .font(PrototypeTypography.button)
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.didPersistVoiceProfile ? "Save voice profile" : "Back to profile")

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PrototypePalette.success)
                        Text(
                            voiceFailed
                                ? "Your profile stays private. Retry voice when ready, or return to profile."
                                : "Your words and captured signals stay private. Review what appears here before choosing Save voice profile."
                        )
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PrototypePalette.accent.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.14, blue: 0.11), Color(red: 0.02, green: 0.05, blue: 0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        appState.resetVoiceSession()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Cancel voice update")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            appState.seedVoiceSessionPreviewIfNeeded()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingTypedUpdate) {
            TypedProfileUpdateSheet(initialValue: "")
            .environmentObject(appState)
        }
    }
}

private struct VoiceListeningCard: View {
    var isActive = false
    var isFailed = false

    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(PrototypePalette.success.opacity(isFailed ? 0.035 : (isActive ? 0.22 : 0.12)), lineWidth: 1)
                    .frame(
                        width: CGFloat(112 + index * 38) * (isActive && pulse ? 1.04 : 1.0),
                        height: CGFloat(112 + index * 38) * (isActive && pulse ? 1.04 : 1.0)
                    )
                    .animation(
                        isActive ? .easeInOut(duration: 0.9 + Double(index) * 0.08).repeatForever(autoreverses: true) : .default,
                        value: pulse
                    )
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: isFailed
                            ? [Color.white.opacity(0.12), Color.white.opacity(0.035), .clear]
                            : [PrototypePalette.success.opacity(isActive ? 0.78 : 0.64), PrototypePalette.accent.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: isActive ? 124 : 112
                    )
                )
                .frame(width: isActive ? 228 : 216, height: isActive ? 228 : 216)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isActive && pulse)

            Image(systemName: isFailed ? "mic.slash.fill" : "sparkle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(isFailed ? 0.72 : 0.92))
                .shadow(color: isFailed ? .clear : PrototypePalette.success, radius: isActive ? 18 : 10)

            if !isFailed {
                Circle()
                    .fill(PrototypePalette.success.opacity(0.85))
                    .frame(width: 26, height: 26)
                    .shadow(color: PrototypePalette.success, radius: isActive ? 28 : 24)
            }
        }
        .frame(height: 260)
        .onAppear {
            pulse = true
        }
        .onChange(of: isActive) { _, active in
            if active { pulse.toggle() }
        }
    }
}

private struct VoiceWaveformBars: View {
    let isActive: Bool

    @State private var levels: [CGFloat] = Array(repeating: 0.35, count: 14)
    @State private var timerActive = false

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(levels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(PrototypePalette.success.opacity(isActive ? 0.92 : 0.35))
                    .frame(width: 4, height: 10 + levels[index] * 26)
            }
        }
        .onAppear { refreshLevels() }
        .onChange(of: isActive) { _, active in
            if active {
                refreshLevels()
            } else {
                levels = Array(repeating: 0.2, count: levels.count)
            }
        }
    }

    private func refreshLevels() {
        guard isActive, !timerActive else { return }
        timerActive = true
        Task {
            while !Task.isCancelled {
                await MainActor.run {
                    guard isActive else {
                        timerActive = false
                        return
                    }
                    levels = levels.map { _ in CGFloat.random(in: 0.18...1.0) }
                }
                try? await Task.sleep(for: .milliseconds(140))
            }
            await MainActor.run { timerActive = false }
        }
    }
}

struct ProfileEditView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingVoiceSession = false
    @State private var showingTypedUpdate = false
    @State private var selectedSignal: ProfileSignalLabel?

    private var signalColumns: [GridItem] {
        [GridItem(.flexible())]
    }

    private var interestColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 120), spacing: 8)]
    }

    private var introduction: String {
        if dynamicTypeSize.isAccessibilitySize {
            return "Private and revisable—not scores."
        }
        return "These are working interpretations from what you chose to share—not fixed facts. They help Likeminded suggest rooms and people, and they are never shown as scores."
    }

    private func correctSignalButton(_ item: ProfileSignalLabel) -> some View {
        Button {
            selectedSignal = item
        } label: {
            Label("Edit", systemImage: "pencil")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.accent)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(PrototypePalette.accentSoft)
                .clipShape(Capsule(style: .continuous))
                .dynamicTypeSize(.xSmall ... .accessibility1)
        }
        .accessibilityLabel("Edit or remove \(item.title) interpretation")
    }

    private var typedUpdateModeButton: some View {
        Button {
            showingTypedUpdate = true
        } label: {
            Label("Type update", systemImage: "keyboard")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.accent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PrototypePalette.accentSoft)
                .clipShape(Capsule(style: .continuous))
                .dynamicTypeSize(.xSmall ... .accessibility1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile-update-with-text")
    }

    private var voiceUpdateModeButton: some View {
        Button {
            showingVoiceSession = true
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--likeminded-dev-voice-preview") {
                appState.seedVoiceSessionPreviewIfNeeded()
                return
            }
            #endif
            Task { await appState.startVoiceSession() }
        } label: {
            Label("Use voice", systemImage: "waveform")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.accent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PrototypePalette.accentSoft)
                .clipShape(Capsule(style: .continuous))
                .dynamicTypeSize(.xSmall ... .accessibility1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Update profile with voice")
        .accessibilityIdentifier("profile-update-with-voice")
    }

    @ViewBuilder
    private var updateModeButtons: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                typedUpdateModeButton
                voiceUpdateModeButton
            }
        } else {
            HStack(spacing: 10) {
                typedUpdateModeButton
                voiceUpdateModeButton
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text("Living profile".uppercased())
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)
                    }
                    Text(dynamicTypeSize.isAccessibilitySize ? "Profile." : "A private, evolving read of you.")
                        .font(dynamicTypeSize.isAccessibilitySize ? PrototypeTypography.sectionTitle : PrototypeTypography.pageTitle)
                        .foregroundStyle(PrototypePalette.ink)
                        .dynamicTypeSize(.xSmall ... .accessibility1)
                        .accessibilityAddTraits(.isHeader)
                    Text(introduction)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.subink)
                        .fixedSize(horizontal: false, vertical: true)

                    Label("Private to you", systemImage: "lock.fill")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.accent)
                }

                updateModeButtons

                FeatureCard(
                    title: dynamicTypeSize.isAccessibilitySize ? "Interpretations" : "What we understood",
                    eyebrow: dynamicTypeSize.isAccessibilitySize ? "Review or remove" : "From your voice"
                ) {
                    let visibleSignals = ProfileSignalFormatting.cards(from: appState.slice?.signals)
                        .filter { $0.value != "From voice profile" }
                    if visibleSignals.isEmpty {
                        Text("No interpretations are being used. You can update again whenever you want.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                    } else {
                        LazyVGrid(columns: signalColumns, spacing: 0) {
                            ForEach(visibleSignals) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.title)
                                        .font(PrototypeTypography.metadata)
                                        .foregroundStyle(PrototypePalette.subink)
                                    if dynamicTypeSize.isAccessibilitySize {
                                        Text(item.value)
                                            .font(PrototypeTypography.bodyStrong)
                                            .foregroundStyle(PrototypePalette.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                        correctSignalButton(item)
                                    } else {
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Text(item.value)
                                                .font(PrototypeTypography.bodyStrong)
                                                .foregroundStyle(PrototypePalette.ink)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Spacer(minLength: 8)
                                            correctSignalButton(item)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(PrototypePalette.rule)
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }

                FeatureCard(title: "Interests", eyebrow: "Private") {
                    let interests = appState.slice?.profile.interests.map(\.label) ?? []
                    if interests.isEmpty {
                        Text("Interests appear after your voice profile.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                    } else {
                        LazyVGrid(columns: interestColumns, alignment: .leading, spacing: 8) {
                            ForEach(interests, id: \.self) { interest in
                                Text(interest)
                                    .font(PrototypeTypography.metadata)
                                    .foregroundStyle(PrototypePalette.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(PrototypePalette.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                            }
                        }
                    }

                    Divider().overlay(PrototypePalette.rule)

                    if let confirmation = appState.profileUpdateConfirmation {
                        Label(confirmation, systemImage: "checkmark.circle.fill")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.accent)
                            .accessibilityIdentifier("profile-update-confirmation")
                    }

                    Text("Latest update")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)

                    Text(appState.slice?.profile.reflection.summary ?? "Complete your voice profile to see your private read.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PrototypeBackButton(label: "Back to profile")
            }
        }
        .toolbarBackground(PrototypePalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .statusBarHidden(dynamicTypeSize.isAccessibilitySize)
        .likemindedTabBarHidden()
        .preferredColorScheme(.light)
        .fullScreenCover(isPresented: $showingVoiceSession) {
            VoiceProfileSessionSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingTypedUpdate) {
            TypedProfileUpdateSheet(initialValue: "")
            .environmentObject(appState)
        }
        .sheet(item: $selectedSignal) { signal in
            TypedProfileUpdateSheet(signal: signal, initialValue: signal.value)
                .environmentObject(appState)
        }
    }
}

struct ProfileSignalsView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingVoiceSession = false

    private var signalColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ScreenContainer(
            title: "Private signals",
            subtitle: "What Likeminded understood.",
            caption: "Working interpretations from your voice and choices. They guide private suggestions, are not shown to other people, and can change when you update your profile."
        ) {
            LazyVGrid(columns: signalColumns, spacing: 10) {
                ForEach(ProfileSignalFormatting.cards(from: appState.slice?.signals)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.subink)
                        Text(item.value)
                            .font(PrototypeTypography.bodyStrong)
                            .foregroundStyle(PrototypePalette.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(PrototypePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                }
            }

            Button {
                showingVoiceSession = true
                Task { await appState.startVoiceSession() }
            } label: {
                Label("Update these signals", systemImage: "waveform")
                    .font(PrototypeTypography.button)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(PrototypePalette.accent)
                    .background(PrototypePalette.surface)
                    .clipShape(Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Update profile signals with voice")
            .accessibilityIdentifier("signals-update-with-voice")
        }
        .toolbar(.hidden, for: .navigationBar)
        .prototypeBackNavigation(label: "Back to profile")
        .likemindedTabBarHidden()
        .sheet(isPresented: $showingVoiceSession) {
            VoiceProfileSessionSheet()
                .environmentObject(appState)
        }
    }
}

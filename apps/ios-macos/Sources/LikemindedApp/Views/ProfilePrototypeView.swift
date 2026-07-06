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

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Profile", subtitle: "Who you are.") {
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
        HStack(alignment: .firstTextBaseline) {
            Text(profileHeaderText)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)

            Spacer()

            NavigationLink(value: ProfileRoute.settings) {
                Image(systemName: "gearshape")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
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

    private var profileHeaderText: String {
        guard let info = appState.slice?.profile.basicInfo ?? appState.basicInfo else {
            return "Start with the basics"
        }

        var parts = [info.name, info.gender.label]
        if let parsed = LikemindedDate.parse(info.dateOfBirth) {
            let age = Calendar.current.dateComponents([.year], from: parsed, to: Date()).year ?? 0
            if age > 0 {
                parts.append("\(age)")
            }
        }
        parts.append(info.city)
        return parts
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
    }

    private var profileInterests: [Interest] {
        appState.slice?.profile.interests ?? []
    }

    private var profileTraits: [ProfileTraitRowModel] {
        let bigFive = appState.slice?.signals?.bigFive ?? ProfileSignals.BigFive()
        let socialEnergy = appState.slice?.signals?.socialEnergy ?? "steady"
        let trustPattern = appState.slice?.signals?.trustPattern ?? "slowTrust"

        let energyValue: Double = {
            switch socialEnergy.lowercased() {
            case "high": return 0.78
            case "low": return 0.32
            default: return 0.50
            }
        }()

        let trustValue: Double = trustPattern.lowercased() == "fasttrust" ? 0.74 : 0.36

        return [
            ProfileTraitRowModel(left: "Reserved", right: "Outgoing", value: bigFive.extraversion),
            ProfileTraitRowModel(left: "Analytical", right: "Intuitive", value: bigFive.openness),
            ProfileTraitRowModel(left: "Low Energy", right: "High Energy", value: energyValue),
            ProfileTraitRowModel(left: "Steady", right: "Spontaneous", value: 1.0 - bigFive.conscientiousness),
            ProfileTraitRowModel(left: "Slow Trust", right: "Fast Trust", value: trustValue)
        ]
    }

    private var communicationReadTitle: String {
        let primary = appState.slice?.signals?.communicationStyle?.primary?.lowercased() ?? ""
        switch primary {
        case "warm": return "Warm Communicator"
        case "direct": return "Direct Communicator"
        case "expressive": return "Expressive Communicator"
        case "analytical": return "Thoughtful Communicator"
        default: return "Honest Communicator"
        }
    }

    private var communicationReadDetail: String {
        let primary = appState.slice?.signals?.communicationStyle?.primary?.lowercased() ?? ""
        switch primary {
        case "warm": return "You lead with care and make people feel heard."
        case "direct": return "You value clarity and get to the point with ease."
        case "expressive": return "You bring energy and openness to conversations."
        case "analytical": return "You think before you speak and notice what others miss."
        default: return "You value clarity and depth in conversations."
        }
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Signals".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(PrototypePalette.accent)
                    Text("Living profile")
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(PrototypePalette.ink)
                }

                Spacer()

                Button("Update profile") {
                    showingVoiceSession = true
                    Task { await appState.startVoiceSession() }
                }
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PrototypePalette.surface)
                .clipShape(Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                .buttonStyle(.plain)
                .accessibilityLabel("Update profile")
            }

            HStack(spacing: 10) {
                ProfileSignalPill("Communication", selected: true)
                ProfileSignalPill("Energy")
                ProfileSignalPill("Trust")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Communication, Energy, Trust")

            HStack(spacing: 14) {
                Image(systemName: "ellipsis.message")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(PrototypePalette.accent)
                    .frame(width: 60, height: 60)
                    .background(PrototypePalette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(communicationReadTitle)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)
                    Text(communicationReadDetail)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.ink)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrototypePalette.subink)
            }
            .padding(16)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(communicationReadTitle). \(communicationReadDetail)")
            .accessibilityAddTraits(.isStaticText)

            VStack(spacing: 15) {
                ForEach(profileTraits, id: \.left) { trait in
                    ProfileTraitRow(left: trait.left, right: trait.right, value: trait.value)
                }
            }

            Divider().overlay(PrototypePalette.rule)

            VStack(alignment: .leading, spacing: 14) {
                Text("Interests".uppercased())
                    .font(PrototypeTypography.eyebrow)
                    .foregroundStyle(PrototypePalette.accent)
                Text("What you're into")
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)

                if profileInterests.isEmpty {
                    Text("No interests detected yet. Update your voice profile to refine.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                } else {
                    ProfileInterestTagLayout(interests: profileInterests)
                }
            }
        }
        .padding(18)
        .background(PrototypePalette.surface.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
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

private struct VoiceProfileSessionSheet: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss

    private var statusLine: String {
        switch appState.realtimeStatus {
        case RealtimeVoicePhase.streaming.rawValue:
            return "I am listening for fit."
        case RealtimeVoicePhase.connecting.rawValue, RealtimeVoicePhase.stopping.rawValue:
            return appState.realtimeStatus + "…"
        case RealtimeVoicePhase.stopped.rawValue:
            return "Signals captured."
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
                        Text(statusLine)
                            .font(PrototypeTypography.body)
                            .foregroundStyle(.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                    .padding(.top, 8)

                    VoiceListeningCard(isActive: appState.isVoiceStreaming || appState.realtimeStatus == RealtimeVoicePhase.streaming.rawValue)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Voice orb")
                        .accessibilityValue(appState.isVoiceStreaming ? "Listening" : appState.realtimeStatus)

                    VoiceWaveformBars(isActive: appState.isVoiceStreaming || appState.realtimeStatus == RealtimeVoicePhase.streaming.rawValue)
                        .frame(height: 36)
                        .accessibilityHidden(true)

                    if let error = appState.realtimeError, !error.isEmpty {
                        Text(error)
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

                                    Circle()
                                        .fill(PrototypePalette.success)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 8)
                                }
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        Task { await appState.stopVoiceSession() }
                    } label: {
                        Label("Stop and extract signals", systemImage: "stop.fill")
                            .font(PrototypeTypography.button)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(PrototypePalette.actionGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop")

                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .font(PrototypeTypography.button)
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PrototypePalette.success)
                        Text("Profile read is private. Circle placement needs confirmation.")
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
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            appState.seedVoiceSessionPreviewIfNeeded()
        }
    }
}

private struct ProfileInterestTagLayout: View {
    let interests: [Interest]

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                ForEach(interests, id: \.label) { interest in
                    ProfileInterestTag(interest: interest)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(interests, id: \.label) { interest in
                    ProfileInterestTag(interest: interest)
                }
            }
        }
    }
}

private struct ProfileInterestTag: View {
    let interest: Interest

    private var isEmphasized: Bool {
        interest.depth == .deep || interest.depth == .active
    }

    var body: some View {
        Text(interest.label)
            .font(PrototypeTypography.metadata)
            .foregroundStyle(isEmphasized ? .white : PrototypePalette.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isEmphasized ? PrototypePalette.accent : PrototypePalette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isEmphasized ? Color.clear : PrototypePalette.rule, lineWidth: 1)
            )
    }
}

private struct ProfileSignalPill: View {
    let title: String
    let selected: Bool

    init(_ title: String, selected: Bool = false) {
        self.title = title
        self.selected = selected
    }

    var body: some View {
        Text(title)
            .font(PrototypeTypography.metadata)
            .foregroundStyle(selected ? .white : PrototypePalette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selected ? PrototypePalette.actionGradient : LinearGradient(colors: [Color.black.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            .clipShape(Capsule(style: .continuous))
    }
}

private struct ProfileTraitRowModel {
    let left: String
    let right: String
    let value: Double
}

private struct ProfileTraitRow: View {
    let left: String
    let right: String
    let value: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(left)
                .frame(width: 86, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PrototypePalette.rule)
                        .frame(height: 2)

                    Capsule()
                        .fill(PrototypePalette.accent)
                        .frame(width: proxy.size.width * value, height: 2)

                    Circle()
                        .fill(PrototypePalette.accent)
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, proxy.size.width * value - 6))
                }
            }
            .frame(height: 12)

            Text(right)
                .frame(width: 92, alignment: .trailing)
        }
        .font(PrototypeTypography.metadata)
        .foregroundStyle(PrototypePalette.ink)
    }
}

private struct VoiceListeningCard: View {
    var isActive = false

    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(PrototypePalette.success.opacity(isActive ? 0.22 : 0.12), lineWidth: 1)
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
                        colors: [PrototypePalette.success.opacity(isActive ? 0.78 : 0.64), PrototypePalette.accent.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: isActive ? 124 : 112
                    )
                )
                .frame(width: isActive ? 228 : 216, height: isActive ? 228 : 216)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isActive && pulse)

            Image(systemName: "sparkle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: PrototypePalette.success, radius: isActive ? 18 : 10)

            Circle()
                .fill(PrototypePalette.success.opacity(0.85))
                .frame(width: 26, height: 26)
                .shadow(color: PrototypePalette.success, radius: isActive ? 28 : 24)
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

    private var profileTraits: [ProfileTraitRowModel] {
        let bigFive = appState.slice?.signals?.bigFive ?? ProfileSignals.BigFive()
        return [
            ProfileTraitRowModel(left: "Reserved", right: "Outgoing", value: bigFive.extraversion),
            ProfileTraitRowModel(left: "Analytical", right: "Intuitive", value: bigFive.openness),
            ProfileTraitRowModel(left: "Steady", right: "Spontaneous", value: 1.0 - bigFive.conscientiousness),
            ProfileTraitRowModel(left: "Guarded", right: "Warm", value: bigFive.agreeableness),
            ProfileTraitRowModel(left: "Steady mood", right: "Reactive", value: bigFive.neuroticism)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Living profile")
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(.white)
                    Text("Read-only signals from your voice profile")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 10) {
                        ForEach(ProfileSignalFormatting.cards(from: appState.slice?.signals).prefix(3)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(PrototypeTypography.metadata)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(item.value)
                                    .font(PrototypeTypography.bodyStrong)
                                    .foregroundStyle(.white)
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(profileTraits, id: \.left) { trait in
                            ProfileTraitRow(left: trait.left, right: trait.right, value: trait.value)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(20)
                .background(PrototypePalette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                FeatureCard(title: "Interests", eyebrow: "Private") {
                    let interests = appState.slice?.profile.interests.map(\.label) ?? []
                    if interests.isEmpty {
                        Text("Interests appear after your voice profile.")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                    } else {
                        FlexibleTagLayout(items: interests)
                    }

                    Divider().overlay(PrototypePalette.rule)

                    Text(appState.slice?.profile.reflection.summary ?? "Complete your voice profile to see your private read.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .navigationTitle("Who you are")
        .navigationBarTitleDisplayMode(.inline)
        .prototypeBackNavigation(label: "Back to profile")
    }
}

struct ProfileSignalsView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenContainer(title: "Your personality signals", subtitle: "From your voice, activity, and choices.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
                dismiss()
            } label: {
                PrimaryActionButton(title: "Done", systemImage: "checkmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
        }
        .toolbar(.hidden, for: .navigationBar)
        .prototypeBackNavigation()
    }
}

import SwiftUI

private enum ProfileRoute: Hashable {
    case edit
    case signals
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

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Profile", subtitle: "Who you are.") {
                profileHeader

                if appState.slice == nil {
                    OnboardingView()
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
        }
    }

    private var profileHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(profileHeaderText)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)

            Spacer()

            NavigationLink {
                SettingsPrototypeView()
            } label: {
                Image(systemName: "gearshape")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var profileHeaderText: String {
        guard let info = appState.slice?.profile.basicInfo ?? appState.basicInfo else {
            return "Start with the basics"
        }

        return [info.name, info.gender.label, info.city]
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

    private var startVoiceButton: some View {
        Button {
            showingVoiceSession = true
            Task { await appState.startVoiceSession() }
        } label: {
            PrimaryActionButton(
                title: appState.isStartingVoice ? "Opening voice profile" : "Start voice profile",
                systemImage: "waveform"
            )
            .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .disabled(appState.isStartingVoice)
        .accessibilityLabel("Start voice profile")
    }

    private var placementConcernCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Circle feels off".uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            Text(appState.placementConcern)
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
            profileHubCard

            FeatureCard(title: "Personality signals", eyebrow: "Private") {
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
                        .background(PrototypePalette.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Button {
                    showingVoiceSession = true
                    Task { await appState.startVoiceSession() }
                } label: {
                    SecondaryActionButton(title: "Retake voice profile", systemImage: "waveform")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retake voice profile")
            }

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
            }
            .padding(16)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))

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
                    FlexibleTagLayout(items: profileInterests.map { $0.label })
                }
            }
        }
    }

    private var profileHubCard: some View {
        let name = appState.slice?.profile.basicInfo?.name ?? appState.basicInfo?.name ?? "You"
        let city = appState.slice?.profile.basicInfo?.city ?? appState.basicInfo?.city ?? "Your location"
        let circleCount = max(appState.joinedCircles.count, appState.placementId == nil ? 0 : 1)
        let connectionCount = appState.soulmateMatches.count
        let eventCount = appState.upcomingMeetings.count + appState.pastMeetings.count

        return VStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 84, height: 84)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(PrototypeTypography.hero)
                        .foregroundStyle(.white)
                }

            Text(name)
                .font(PrototypeTypography.cardTitle)
                .foregroundStyle(.white)

            Label(city, systemImage: "mappin")
                .font(PrototypeTypography.caption)
                .foregroundStyle(.white.opacity(0.85))

            Label("Voice profile active", systemImage: "waveform")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.16))
                .clipShape(Capsule(style: .continuous))

            HStack(spacing: 0) {
                profileStat(value: "\(circleCount)", label: "Circles")
                profileStat(value: "\(connectionCount)", label: "Connections")
                profileStat(value: "\(eventCount)", label: "Events")
            }

            HStack(spacing: 12) {
                NavigationLink(value: ProfileRoute.signals) {
                    Text("Share profile")
                        .font(PrototypeTypography.button)
                        .foregroundStyle(PrototypePalette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share profile")

                NavigationLink(value: ProfileRoute.edit) {
                    Text("Edit profile")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white.opacity(0.9))
                        .underline()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit profile")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(PrototypePalette.roomGradient(1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileVoiceEmptyCard: View {
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

            Label("Start voice profile", systemImage: "waveform")
                .font(PrototypeTypography.button)
                .foregroundStyle(PrototypePalette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.88))
                .clipShape(Capsule(style: .continuous))
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

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Voice profile", subtitle: "Speak naturally.") {
                ProfileVoiceEmptyCard()

                FeatureCard(title: "Realtime status", eyebrow: "Voice") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(appState.realtimeStatus, systemImage: appState.isVoiceStreaming ? "waveform" : "waveform.circle")
                            .font(PrototypeTypography.bodyStrong)
                            .foregroundStyle(PrototypePalette.ink)

                        if let error = appState.realtimeError, !error.isEmpty {
                            Text(error)
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.amber)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("The profile updates from the backend voice session when realtime is available.")
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.subink)
                        }

                        if !appState.realtimeTranscript.isEmpty {
                            Text(appState.realtimeTranscript)
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await appState.stopVoiceSession() }
                    } label: {
                        SecondaryActionButton(title: "Stop", systemImage: "stop.circle")
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        PrimaryActionButton(title: "Done", systemImage: "checkmark")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .stroke(PrototypePalette.success.opacity(0.12), lineWidth: 1)
                    .frame(width: CGFloat(112 + index * 38), height: CGFloat(112 + index * 38))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [PrototypePalette.success.opacity(0.64), PrototypePalette.accent.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 6,
                        endRadius: 112
                    )
                )
                .frame(width: 216, height: 216)

            Circle()
                .fill(PrototypePalette.success.opacity(0.85))
                .frame(width: 26, height: 26)
                .shadow(color: PrototypePalette.success, radius: 24)
        }
        .frame(height: 260)
    }
}

struct ProfileEditView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss

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

                Button {
                    dismiss()
                } label: {
                    PrimaryActionButton(title: "Back to profile", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to profile")
            }
            .padding(20)
        }
        .background(PrototypePalette.background.ignoresSafeArea())
        .navigationTitle("Who you are")
        .navigationBarTitleDisplayMode(.inline)
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
    }
}

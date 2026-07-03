import SwiftUI

struct VoiceProfileView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var showingVoiceSession = false

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Profile", subtitle: "Who you are.") {
                profileHeader

                if appState.slice == nil, appState.basicInfo == nil {
                    OnboardingView()
                } else if appState.slice == nil {
                    ProfileVoiceEmptyCard()
                    startVoiceButton
                } else {
                    if appState.concernFlag {
                        placementConcernCard
                    }
                    livingProfile
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingVoiceSession) {
                VoiceProfileSessionSheet()
                    .environmentObject(appState)
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
                Image(systemName: "pencil")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
            }
            .buttonStyle(.plain)
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
            }

            HStack(spacing: 10) {
                ProfileSignalPill("Communication", selected: true)
                ProfileSignalPill("Energy")
                ProfileSignalPill("Trust")
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

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(PrototypePalette.ink)
            }
            .padding(16)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))

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
                    FlexibleTagLayout(items: profileInterests.map { $0.label })
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

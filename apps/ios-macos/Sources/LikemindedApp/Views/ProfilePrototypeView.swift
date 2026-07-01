import SwiftUI

struct VoiceProfileView: View {
    @EnvironmentObject private var appState: PrototypeAppState

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

    private var startVoiceButton: some View {
        Button {
            Task { await appState.startVoiceSession() }
        } label: {
            PrimaryActionButton(
                title: appState.isStartingVoice ? "Opening voice profile" : "Start voice profile",
                systemImage: "waveform"
            )
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
                Task { await appState.startReinterview() }
            } label: {
                PrimaryActionButton(
                    title: appState.isStartingVoice ? "Opening voice" : "Re-interview for placement",
                    systemImage: "waveform"
                )
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
                    Text("Honest Communicator")
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)
                    Text("You value clarity and depth in conversations.")
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
                ProfileTraitRow(left: "Reserved", right: "Outgoing", value: 0.55)
                ProfileTraitRow(left: "Analytical", right: "Intuitive", value: 0.66)
                ProfileTraitRow(left: "Low Energy", right: "High Energy", value: 0.44)
                ProfileTraitRow(left: "Steady", right: "Spontaneous", value: 0.58)
                ProfileTraitRow(left: "Slow Trust", right: "Fast Trust", value: 0.50)
            }

            Divider().overlay(PrototypePalette.rule)

            VStack(alignment: .leading, spacing: 14) {
                Text("Interests".uppercased())
                    .font(PrototypeTypography.eyebrow)
                    .foregroundStyle(PrototypePalette.accent)
                Text("What you're into")
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)

                FlexibleTagLayout(items: ["Jazz", "Essays", "Psychology", "Design", "Cooking", "Movies", "Trekking"])
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

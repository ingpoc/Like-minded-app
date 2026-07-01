import SwiftUI

struct VoiceProfileView: View {
    @State private var hasEntered = false
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Profile",
                subtitle: "Voice. Then place."
            ) {
                if appState.concernFlag {
                    reinterviewPrompt
                        .likemindedEntrance(order: 0, isActive: hasEntered, y: 12, scale: 0.98)
                }

                voiceHero
                    .likemindedEntrance(order: 1, isActive: hasEntered, y: 16, scale: 0.97)

                profileSignals
                    .likemindedEntrance(order: 2, isActive: hasEntered, y: 14, scale: 0.98)

                voiceSignalCapture
                    .likemindedEntrance(order: 3, isActive: hasEntered, y: 14, scale: 0.98)
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Image(systemName: "lock.shield")
                    }
                    .accessibilityLabel("Privacy state")
                }
            }
        }
        .task {
            guard !hasEntered else { return }
            hasEntered = true
        }
    }

    private var voiceHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VoiceOrbView(status: appState.realtimeStatus)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Voice profile")
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(Color.white.opacity(0.72))

                    Text(voiceTitle)
                        .font(PrototypeTypography.hero)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)
            }

            Text("Speak naturally. The profile updates as you talk.")
                .font(PrototypeTypography.body)
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ProfileStatusBadge(title: appState.realtimeStatus, systemImage: statusIcon)
                ProfileStatusBadge(title: appState.sourceLabel, systemImage: "point.3.connected.trianglepath.dotted")
            }

            Button {
                Task {
                    if appState.isVoiceStreaming {
                        await appState.stopVoiceSession()
                    } else {
                        await appState.startVoiceSession()
                    }
                }
            } label: {
                PrimaryActionButton(
                    title: voiceButtonTitle,
                    systemImage: voiceButtonIcon
                )
            }
            .buttonStyle(.plain)
            .disabled(appState.isStartingVoice)

            if let realtimeError = appState.realtimeError {
                Text(realtimeError)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PrototypePalette.accent)
        )
        .shadow(color: PrototypePalette.accent.opacity(0.18), radius: 22, y: 14)
    }

    private var reinterviewPrompt: some View {
        FeatureCard(title: "Let's re-evaluate your placement", eyebrow: "Circle concern") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep your current read, then add a fresh voice pass so placement can adjust.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task {
                        await appState.startReinterview()
                    }
                } label: {
                    PrimaryActionButton(title: "Start re-interview", systemImage: "waveform")
                }
                .buttonStyle(.plain)
                .disabled(appState.isStartingVoice)
            }
        }
    }

    private var voiceSignalCapture: some View {
        FeatureCard(title: "Captured voice", eyebrow: "Onboarding") {
            VStack(alignment: .leading, spacing: 14) {
                if appState.capturedVoiceSignals.isEmpty {
                    EmptyCapturedSignalsRow()
                } else {
                    ForEach(Array(appState.capturedVoiceSignals.enumerated()), id: \.offset) { index, signal in
                        CapturedSignalRow(index: index + 1, signal: signal)
                    }
                }

                Button {
                    Task {
                        await appState.synthesizePlacementFromVoice()
                    }
                } label: {
                    PrimaryActionButton(
                        title: appState.isSynthesizingPlacement ? "Placing you" : "Use voice for placement",
                        systemImage: appState.isSynthesizingPlacement ? "hourglass" : "person.3.sequence.fill"
                    )
                }
                .buttonStyle(.plain)
                .disabled(appState.isSynthesizingPlacement || !appState.hasCapturedVoiceSignals)
                .opacity(appState.hasCapturedVoiceSignals ? 1 : 0.56)
            }
        }
    }

    private var profileSignals: some View {
        FeatureCard(title: "Living profile", eyebrow: "Signals") {
            VStack(alignment: .leading, spacing: 14) {
                signalRead

                bigFiveScores
                    .likemindedEntrance(order: 2, isActive: hasEntered, y: 8, scale: 0.98)

                interestTags

                Text("Private to you. Hidden placement signals are used for room fit, not shown as profile copy.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var signalRead: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: signalIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(PrototypePalette.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(signalValue)
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)
                Text(signalDetail)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }

    private var bigFiveScores: some View {
        let signals = appState.slice?.signals
        let bigFive = signals?.bigFive ?? ProfileSignals.BigFive()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Personality traits")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)

            VStack(spacing: 10) {
                TraitBar(leftLabel: "Concrete", rightLabel: "Curious", value: bigFive.openness)
                TraitBar(leftLabel: "Flexible", rightLabel: "Intentional", value: bigFive.conscientiousness)
                TraitBar(leftLabel: "Reserved", rightLabel: "Outgoing", value: bigFive.extraversion)
                TraitBar(leftLabel: "Direct", rightLabel: "Warm", value: bigFive.agreeableness)
                TraitBar(leftLabel: "Steady", rightLabel: "Sensitive", value: bigFive.neuroticism)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }

    private var interestTags: some View {
        let interests = appState.activeSlice.profile.interests

        return VStack(alignment: .leading, spacing: 10) {
            Text("Interests")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)

            if interests.isEmpty {
                Text("Voice will add interests as you talk.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            } else {
                ViewThatFits(in: .vertical) {
                    HStack(spacing: 8) {
                        ForEach(interests) { interest in
                            InterestTagChip(interest: interest)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(interests) { interest in
                            InterestTagChip(interest: interest)
                        }
                    }
                }
            }
        }
    }

    private var placementPreview: some View {
        let placement = appState.currentPlacement
        let circle = placement.primaryCircle

        return FeatureCard(title: "First room", eyebrow: "Placement") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(PrototypePalette.accent)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(circle.name)
                            .font(PrototypeTypography.sectionTitle)
                            .foregroundStyle(PrototypePalette.ink)

                        Text(circle.roomEnergy)
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    StatPill(value: circle.fitLabel, label: "Fit")
                    StatPill(value: placement.userState.rawValue.capitalized, label: "State")
                    StatPill(value: placement.confidenceLabel, label: "Confidence")
                }

                TokenRow(items: Array(placement.sourceReflectionSignals.prefix(3)))

                HStack(spacing: 10) {
                    Button {
                        appState.acceptPlacement()
                    } label: {
                        SecondaryActionButton(title: "Accept", systemImage: "checkmark")
                    }
                    .buttonStyle(.plain)

                    Button {
                        appState.deferPlacement()
                    } label: {
                        SecondaryActionButton(title: "Defer", systemImage: "clock")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var voiceTitle: String {
        switch appState.realtimeStatus {
        case "Listening":
            return "I am listening for fit."
        case "Placing":
            return "I am extracting signals."
        case "Captured":
            return "Signals are ready."
        case "Opening":
            return "Opening the room."
        case "Needs server key":
            return "Voice is waiting on the server."
        case "Offline":
            return "Voice needs the API."
        default:
            return "Tell me how you connect."
        }
    }

    private var statusIcon: String {
        switch appState.realtimeStatus {
        case "Listening":
            return "checkmark.circle.fill"
        case "Placing":
            return "arrow.triangle.2.circlepath"
        case "Captured":
            return "text.badge.checkmark"
        case "Opening":
            return "hourglass"
        case "Needs server key":
            return "key.fill"
        case "Offline":
            return "wifi.slash"
        default:
            return "mic.fill"
        }
    }

    private var voiceButtonTitle: String {
        if appState.isStartingVoice {
            return "Opening voice"
        }

        if appState.isVoiceStreaming {
            return "Stop and extract signals"
        }

        return "Start voice profile"
    }

    private var voiceButtonIcon: String {
        if appState.isStartingVoice {
            return "hourglass"
        }

        if appState.isVoiceStreaming {
            return "stop.fill"
        }

        return "waveform"
    }

    private var signalValue: String {
        let profile = appState.activeSlice.profile
        return profile.communicationStyle.capitalized
    }

    private var signalDetail: String {
        let signals = appState.slice?.signals
        let parts = [
            signals?.communicationStyle?.primary,
            signals?.socialEnergy,
            signals?.trustPattern
        ].compactMap { $0 }
        return parts.isEmpty ? "Not read yet" : parts.joined(separator: " · ")
    }

    private var signalIcon: String {
        return "text.bubble.fill"
    }
}

private struct ProfileStatusBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(PrototypeTypography.metadata)
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.14))
            .clipShape(Capsule(style: .continuous))
    }
}

private struct CapturedSignalRow: View {
    let index: Int
    let signal: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(PrototypePalette.accent)
                .clipShape(Circle())

            Text(signal)
                .font(PrototypeTypography.body)
                .foregroundStyle(PrototypePalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }
}

private struct EmptyCapturedSignalsRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 38, height: 38)
                .background(PrototypePalette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("Start voice profile to capture the first personality signals.")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }
}

private struct TraitBar: View {
    let leftLabel: String
    let rightLabel: String
    let value: Double

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(LinearGradient(colors: [PrototypePalette.accent, PrototypePalette.accent.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * min(max(value, 0), 1)))
                }
            }
            .frame(height: 9)

            HStack {
                Text(leftLabel)
                Spacer()
                Text(rightLabel)
            }
            .font(.caption2)
            .foregroundStyle(PrototypePalette.subink)
        }
    }
}

private struct InterestTagChip: View {
    let interest: Interest

    var body: some View {
        Text(interest.label)
            .font(PrototypeTypography.metadata)
            .foregroundStyle(foreground)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Capsule(style: .continuous).fill(background))
            .overlay(Capsule(style: .continuous).stroke(border, lineWidth: 1))
    }

    private var foreground: Color {
        switch interest.depth {
        case .deep:
            return .white
        case .active:
            return PrototypePalette.accent
        case .casual:
            return PrototypePalette.subink
        }
    }

    private var background: Color {
        switch interest.depth {
        case .deep:
            return PrototypePalette.accent
        case .active:
            return .clear
        case .casual:
            return PrototypePalette.surface
        }
    }

    private var border: Color {
        switch interest.depth {
        case .deep, .casual:
            return .clear
        case .active:
            return PrototypePalette.accent
        }
    }
}

import SwiftUI

struct ReflectionPrototypeView: View {
    @State private var hasEntered = false
    @State private var selectedSignal = "Communication"
    @EnvironmentObject private var appState: PrototypeAppState

    private let signalTabs = ["Communication", "Energy", "Trust"]

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Talk",
                subtitle: "Voice first. Profile signals stay private until you confirm placement."
            ) {
                voiceHero
                    .likemindedEntrance(order: 0, isActive: hasEntered, y: 16, scale: 0.97)

                profileSignals
                    .likemindedEntrance(order: 1, isActive: hasEntered, y: 14, scale: 0.98)

                placementPreview
                    .likemindedEntrance(order: 2, isActive: hasEntered, y: 14, scale: 0.98)

                voiceSignalCapture
                    .likemindedEntrance(order: 3, isActive: hasEntered, y: 14, scale: 0.98)
            }
            .navigationTitle("Talk")
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
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 54, height: 54)

                    Image(systemName: appState.voiceIsReady ? "waveform" : "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

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

            Text("The first conversation should learn tone, pace, trust, humor, and group comfort before suggesting a room.")
                .font(PrototypeTypography.body)
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                VoiceStatusPill(title: appState.realtimeStatus, systemImage: statusIcon)
                VoiceStatusPill(title: appState.sourceLabel, systemImage: "point.3.connected.trianglepath.dotted")
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

    private var voiceSignalCapture: some View {
        FeatureCard(title: "Captured voice", eyebrow: "Onboarding") {
            VStack(alignment: .leading, spacing: 14) {
                if appState.capturedVoiceSignals.isEmpty {
                    EmptyVoiceSignalRow()
                } else {
                    ForEach(Array(appState.capturedVoiceSignals.enumerated()), id: \.offset) { index, signal in
                        VoiceSignalRow(index: index + 1, signal: signal)
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
                SegmentedSignalRow(items: signalTabs, selection: $selectedSignal)

                SignalSummaryRow(
                    title: selectedSignal,
                    value: signalValue,
                    detail: signalDetail,
                    systemImage: signalIcon
                )

                bigFiveScores
                    .likemindedEntrance(order: 2, isActive: hasEntered, y: 8, scale: 0.98)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Reviewable read")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)

                    TextEditor(text: $appState.editedReflection)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.ink)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 92)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PrototypePalette.rule, lineWidth: 1)
                        )

                    Button {
                        // Reflection edits are already in appState.editedReflection
                        // Just mark as saved (no-op for now, persists in-app)
                    } label: {
                        SecondaryActionButton(title: "Save edits", systemImage: "checkmark")
                    }
                    .buttonStyle(.plain)
                }

                PrivacyStrip()
            }
        }
    }

    private var bigFiveScores: some View {
        let signals = appState.slice?.signals
        let bigFive = signals?.bigFive ?? ProfileSignals.BigFive()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Personality traits")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)

            HStack(spacing: 6) {
                BigFiveGauge(label: "O", value: bigFive.openness)
                BigFiveGauge(label: "C", value: bigFive.conscientiousness)
                BigFiveGauge(label: "E", value: bigFive.extraversion)
                BigFiveGauge(label: "A", value: bigFive.agreeableness)
                BigFiveGauge(label: "N", value: bigFive.neuroticism)
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
        switch selectedSignal {
        case "Energy": return profile.emotionalRhythm.capitalized
        case "Trust": return profile.relationshipIntent.capitalized
        default: return profile.communicationStyle.capitalized
        }
    }

    private var signalDetail: String {
        let signals = appState.slice?.signals
        switch selectedSignal {
        case "Energy":
            if let energy = signals?.socialEnergy { return "Social energy: \(energy). The room pacing should match this rhythm." }
            return "How much social energy you bring — from low-key presence to high-energy engagement."
        case "Trust":
            if let trust = signals?.trustPattern { return "Trust pattern: \(trust). Placement should respect this pace." }
            return "How quickly you open up — from cautious and earned to fast and generous trust."
        default:
            if let style = signals?.communicationStyle?.primary { return "Primary style: \(style). Conversations flow most naturally this way." }
            return "How you communicate — from warm and direct to analytical and reflective."
        }
    }

    private var signalIcon: String {
        switch selectedSignal {
        case "Energy": return "bolt.heart.fill"
        case "Trust": return "lock.shield.fill"
        default: return "text.bubble.fill"
        }
    }
}

private struct VoiceStatusPill: View {
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

private struct SegmentedSignalRow: View {
    let items: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    Text(item)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(selection == item ? .white : PrototypePalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(selection == item ? PrototypePalette.accent : PrototypePalette.surface)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(PrototypePalette.rule, lineWidth: selection == item ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SignalSummaryRow: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 42, height: 42)
                .background(PrototypePalette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)

                Text(value)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)

                Text(detail)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }
}

private struct PrivacyStrip: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)

            Text("Profile read is private. Circle placement needs confirmation.")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.accentSoft.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct VoiceSignalRow: View {
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

private struct EmptyVoiceSignalRow: View {
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

private struct BigFiveGauge: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(PrototypePalette.rule, lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(PrototypePalette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PrototypePalette.ink)
            }
            Text("\(Int(value * 100))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PrototypePalette.subink)
        }
        .frame(maxWidth: .infinity)
    }
}

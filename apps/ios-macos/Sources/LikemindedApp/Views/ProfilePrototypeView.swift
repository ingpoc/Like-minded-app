import SwiftUI

struct VoiceProfileView: View {
    @State private var hasEntered = false
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ZStack {
                PrototypePalette.accentDeep.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Spacer()
                            Image(systemName: "ellipsis")
                        }
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.88))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Profile".uppercased())
                                .font(PrototypeTypography.eyebrow)
                                .foregroundStyle(.white.opacity(0.76))
                            Text("Voice profile")
                                .font(PrototypeTypography.hero)
                                .foregroundStyle(.white)
                            Text("Tell me how you connect.")
                                .font(PrototypeTypography.heroBody)
                                .foregroundStyle(.white.opacity(0.86))
                        }

                        VoiceListeningCard()
                            .frame(maxWidth: .infinity)
                            .likemindedEntrance(order: 0, isActive: hasEntered, y: 14, scale: 0.98)

                        Text(voiceLine)
                            .font(PrototypeTypography.bodyStrong)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)

                        VoiceBars()

                        Button {
                            Task {
                                if appState.isVoiceStreaming {
                                    await appState.stopVoiceSession()
                                } else {
                                    await appState.startVoiceSession()
                                }
                            }
                        } label: {
                            Label(voiceButtonTitle, systemImage: appState.isVoiceStreaming ? "stop.fill" : "waveform")
                                .font(PrototypeTypography.button)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.isStartingVoice)

                        capturedSignals

                        HStack(spacing: 14) {
                            Image(systemName: "lock")
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(PrototypePalette.accent.opacity(0.82))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text("Profile read is private.\nCircle placement needs confirmation.")
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle("Profile")
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            guard !hasEntered else { return }
            hasEntered = true
        }
    }

    private var capturedSignals: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Captured signals")
                .font(PrototypeTypography.bodyStrong)
                .foregroundStyle(.white)

            ForEach(Array(signals.enumerated()), id: \.offset) { index, signal in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(PrototypePalette.accent.opacity(0.86))
                        .clipShape(Circle())

                    Text(signal)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(.white)

                    Spacer()

                    Circle()
                        .fill(PrototypePalette.success)
                        .frame(width: 7, height: 7)
                }
                .padding(12)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
    }

    private var signals: [String] {
        let captured = appState.capturedVoiceSignals
        if captured.isEmpty {
            return [
                "Prefers slow, honest conversation",
                "Values steady and thoughtful pacing",
                "Enjoys depth over small talk"
            ]
        }
        return Array(captured.prefix(3))
    }

    private var voiceLine: String {
        appState.realtimeStatus == "Listening" ? "I am listening for fit." : "Ready when you are."
    }

    private var voiceButtonTitle: String {
        if appState.isStartingVoice { return "Opening voice" }
        if appState.isVoiceStreaming { return "Stop and extract signals" }
        return "Start voice profile"
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

            Image(systemName: "sparkle")
                .font(.system(size: 31, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(PrototypePalette.accent.opacity(0.72))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
        }
        .frame(height: 260)
    }
}

private struct VoiceBars: View {
    private let values: [CGFloat] = [0.2, 0.35, 0.22, 0.48, 0.32, 0.62, 0.44, 0.76, 0.55, 0.88, 0.58, 0.34, 0.68, 0.42, 0.54, 0.28, 0.46, 0.36, 0.50, 0.31]

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(PrototypePalette.success.opacity(0.34 + value * 0.55))
                    .frame(width: 3, height: 32 * value)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 42)
    }
}

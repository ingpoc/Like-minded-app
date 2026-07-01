import SwiftUI

struct VoiceOrbView: View {
    let status: String

    private var isListening: Bool { status == "Listening" }
    private var isProcessing: Bool { status == "Opening" || status == "Placing" }
    private var isCaptured: Bool { status == "Captured" }

    var body: some View {
        PhaseAnimator([0.0, 1.0], trigger: status) { phase in
            let amplitude = isListening ? phase : (isProcessing ? 0.35 : 0.08)
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [PrototypePalette.accent, PrototypePalette.accent.opacity(0.18), .clear],
                                center: .center,
                                startRadius: 4,
                                endRadius: 76
                            )
                        )
                        .frame(width: 80 + amplitude * 40, height: 80 + amplitude * 40)

                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: isCaptured ? "checkmark" : "waveform")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                Capsule()
                    .fill(Color.white.opacity(isListening ? 0.8 : 0.28))
                    .frame(width: isListening ? 28 + amplitude * 38 : 30, height: 4)
            }
            .frame(width: 124, height: 96)
            .animation(.easeInOut(duration: 0.25), value: status)
        } animation: { _ in
            .easeInOut(duration: isListening ? 0.7 : 1.2).repeatForever(autoreverses: true)
        }
    }
}

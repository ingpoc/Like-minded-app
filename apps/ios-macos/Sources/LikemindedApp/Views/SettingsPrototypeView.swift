import SwiftUI

struct SafetyPrototypeView: View {
    @State private var controls = PrototypeData.privacyControls

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Safety",
                subtitle: "Privacy, consent, and account controls stay visible from the main flow."
            ) {
                FlexibleTagLayout(items: ["Privacy visible", "Consent clear", "Pause or leave safely"])

                FeatureCard(title: "Privacy controls", eyebrow: "Safety settings") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach($controls) { $control in
                            Toggle(isOn: $control.isEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(control.title)
                                        .font(.headline)

                                    Text(control.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if control.id != controls.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                FeatureCard(title: "Protection actions", eyebrow: "Immediate exits") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Review AI reflection before anything is shared", systemImage: "checkmark.shield")
                        Label("Block or report when a room or person feels wrong", systemImage: "hand.raised.fill")
                        Label("Pause matching without deleting the profile", systemImage: "pause.circle")
                        Label("Delete account and data controls", systemImage: "trash")
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Safety")
        }
    }
}

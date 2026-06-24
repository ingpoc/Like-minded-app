import SwiftUI

struct CirclesPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        let placement = appState.currentPlacement

        NavigationStack {
            ScreenContainer(
                title: "Circles",
                subtitle: "Rooms come first. People and chats arrive after the room feels right."
            ) {
                FlexibleTagLayout(items: ["Primary room", "Secondary options", "Auto-place, user-confirm"])

                Text("Current state: \(stateLabel(placement.userState))")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.accent)

                FeatureCard(title: placement.primaryCircle.name, eyebrow: "Primary room") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(placement.primaryCircle.shortPromise)
                            .font(PrototypeTypography.sectionTitle)
                            .foregroundStyle(PrototypePalette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(placement.primaryCircle.roomEnergy)
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                            .fixedSize(horizontal: false, vertical: true)

                        FlexibleTagLayout(items: [
                            placement.primaryCircle.emotionalPace,
                            placement.primaryCircle.interactionIntent,
                            placement.primaryCircle.socialFormat
                        ])

                        Text("First action: \(placement.primaryCircle.easiestFirstAction)")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                FeatureCard(title: "Other rooms to consider", eyebrow: "Secondary circles") {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(placement.secondaryCircles.enumerated()), id: \.element.id) { index, circle in
                            VStack(alignment: .leading, spacing: 8) {
                                ViewThatFits(in: .vertical) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(circle.name)
                                            .font(PrototypeTypography.bodyStrong)
                                            .foregroundStyle(PrototypePalette.ink)

                                        Spacer(minLength: 12)

                                        Text(circle.fitLabel)
                                            .font(PrototypeTypography.metadata)
                                            .foregroundStyle(PrototypePalette.subink)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(circle.name)
                                            .font(PrototypeTypography.bodyStrong)
                                            .foregroundStyle(PrototypePalette.ink)

                                        Text(circle.fitLabel)
                                            .font(PrototypeTypography.metadata)
                                            .foregroundStyle(PrototypePalette.subink)
                                    }
                                }

                                Text(circle.shortPromise)
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(PrototypePalette.subink)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(circle.easiestFirstAction)
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(PrototypePalette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if index != placement.secondaryCircles.count - 1 {
                                Rectangle()
                                    .fill(PrototypePalette.rule)
                                    .frame(height: 1)
                            }
                        }
                    }
                }

                FeatureCard(title: "Placement rule", eyebrow: "Safety posture") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The system can suggest the room, but the user still confirms the step into it.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                            .fixedSize(horizontal: false, vertical: true)

                        TokenRow(items: [
                            "1 primary circle",
                            "2 secondary circles",
                            "Explain why",
                            "Accept, swap, or defer"
                        ])
                    }
                }

                ViewThatFits(in: .vertical) {
                    HStack(spacing: 12) {
                        Button {
                            appState.acceptPlacement()
                        } label: {
                            PrimaryActionButton(title: placementActionTitle(placement.actions.primaryAction), systemImage: placement.userState == .accepted ? "checkmark" : "checkmark.circle")
                        }
                        .buttonStyle(.plain)

                        Button {
                            appState.swapPrimaryCircle()
                        } label: {
                            SecondaryActionButton(title: placement.actions.swapAction, systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 12) {
                        Button {
                            appState.acceptPlacement()
                        } label: {
                            PrimaryActionButton(title: placementActionTitle(placement.actions.primaryAction), systemImage: placement.userState == .accepted ? "checkmark" : "checkmark.circle")
                        }
                        .buttonStyle(.plain)

                        Button {
                            appState.swapPrimaryCircle()
                        } label: {
                            SecondaryActionButton(title: placement.actions.swapAction, systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    appState.deferPlacement()
                } label: {
                    SecondaryActionButton(title: placement.actions.deferAction, systemImage: "pause.circle")
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Circles")
        }
    }

    private func stateLabel(_ state: PlacementState) -> String {
        switch state {
        case .proposed:
            return "Proposed"
        case .accepted:
            return "Accepted"
        case .swapped:
            return "Swapped"
        case .deferred:
            return "Deferred"
        }
    }

    private func placementActionTitle(_ baseTitle: String) -> String {
        switch appState.currentPlacement.userState {
        case .accepted:
            return "Room accepted"
        case .swapped:
            return "Accept this room"
        case .proposed, .deferred:
            return baseTitle
        }
    }
}

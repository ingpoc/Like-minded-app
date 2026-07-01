import SwiftUI

struct CirclesPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Circles",
                subtitle: "Choose your room."
            ) {
                if let placement = appState.slice?.placement {
                    FeatureCard(title: placement.primaryCircle.name, eyebrow: stateLabel(placement.userState)) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(placement.primaryCircle.shortPromise)
                                .font(PrototypeTypography.sectionTitle)
                                .foregroundStyle(PrototypePalette.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(placement.primaryCircle.roomEnergy)
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.subink)
                                .fixedSize(horizontal: false, vertical: true)

                            FlexibleTagLayout(items: placement.primaryCircle.themes)

                            ForEach(placement.fitReasons, id: \.self) { reason in
                                Label(reason, systemImage: "checkmark.seal")
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(PrototypePalette.subink)
                            }
                        }
                    }

                    FeatureCard(title: "Actions", eyebrow: stateLabel(placement.userState)) {
                        VStack(spacing: 12) {
                            Button {
                                appState.acceptPlacement()
                            } label: {
                                PrimaryActionButton(
                                    title: placement.userState == .accepted ? "Room accepted" : placement.actions.primaryAction,
                                    systemImage: placement.userState == .accepted ? "checkmark" : "checkmark.circle"
                                )
                            }
                            .buttonStyle(.plain)

                            Button {
                                appState.swapPrimaryCircle()
                            } label: {
                                SecondaryActionButton(title: placement.actions.swapAction, systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.plain)

                            Button {
                                appState.deferPlacement()
                            } label: {
                                SecondaryActionButton(title: placement.actions.deferAction, systemImage: "pause.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !placement.secondaryCircles.isEmpty {
                        FeatureCard(title: "Alternate rooms", eyebrow: "If needed") {
                            VStack(spacing: 10) {
                                ForEach(placement.secondaryCircles.prefix(3)) { circle in
                                    alternateCircleRow(circle)
                                }
                            }
                        }
                    }
                } else {
                    FeatureCard(title: "No circle yet", eyebrow: "Talk first") {
                        Text("Start in Talk.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
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

    private func alternateCircleRow(_ circle: PlacementCircle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(circle.name)
                .font(PrototypeTypography.bodyStrong)
                .foregroundStyle(PrototypePalette.ink)

            Text(circle.roomEnergy)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }
}

struct CommunitiesPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Communities",
                subtitle: "Interests, not placement."
            ) {
                FeatureCard(title: "Community catalog", eyebrow: "Preview") {
                    VStack(spacing: 10) {
                        ForEach(PrototypeData.communities) { community in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(community.name)
                                        .font(PrototypeTypography.bodyStrong)
                                        .foregroundStyle(PrototypePalette.ink)
                                    Spacer()
                                    Text(community.fitLabel)
                                        .font(PrototypeTypography.caption)
                                        .foregroundStyle(PrototypePalette.accent)
                                }

                                Text(community.summary)
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(PrototypePalette.subink)
                                    .fixedSize(horizontal: false, vertical: true)

                                FlexibleTagLayout(items: community.themes)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PrototypePalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(PrototypePalette.rule, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Communities")
        }
    }

}

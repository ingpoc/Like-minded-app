import SwiftUI

struct ConnectionsPrototypeView: View {
    @State private var hasEntered = false
    @State private var mode: ConnectionMode = .circles
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Connections",
                subtitle: "Circle-first connection with fit, strength, and consent visible."
            ) {
                Picker("Connection mode", selection: $mode) {
                    ForEach(ConnectionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .likemindedEntrance(order: 0, isActive: hasEntered, y: 10, scale: 0.98)

                if mode == .circles {
                    circleMode
                        .likemindedEntrance(order: 1, isActive: hasEntered, y: 14, scale: 0.98)
                } else {
                    peopleMode
                        .likemindedEntrance(order: 1, isActive: hasEntered, y: 14, scale: 0.98)
                }

                inviteAction
                    .likemindedEntrance(order: 2, isActive: hasEntered, y: 14, scale: 0.98)
            }
            .navigationTitle("Connections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Invite")
                }
            }
        }
        .task {
            guard !hasEntered else { return }
            hasEntered = true
        }
    }

    private var circleMode: some View {
        let placement = appState.currentPlacement

        return FeatureCard(title: placement.primaryCircle.name, eyebrow: "Active circle") {
            VStack(alignment: .leading, spacing: 14) {
                CircleSelector(placement: placement)

                Text(placement.primaryCircle.roomEnergy)
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    MiniMetricCard(icon: "person.2.fill", value: "\(placement.primaryCircle.membersOnline)", label: "Members")
                    MiniMetricCard(icon: "checkmark.seal.fill", value: placement.primaryCircle.fitLabel, label: "Fit")
                }

                TokenRow(items: Array(placement.primaryCircle.themes.prefix(3)))
            }
        }
    }

    private var peopleMode: some View {
        FeatureCard(title: "People in fit order", eyebrow: appState.canOpenConnection ? "Open" : "Preview") {
            VStack(spacing: 12) {
                ForEach(appState.visibleMatches) { match in
                    PersonFitCard(match: match, isOpen: appState.canOpenConnection) {
                        appState.confirmConnection()
                    }
                }

                if appState.visibleMatches.isEmpty {
                    Text(appState.connectionsGateMessage)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.subink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var inviteAction: some View {
        Button {
            appState.acceptPlacement()
            mode = .people
        } label: {
            PrimaryActionButton(
                title: appState.canOpenConnection ? "Invite with context" : "Confirm room to invite",
                systemImage: appState.canOpenConnection ? "paperplane.fill" : "checkmark.circle.fill"
            )
        }
        .buttonStyle(.plain)
    }
}

private enum ConnectionMode: String, CaseIterable, Identifiable {
    case circles
    case people

    var id: String { rawValue }

    var title: String {
        switch self {
        case .circles:
            return "Circles"
        case .people:
            return "People"
        }
    }
}

private struct CircleSelector: View {
    let placement: CirclePlacement

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CircleSelectorChip(title: placement.primaryCircle.name, isSelected: true)

                ForEach(placement.secondaryCircles) { circle in
                    CircleSelectorChip(title: circle.name, isSelected: false)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct CircleSelectorChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(PrototypeTypography.metadata)
            .foregroundStyle(isSelected ? .white : PrototypePalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? PrototypePalette.accent : PrototypePalette.surface)
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(PrototypePalette.rule, lineWidth: isSelected ? 0 : 1)
            )
    }
}

private struct PersonFitCard: View {
    let match: MatchRecommendation
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(PrototypePalette.accentSoft)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(match.name.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PrototypePalette.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(match.name)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)

                    Text(match.headline)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(match.compatibility)%")
                        .font(PrototypeTypography.metric)
                        .foregroundStyle(PrototypePalette.accent)

                    Text(strengthLabel)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)
                }
            }

            ProgressView(value: Double(match.compatibility), total: 100)
                .tint(PrototypePalette.accent)

            HStack {
                Label(isOpen ? "Consent ready" : "Placement gated", systemImage: isOpen ? "checkmark.shield" : "lock")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(isOpen ? PrototypePalette.success : PrototypePalette.amber)

                Spacer(minLength: 8)

                Button(action: action) {
                    Text(isOpen ? "Invite" : "Preview")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.accent)
                }
                .buttonStyle(.plain)
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

    private var strengthLabel: String {
        match.compatibility >= 90 ? "Strong" : "Growing"
    }
}

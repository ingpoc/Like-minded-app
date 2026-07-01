import SwiftUI

struct TodayPrototypeView: View {
    @State private var hasEntered = false
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Today",
                subtitle: "Your next placement, evidence, and action."
            ) {
                if appState.isLoading && appState.slice == nil {
                    loadingCard
                        .likemindedEntrance(order: 0, isActive: hasEntered, y: 18, scale: 0.97)
                }

                let slice = appState.activeSlice

                placementHero(slice.placement, connection: slice.connectionPath)
                    .likemindedEntrance(order: 0, isActive: hasEntered, y: 18, scale: 0.97)

                nextActionRows(slice.placement)
                    .likemindedEntrance(order: 1, isActive: hasEntered, y: 14, scale: 0.98)

                circleOverview(slice.placement)
                    .likemindedEntrance(order: 2, isActive: hasEntered, y: 14, scale: 0.98)

                if let loadError = appState.loadError {
                    apiFallbackCard(loadError)
                        .likemindedEntrance(order: 3, isActive: hasEntered, y: 12, scale: 0.98)
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {} label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Menu")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Image(systemName: "bell.badge")
                    }
                    .accessibilityLabel("Placement updates")
                }
            }
        }
        .task {
            guard !hasEntered else { return }
            hasEntered = true
            await appState.loadSlice()
        }
    }

    private func placementHero(_ placement: CirclePlacement, connection: ConnectionPath) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 54, height: 54)

                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("NEXT PLACEMENT")
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(Color.white.opacity(0.72))

                    Text("\(connection.displayName) into \(placement.primaryCircle.name)")
                        .font(PrototypeTypography.hero)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.top, 12)
            }

            Text(placement.primaryCircle.placementReason)
                .font(PrototypeTypography.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                EvidenceChip(title: "Fit", value: placement.primaryCircle.fitLabel)
                EvidenceChip(title: "Trust", value: placement.primaryCircle.privacyLevel)
                EvidenceChip(title: "Confidence", value: placement.confidenceLabel)
            }

            Button {
                appState.acceptPlacement()
            } label: {
                Label("Confirm placement", systemImage: "checkmark.circle.fill")
                    .font(PrototypeTypography.button)
                    .foregroundStyle(PrototypePalette.accentDeep)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PrototypePalette.accentDeep)
        )
        .shadow(color: PrototypePalette.accentDeep.opacity(0.18), radius: 22, y: 14)
    }

    private func nextActionRows(_ placement: CirclePlacement) -> some View {
        VStack(spacing: 12) {
            PlacementActionRow(
                icon: "checkmark.circle",
                tint: PrototypePalette.success,
                title: placement.actions.primaryAction,
                detail: "Open the room with consent visible."
            ) {
                appState.acceptPlacement()
            }

            PlacementActionRow(
                icon: "arrow.triangle.2.circlepath",
                tint: PrototypePalette.teal,
                title: placement.actions.swapAction,
                detail: "Compare a second circle before deciding."
            ) {
                appState.swapPrimaryCircle()
            }

            PlacementActionRow(
                icon: "clock",
                tint: PrototypePalette.amber,
                title: placement.actions.deferAction,
                detail: "Pause placement without losing the read."
            ) {
                appState.deferPlacement()
            }
        }
    }

    private func circleOverview(_ placement: CirclePlacement) -> some View {
        FeatureCard(title: "Circle overview", eyebrow: "Rooms") {
            VStack(spacing: 12) {
                CircleSummaryCard(circle: placement.primaryCircle, isPrimary: true)

                ForEach(placement.secondaryCircles.prefix(2)) { circle in
                    CircleSummaryCard(circle: circle, isPrimary: false)
                }
            }
        }
    }

    private var loadingCard: some View {
        FeatureCard(title: "Reading your reflection", eyebrow: "Placing") {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(PrototypePalette.accent)

                Text("Preparing circle fit, trust signals, and the next action.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
            }
        }
    }

    private func apiFallbackCard(_ message: String) -> some View {
        FeatureCard(title: "Prototype source", eyebrow: appState.sourceLabel) {
            Text(message)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EvidenceChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(Color.white.opacity(0.58))

            Text(value)
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PlacementActionRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    let action: () -> Void
    @State private var feedbackTrigger = 0

    var body: some View {
        Button {
            action()
            feedbackTrigger += 1
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)

                    Text(detail)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrototypePalette.muted)
            }
            .padding(14)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PrototypePalette.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: feedbackTrigger)
    }
}

private struct CircleSummaryCard: View {
    let circle: PlacementCircle
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarStack(count: min(circle.membersOnline, 3))

                VStack(alignment: .leading, spacing: 4) {
                    Text(circle.name)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)

                    Text("\(circle.membersOnline) members nearby")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }

                Spacer(minLength: 8)

                Text(isPrimary ? "Primary" : circle.fitLabel)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(isPrimary ? .white : PrototypePalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isPrimary ? PrototypePalette.accent : PrototypePalette.accentSoft)
                    .clipShape(Capsule(style: .continuous))
            }

            Text(circle.shortPromise)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
                .fixedSize(horizontal: false, vertical: true)

            TokenRow(items: Array(circle.themes.prefix(3)))
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

private struct AvatarStack: View {
    let count: Int

    var body: some View {
        HStack(spacing: -8) {
            ForEach(0..<max(count, 1), id: \.self) { index in
                Circle()
                    .fill(avatarColor(index))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(index + 1))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .overlay(Circle().stroke(PrototypePalette.surface, lineWidth: 2))
            }
        }
        .frame(width: 56, alignment: .leading)
    }

    private func avatarColor(_ index: Int) -> Color {
        [PrototypePalette.accent, PrototypePalette.teal, PrototypePalette.coral][index % 3]
    }
}

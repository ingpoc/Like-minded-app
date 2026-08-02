import SwiftUI

/// Circles tab — placement-first layout (`circlesRoom`).
/// Unplaced: editorial left + interview CTA. Placed: primary left, AI secondary suggestions right.
struct MacCirclesRoomView: View {
    @ObservedObject var appState: MacAppState
    var navigate: ((MacPrototypeScreen) -> Void)?

    @State private var circleConcernStatus: String?

    private let promiseRows: [(icon: String, title: String, detail: String)] = [
        ("waveform", "Private signals", "Only you shape what we understand."),
        ("shield", "By design", "Circles are small, intentional, and moderated."),
        ("person.3", "Right time, right circle", "We'll place you when the fit is right."),
    ]

    private var placement: CirclePlacement? {
        appState.placement?.placement
    }

    private var isPlaced: Bool {
        appState.isSignedIn && placement != nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CirclesPlacementFieldView(background: MacPalette.background)
                .opacity(isPlaced ? 0.72 : 0.85)
                .ignoresSafeArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    if isPlaced, let placement {
                        placedLayout(placement)
                    } else {
                        unplacedLayout
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.top, 54)
                .padding(.bottom, 116)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: appState.isSignedIn) {
            guard appState.isSignedIn else { return }
            await appState.loadCurrentPlacement()
            await appState.fetchCircles()
        }
    }

    // MARK: - Unplaced

    private var unplacedLayout: some View {
        HStack(alignment: .top, spacing: 36) {
            editorialColumn
                .frame(width: 340, alignment: .leading)
            unplacedRightColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editorialColumn: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Likeminded")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(MacPalette.ink)

            Text("Your circle.")
                .font(MacType.title)
                .foregroundStyle(MacPalette.ink)

            Text("We place you with people who match your pace, energy, and what matters now.")
                .font(MacType.body)
                .foregroundStyle(MacPalette.muted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(promiseRows, id: \.title) { row in
                    promiseRow(row)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
    }

    private var unplacedRightColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            MacPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(MacPalette.accent)
                    Text("Complete your AI profile")
                        .font(MacType.section)
                        .foregroundStyle(MacPalette.ink)
                    Text("A short voice interview helps us place you in the right personality-matched circle.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Start interview") {
                        navigate?(.profileOnboarding)
                    }
                    .font(MacType.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.black, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start AI profile interview")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            circleTypesSection(muted: true)
        }
    }

    // MARK: - Placed

    private func placedLayout(_ placement: CirclePlacement) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Your circle.")
                .font(MacType.title)
                .foregroundStyle(MacPalette.ink)

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    primaryCircleCard(placement.primaryCircle, placement: placement)
                    concernStrip
                }
                .frame(width: 420, alignment: .leading)

                VStack(alignment: .leading, spacing: 18) {
                    secondarySuggestionsSection(placement)
                    circleTypesSection(muted: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func primaryCircleCard(_ circle: PlacementCircle, placement: CirclePlacement) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PRIMARY CIRCLE")
                .font(MacType.eyebrow)
                .foregroundStyle(MacPalette.muted)

            HStack(alignment: .center, spacing: 20) {
                DoodleCircleMark(circleId: circle.id, size: 132)

                VStack(alignment: .leading, spacing: 10) {
                    Text(circle.name)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(MacPalette.ink)
                    Label("\(memberCount(circle)) members", systemImage: "person.2")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                    Text(circle.placementReason)
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)

                    tagPills(for: circle)

                    Button("Enter \(circle.name)") {
                        openCircleDetail(circle)
                    }
                    .font(MacType.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.black, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Enter \(circle.name)")
                    .accessibilityIdentifier("hero-circle-macos")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(22)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MacPalette.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 18, y: 8)
        }
    }

    private var concernStrip: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "hand.raised.slash")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MacPalette.ink)
            VStack(alignment: .leading, spacing: 2) {
                Text("This doesn't feel like my circle")
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                Text(circleConcernStatus ?? "Ask for a placement refresh when the circle feels off.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .lineLimit(2)
                    .accessibilityLabel(circleConcernStatus ?? "Ask for a placement refresh when the circle feels off.")
            }
            Spacer(minLength: 8)
            Button("Request refresh") {
                circleConcernStatus = "Requesting a placement refresh..."
                Task {
                    // Persist customer-facing copy — never harness labels (they surface on Profile).
                    _ = await appState.reportCircleConcern(MacAppState.defaultPlacementConcernCopy)
                    circleConcernStatus = appState.loadError ?? "Placement refresh requested."
                }
            }
            .font(MacType.button)
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(MacPalette.accent, in: Capsule())
            .foregroundStyle(.white)
            .accessibilityLabel("Request circle placement refresh")
            .accessibilityIdentifier("concern-btn")
        }
        .padding(16)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MacPalette.line, lineWidth: 1)
        )
    }

    private func secondarySuggestionsSection(_ placement: CirclePlacement) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested for your second circle")
                    .font(MacType.section)
                    .foregroundStyle(MacPalette.ink)
                Text("Preview fit only — opening a suggestion does not change your placement until you choose it.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let suggestions = placement.secondaryCircles
            if suggestions.isEmpty {
                Text("No secondary suggestions yet.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(suggestions) { circle in
                        secondarySuggestionCard(
                            circle,
                            isSelected: placement.selectedSecondaryCircleId == circle.id
                        )
                    }
                }
            }
        }
    }

    private func secondarySuggestionCard(_ circle: PlacementCircle, isSelected: Bool) -> some View {
        Button {
            openCircleDetail(circle)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                DoodleCircleMark(circleId: circle.id, size: 64)
                Text(circle.name)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(MacPalette.ink)
                    .lineLimit(2)
                Label("\(memberCount(circle)) members", systemImage: "person.2")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                Text(circle.shortPromise.isEmpty ? circle.placementReason : circle.shortPromise)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    if isSelected {
                        Label("Your second circle", systemImage: "checkmark.circle.fill")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.accent)
                    } else {
                        Text("See why we matched")
                            .font(MacType.small.weight(.semibold))
                            .foregroundStyle(MacPalette.accent)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(MacType.small.weight(.semibold))
                        .foregroundStyle(MacPalette.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? MacPalette.accent.opacity(0.55) : MacPalette.line, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(circle.name) circle")
        .accessibilityValue(isSelected ? "Your second circle" : "Suggested secondary circle")
        .accessibilityIdentifier("circle-card")
    }

    private func circleTypesSection(muted: Bool) -> some View {
        let primaryId = placement?.primaryCircle.id
        let suggestionIds = Set((placement?.secondaryCircles ?? []).map(\.id))
        let types = appState.circles.filter { circle in
            circle.id != primaryId && !suggestionIds.contains(circle.id)
        }

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Circle types")
                    .font(MacType.section)
                    .foregroundStyle(muted ? MacPalette.muted : MacPalette.ink)
                Text("Personality-matched archetypes. Placement only — not browsing.")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }

            if types.isEmpty {
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { index in
                        placeholderTypeCard(index: index, muted: muted)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(types) { circle in
                        circleTypeCard(circle, muted: muted)
                    }
                }
            }
        }
        .opacity(muted ? 0.72 : 1)
    }

    private func circleTypeCard(_ circle: PlacementCircle, muted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DoodleCircleMark(circleId: circle.id, size: 52)
            Text(circle.name)
                .font(MacType.button)
                .foregroundStyle(MacPalette.ink)
                .lineLimit(2)
            Text("\(memberCount(circle)) members")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
            Text("Personality fit")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(MacPalette.surface.opacity(muted ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MacPalette.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(circle.name), personality archetype")
    }

    private func placeholderTypeCard(index: Int, muted: Bool) -> some View {
        let ids = ["reflective-builders", "longform-thinkers", "gentle-romantics"]
        return VStack(alignment: .leading, spacing: 10) {
            DoodleCircleMark(circleId: ids[index % ids.count], size: 52)
                .opacity(muted ? 0.65 : 1)
            Text(["Open Hearts", "Thinkers", "Visionaries"][index % 3])
                .font(MacType.button)
                .foregroundStyle(MacPalette.muted)
            Text("Personality fit")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(MacPalette.surface.opacity(muted ? 0.5 : 0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MacPalette.line, lineWidth: 1)
        )
    }

    // MARK: - Shared pieces

    private func promiseRow(_ row: (icon: String, title: String, detail: String)) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: row.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MacPalette.ink)
                .frame(width: 36, height: 36)
                .background(MacPalette.surface.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(MacPalette.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                Text(row.detail)
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title). \(row.detail)")
    }

    private func tagPills(for circle: PlacementCircle) -> some View {
        let tags = Array(circle.themes.prefix(3))
        let overflow = max(0, circle.themes.count - 3)
        return FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(MacType.small.weight(.medium))
                    .foregroundStyle(MacPalette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MacPalette.background.opacity(0.8), in: Capsule())
                    .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(MacType.small.weight(.medium))
                    .foregroundStyle(MacPalette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(MacPalette.background.opacity(0.8), in: Capsule())
                    .overlay(Capsule().stroke(MacPalette.line, lineWidth: 1))
            }
        }
    }

    private func memberCount(_ circle: PlacementCircle) -> Int {
        // Circles are micro-rooms (archetype 4–6; concept mockups 12–18). Historical
        // store bloat must not surface as “1,676 members” next to “small circle” copy.
        let raw = max(circle.membersOnline, 0)
        if raw <= 0 { return 12 }
        return min(raw, 18)
    }

    private func openCircleDetail(_ circle: PlacementCircle) {
        appState.circleDetail = circle
        navigate?(.circleDetail)
        Task { await appState.loadCircleDetail(id: circle.id) }
    }
}

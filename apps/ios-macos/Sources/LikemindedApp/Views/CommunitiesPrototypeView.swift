import SwiftUI

struct CirclesPrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState

    private var placement: CirclePlacement { appState.currentPlacement }

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Circles", subtitle: "Your room.") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your circle".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(.white.opacity(0.86))

                    NavigationLink {
                        CircleDetailView(circle: placement.primaryCircle, reasons: placement.fitReasons)
                    } label: {
                        CircleHeroCard(circle: placement.primaryCircle)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    appState.concernFlag = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.slash")
                        Text("This doesn't feel like my circle")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.ink)
                    .padding(16)
                    .background(PrototypePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Browse circles".uppercased())
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)
                        Spacer()
                        Text("View all")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.subink)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(browseCircles.enumerated()), id: \.element.id) { index, circle in
                                NavigationLink {
                                    CircleDetailView(circle: circle, reasons: placement.fitReasons)
                                } label: {
                                    BrowseCircleCard(circle: circle, tone: index)
                                }
                                .buttonStyle(.plain)
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                        .opacity(phase.isIdentity ? 1 : 0.72)
                                }
                            }
                        }
                    }
                    .contentMargins(.horizontal, 2, for: .scrollContent)
                }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "plus")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                    .frame(width: 36, height: 36)
                    .background(PrototypePalette.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PrototypePalette.rule, lineWidth: 1))
                    .padding(.top, 42)
                    .padding(.trailing, 22)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var browseCircles: [PlacementCircle] {
        [
            PlacementCircle(
                id: "thinkers",
                name: "The Thinkers' Room",
                emotionalPace: "Calm",
                interactionIntent: "Analytical companionship",
                socialFormat: "Small weekly room",
                riskLevel: "Low",
                privacyLevel: "Starter circle",
                shortPromise: "Analytical · Calm · Curious",
                roomEnergy: "Quiet builders who prefer substance over speed.",
                easiestFirstAction: "Join the Sunday check-in.",
                fitLabel: "Strong fit",
                placementReason: "Your reflective pace fits the room.",
                membersOnline: 18,
                themes: ["Analytical", "Calm", "Curious"]
            ),
            PlacementCircle(
                id: "open-hearts",
                name: "Open Hearts",
                emotionalPace: "Warm",
                interactionIntent: "Supportive connection",
                socialFormat: "Guided sharing",
                riskLevel: "Medium",
                privacyLevel: "Opt-in",
                shortPromise: "Warm · Expressive · Supportive",
                roomEnergy: "People who say the real thing kindly.",
                easiestFirstAction: "React to the welcome prompt.",
                fitLabel: "Good fit",
                placementReason: "Your warmth is present but paced.",
                membersOnline: 22,
                themes: ["Warm", "Expressive", "Supportive"]
            ),
            PlacementCircle(
                id: "craft-room",
                name: "The Craft Room",
                emotionalPace: "Focused",
                interactionIntent: "Maker friendship",
                socialFormat: "Project circle",
                riskLevel: "Low",
                privacyLevel: "Starter circle",
                shortPromise: "Focused · Gentle · Useful",
                roomEnergy: "Builders who trade notes and momentum.",
                easiestFirstAction: "Share what you are making.",
                fitLabel: "High fit",
                placementReason: "Your builder identity is strong.",
                membersOnline: 16,
                themes: ["Makers", "Depth", "Ritual"]
            )
        ]
    }
}

private struct CircleHeroCard: View {
    let circle: PlacementCircle

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Label("High fit", systemImage: "sparkle")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.38), lineWidth: 1))
            }

            Text(circle.name)
                .font(PrototypeTypography.hero)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Thoughtful · Deep · Intentional")
                .font(PrototypeTypography.body)
                .foregroundStyle(.white.opacity(0.92))

            Text("We value honesty, depth and steady conversations.")
                .font(PrototypeTypography.caption)
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label("Sunday 7pm", systemImage: "calendar")
                Spacer()
                Label("\(circle.membersOnline) members", systemImage: "person.2")
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.88))
                    .foregroundStyle(PrototypePalette.ink)
                    .clipShape(Circle())
            }
            .font(PrototypeTypography.metadata)
            .foregroundStyle(.white)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypePalette.roomGradient(0))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(WaveLines().stroke(Color.white.opacity(0.16), lineWidth: 1).padding(8))
    }
}

private struct BrowseCircleCard: View {
    let circle: PlacementCircle
    let tone: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer()
            Text(circle.name)
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(circle.shortPromise)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
            Text("\(circle.membersOnline) members")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white.opacity(0.90))
                .padding(.top, 8)
        }
        .padding(14)
        .frame(width: 144, height: 190, alignment: .leading)
        .background(PrototypePalette.roomGradient(tone))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CircleDetailView: View {
    let circle: PlacementCircle
    let reasons: [String]

    var body: some View {
        ScreenContainer(title: "Circle", subtitle: circle.name) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Thoughtful · Deep · Intentional")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(.white.opacity(0.92))

                Text("We build trust slowly, listen deeply, and show up for each other.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(.white.opacity(0.84))

                FlexibleTagLayout(items: circle.themes)

                HStack {
                    Label("Next meetup\nSunday, Jul 6 · 7:00 PM", systemImage: "calendar")
                    Spacer()
                    Text("3d 4h left")
                        .font(PrototypeTypography.metadata.monospacedDigit())
                        .foregroundStyle(PrototypePalette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(PrototypePalette.accentSoft)
                        .clipShape(Capsule(style: .continuous))
                }
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white)
            }
            .padding(22)
            .background(PrototypePalette.roomGradient(0))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            FeatureCard(title: "Why you fit", eyebrow: "Signal match") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                        Label(reason, systemImage: "checkmark.circle.fill")
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.ink)
                    }
                }
            }

            FeatureCard(title: "Room rhythm", eyebrow: "Format") {
                VStack(spacing: 0) {
                    DetailRow(icon: "person.2", title: "\(circle.membersOnline) members")
                    DetailRow(icon: "bubble.left.and.bubble.right", title: "Weekly structured check-ins")
                }
            }

            SecondaryActionButton(title: "Leave circle", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .navigationTitle(circle.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CommunitiesPrototypeView: View {
    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Communities", subtitle: "What you're into.") {
                HStack(spacing: 10) {
                    Label("Search communities", systemImage: "magnifyingglass")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(Color.black.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    Image(systemName: "slider.horizontal.3")
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(PrototypePalette.ink)
                        .frame(width: 46, height: 46)
                        .background(PrototypePalette.surface)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your communities".uppercased())
                            .font(PrototypeTypography.eyebrow)
                            .foregroundStyle(PrototypePalette.accent)
                        Spacer()
                        Text("View all")
                            .font(PrototypeTypography.metadata)
                            .foregroundStyle(PrototypePalette.accent)
                    }
                    CommunityCard(name: "Jazz & Music", summary: "18 members", tags: [], action: "Joined", tone: 3, compact: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse communities".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(PrototypePalette.accent)

                    CommunityCard(name: "AI Builders", summary: "People building useful AI products and tools.", tags: ["AI", "Products", "UX"], action: "Join", tone: 1)
                    CommunityCard(name: "Writers' Corner", summary: "For storytellers and creative writers.", tags: ["Writing", "Stories", "Books"], action: "Join", tone: 2)
                    CommunityCard(name: "Slow Living", summary: "Mindful living. Less rush, more meaning.", tags: ["Wellness", "Mindfulness", "Lifestyle"], action: "Join", tone: 0)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct CommunityCard: View {
    let name: String
    let summary: String
    let tags: [String]
    let action: String
    let tone: Int
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(name)
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(.white)
                    Text(summary)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(.white.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(action)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(action == "Joined" ? PrototypePalette.accent : PrototypePalette.ink)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(action == "Joined" ? PrototypePalette.accentSoft : Color.white.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule(style: .continuous))
                            .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.26), lineWidth: 1))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: compact ? 92 : 146, alignment: .leading)
        .background(PrototypePalette.roomGradient(tone))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 26)
            Text(title)
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PrototypePalette.rule)
                .frame(height: 1)
        }
    }
}

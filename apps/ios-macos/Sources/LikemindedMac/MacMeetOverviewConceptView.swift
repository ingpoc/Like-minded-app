import SwiftUI

/// Meet tab plate — thewayofcode-inspired venue convergence map.
/// Reference: `mockups/macos/concepts/mockup-meet-overview-convergence.png`
/// Meet tab production plate (`--mac-screen meetOverview`). Same shell + `MacBottomNav`.
struct MacMeetOverviewConceptView: View {
    @ObservedObject var appState: MacAppState
    var navigate: ((MacPrototypeScreen) -> Void)?

    @State private var heroRSVP: HeroMeetRSVP = .yes
    @State private var weeklySlots: [WeeklyAvailabilitySlot] = WeeklyAvailabilitySlot.conceptDefaults
    @State private var selectedRecapMeetingId: String?

    private enum HeroMeetRSVP: String, CaseIterable, Identifiable {
        case yes, maybe, no

        var id: String { rawValue }

        var label: String {
            switch self {
            case .yes: "RSVP Yes"
            case .maybe: "Maybe"
            case .no: "Can't Make It"
            }
        }

        var icon: String {
            switch self {
            case .yes: "checkmark"
            case .maybe: "minus"
            case .no: "xmark"
            }
        }
    }

    private struct WeeklyAvailabilitySlot: Identifiable {
        let id: String
        let day: String
        var detail: String
        var isOn: Bool

        static let conceptDefaults: [WeeklyAvailabilitySlot] = [
            WeeklyAvailabilitySlot(id: "mon", day: "Mon", detail: "6:00 – 9:00 PM", isOn: true),
            WeeklyAvailabilitySlot(id: "tue", day: "Tue", detail: "6:00 – 9:00 PM", isOn: true),
            WeeklyAvailabilitySlot(id: "wed", day: "Wed", detail: "Unavailable", isOn: false),
            WeeklyAvailabilitySlot(id: "thu", day: "Thu", detail: "6:00 – 9:00 PM", isOn: true),
            WeeklyAvailabilitySlot(id: "fri", day: "Fri", detail: "Flexible", isOn: false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            conceptHeader
            if appState.isSignedIn {
                nextMeetupCard
                HStack(alignment: .top, spacing: 20) {
                    pastMeetupsPanel
                        .frame(maxWidth: .infinity)
                    weeklyAvailabilityPanel
                        .frame(width: 340)
                }
            } else {
                MacPanel {
                    Text("Sign in to preview the Meet concept screen.")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }
            }
        }
        .task {
            if appState.isSignedIn {
                await appState.fetchMeetings()
            }
        }
    }

    // MARK: - Header

    private var conceptHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Likeminded")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(MacPalette.accent)
            Text("When you meet.")
                .font(MacType.title)
                .foregroundStyle(MacPalette.ink)
            Text("AI helps you meet the right people in the right rooms.")
                .font(MacType.body)
                .foregroundStyle(MacPalette.muted)
                .frame(maxWidth: 520, alignment: .leading)
        }
    }

    // MARK: - Next meetup hero

    @ViewBuilder
    private var nextMeetupCard: some View {
        let meeting = appState.upcomingMeetings.first
        let venue = conceptVenue(for: meeting)
        let venueLines = conceptVenueLines(for: meeting)
        let going = max(meeting?.groupSize ?? 9, 9)
        let spotsLeft = max(1, 15 - going)

        // Concept plate: ONE card. Field = cover art from concept mockup
        // (right ~⅔). Live pin/label overlay; copy on the left.
        ZStack(alignment: .topLeading) {
            MacMeetVenueConvergenceField()

            VStack(alignment: .leading, spacing: 16) {
                Text("Next meetup")
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(MacPalette.muted)

                Text(meeting?.title ?? "Designing for Belonging")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(MacPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.map { conceptScheduleLine($0.scheduledAt) } ?? "Thursday, May 22 · 6:30 – 8:30 PM")
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.ink)
                    Text(venue)
                        .font(MacType.body)
                        .foregroundStyle(MacPalette.muted)
                }

                HStack(spacing: 8) {
                    attendeeStack(count: min(4, going))
                    Text("\(going) going · \(spotsLeft) spots left")
                        .font(MacType.small)
                        .foregroundStyle(MacPalette.muted)
                }

                HStack(spacing: 10) {
                    ForEach(HeroMeetRSVP.allCases) { option in
                        heroRSVPButton(option)
                    }
                }
            }
            .padding(28)
            .frame(width: 400, alignment: .topLeading)

            // Pin sits on the generated field's convergence sink.
            GeometryReader { geo in
                let focus = MacMeetVenueConvergenceField.pinPosition(in: geo.size)
                VStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(MacPalette.ink)
                    VStack(spacing: 2) {
                        Text(venueLines.title)
                            .font(MacType.small.weight(.semibold))
                        Text(venueLines.subtitle)
                            .font(MacType.small)
                    }
                    .foregroundStyle(MacPalette.ink)
                    .multilineTextAlignment(.center)
                }
                .position(x: focus.x, y: focus.y + 18)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(venueLines.title), \(venueLines.subtitle)")
            }
        }
        .frame(minHeight: 300)
        .frame(maxWidth: .infinity)
        .background(MacPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MacPalette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func heroRSVPButton(_ option: HeroMeetRSVP) -> some View {
        let selected = heroRSVP == option
        return Button {
            heroRSVP = option
        } label: {
            Label(option.label, systemImage: option.icon)
                .font(MacType.small.weight(.semibold))
                .foregroundStyle(selected && option == .yes ? .white : MacPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    selected && option == .yes ? Color.black : MacPalette.surface.opacity(0.92),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(MacPalette.line, lineWidth: selected && option == .yes ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func attendeeStack(count: Int) -> some View {
        HStack(spacing: -8) {
            ForEach(0..<count, id: \.self) { index in
                MacAvatar(initials: ["P", "G", "M", "A"][index % 4], size: 28)
                    .overlay(Circle().stroke(MacPalette.surface, lineWidth: 2))
            }
        }
    }

    // MARK: - Past meetups

    private var pastMeetupsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Past meetups")
                    .font(MacType.section)
                    .foregroundStyle(MacPalette.ink)
                Spacer()
                Button("View all") {}
                    .font(MacType.small.weight(.semibold))
                    .foregroundStyle(MacPalette.accent)
                    .buttonStyle(.plain)
            }

            if appState.pastMeetings.isEmpty {
                Text("No past meetups yet.")
                    .font(MacType.body)
                    .foregroundStyle(MacPalette.muted)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.pastMeetings.prefix(3)) { meeting in
                        Button {
                            selectedRecapMeetingId = meeting.id
                            navigate?(.meetRecap)
                        } label: {
                            pastMeetConceptRow(meeting)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private func pastMeetConceptRow(_ meeting: Meeting) -> some View {
        HStack(spacing: 14) {
            DoodleCover(
                assetName: DoodleArt.eventCover(eventType: meeting.kind),
                height: 52,
                cornerRadius: 10,
                scrim: false
            )
            .frame(width: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(MacType.button)
                    .foregroundStyle(MacPalette.ink)
                    .lineLimit(2)
                Text("\(LikemindedDate.short(meeting.scheduledAt)) · \(conceptVenueShort(for: meeting))")
                    .font(MacType.small)
                    .foregroundStyle(MacPalette.muted)
            }

            Spacer(minLength: 8)

            MacPill(text: "You went", isSelected: false)
            Image(systemName: "chevron.right")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
        }
        .padding(12)
        .background(MacPalette.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Weekly availability

    private var weeklyAvailabilityPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your availability")
                    .font(MacType.section)
                    .foregroundStyle(MacPalette.ink)
                Spacer()
                Button {} label: {
                    Label("Edit", systemImage: "calendar")
                        .font(MacType.small.weight(.semibold))
                        .foregroundStyle(MacPalette.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(weeklySlots.enumerated()), id: \.element.id) { index, slot in
                    if index > 0 {
                        Divider()
                    }
                    weeklyAvailabilityRow(slot)
                }
            }

            Text("We'll suggest meetups that fit your schedule.")
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
                .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(MacPalette.line, lineWidth: 1))
    }

    private func weeklyAvailabilityRow(_ slot: WeeklyAvailabilitySlot) -> some View {
        let binding = Binding<Bool>(
            get: { weeklySlots.first(where: { $0.id == slot.id })?.isOn ?? slot.isOn },
            set: { newValue in
                guard let index = weeklySlots.firstIndex(where: { $0.id == slot.id }) else { return }
                weeklySlots[index].isOn = newValue
            }
        )

        return HStack {
            Text(slot.day)
                .font(MacType.button)
                .frame(width: 36, alignment: .leading)
            Text(slot.detail)
                .font(MacType.small)
                .foregroundStyle(MacPalette.muted)
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(MacPalette.accent)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Copy helpers

    private func conceptVenueLines(for meeting: Meeting?) -> (title: String, subtitle: String) {
        if let city = appState.profile?.basicInfo?.city, !city.isEmpty {
            return ("The Harbor Room", city)
        }
        return ("The Harbor Room", "San Francisco, CA")
    }

    private func conceptVenue(for meeting: Meeting?) -> String {
        if let city = appState.profile?.basicInfo?.city, !city.isEmpty {
            return "The Harbor Room, \(city)"
        }
        return "The Harbor Room, San Francisco, CA"
    }

    private func conceptVenueShort(for meeting: Meeting) -> String {
        let venues = ["The Pearl, San Francisco", "The Interval, San Francisco", "The Foundry, Berkeley"]
        let index = abs(meeting.id.hashValue) % venues.count
        return venues[index]
    }

    private func conceptScheduleLine(_ scheduledAt: String) -> String {
        guard let date = LikemindedDate.parse(scheduledAt) else {
            return LikemindedDate.meetHeader(scheduledAt)
        }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d · "
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let end = date.addingTimeInterval(2 * 60 * 60)
        return dayFormatter.string(from: date)
            + timeFormatter.string(from: date)
            + " – "
            + timeFormatter.string(from: end)
    }
}

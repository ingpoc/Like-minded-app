import SwiftUI

struct MeetPrototypeView: View {
    @State private var saturdayAvailable = true
    @State private var sundayAvailable = true

    var body: some View {
        NavigationStack {
            ScreenContainer(title: "Meet", subtitle: "When you meet.") {
                RSVPCard(
                    saturdayAvailable: $saturdayAvailable,
                    sundayAvailable: $sundayAvailable
                )

                VStack(alignment: .leading, spacing: 14) {
                    Text("Your Saturday meet".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(PrototypePalette.accent)

                    PreMeetTeaserCard(
                        title: "Jazz & Music Community",
                        detail: "5 people from 4 different circles.\nTwo extroverts, three introverts.\nHost: Marco.",
                        tone: 0
                    )

                    Text("Your Sunday meet".uppercased())
                        .font(PrototypeTypography.eyebrow)
                        .foregroundStyle(PrototypePalette.accent)
                        .padding(.top, 10)

                    PreMeetTeaserCard(
                        title: "Your Circle Meetup",
                        detail: "5 people. You all share slow-trust patterns and analytical communication.\nHost: Priya.",
                        tone: 2
                    )
                }

                UpcomingMeetCard()

                FeatureCard(title: "Past meets", eyebrow: "History") {
                    NavigationLink {
                        PostMeetSoulmateSelectionView()
                    } label: {
                        PastMeetRow()
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                    .frame(width: 42, height: 42)
                    .background(PrototypePalette.surface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 8)
                    .padding(.top, 42)
                    .padding(.trailing, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct RSVPCard: View {
    @Binding var saturdayAvailable: Bool
    @Binding var sundayAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Available this weekend?")
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(PrototypePalette.ink)

            RSVPRow(
                icon: "calendar",
                tint: PrototypePalette.success,
                title: "Saturday",
                subtitle: "Community meetup",
                isAvailable: $saturdayAvailable
            )

            Divider().overlay(PrototypePalette.rule)

            RSVPRow(
                icon: "calendar.badge.clock",
                tint: PrototypePalette.amber,
                title: "Sunday",
                subtitle: "Circle meetup",
                isAvailable: $sundayAvailable
            )

            Divider().overlay(PrototypePalette.rule)

            Label("RSVP closes Friday midnight.", systemImage: "timer")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.subink)
        }
        .padding(18)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }
}

private struct RSVPRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @Binding var isAvailable: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.ink)
                Text(subtitle)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.ink)
            }

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                availabilityButton("Available", selected: isAvailable) { isAvailable = true }
                availabilityButton("Not", selected: !isAvailable) { isAvailable = false }
            }
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(PrototypePalette.rule, lineWidth: 1)
            )
        }
        .sensoryFeedback(.success, trigger: isAvailable)
    }

    private func availabilityButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : PrototypePalette.ink)
                .frame(width: title == "Available" ? 76 : 44, height: 36)
                .background(selected ? PrototypePalette.actionGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom))
        }
        .buttonStyle(.plain)
    }
}

private struct PreMeetTeaserCard: View {
    let title: String
    let detail: String
    let tone: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(PrototypeTypography.cardTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(PrototypeTypography.caption)
                .foregroundStyle(.white.opacity(0.88))
                .lineSpacing(5)

            Label("Join in 2 days", systemImage: "calendar")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.13))
                .clipShape(Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.38), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(PrototypePalette.roomGradient(tone))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(WaveLines().stroke(Color.white.opacity(0.14), lineWidth: 1).padding(8))
    }
}

private struct UpcomingMeetCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming meetup".uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            VStack(alignment: .leading, spacing: 16) {
                Capsule()
                    .fill(PrototypePalette.accent)
                    .frame(width: 62, height: 5)

                Text("Saturday, Jul 5 · 7:00 PM")
                    .font(PrototypeTypography.cardTitle)
                    .foregroundStyle(PrototypePalette.ink)

                Text("2d 4h away")
                    .font(PrototypeTypography.bodyStrong.monospacedDigit())
                    .foregroundStyle(PrototypePalette.success)

                Label("Host: Marco", systemImage: "person")
                Label("10 participants (5M · 5F)", systemImage: "person.2")

                Text("Jazz & Music Community")
                    .font(PrototypeTypography.sectionTitle)
                    .foregroundStyle(PrototypePalette.ink)
                    .padding(.top, 4)

                NavigationLink {
                    GroupVideoCallPrototypeView()
                } label: {
                    PrimaryActionButton(title: "Join meetup", systemImage: "video.fill")
                }
                .buttonStyle(.plain)
            }
            .font(PrototypeTypography.metadata)
            .foregroundStyle(PrototypePalette.ink)
            .padding(18)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PrototypePalette.rule, lineWidth: 1)
            )
        }
    }
}

private struct PastMeetRow: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Jun 21 · Circle Meetup")
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                Text("The Quiet Builders circle")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(PrototypePalette.ink)
        }
        .padding(16)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PrototypePalette.rule, lineWidth: 1)
        )
    }
}

struct GroupVideoCallPrototypeView: View {
    private let participants = ["Arjun", "Meera", "Nisha", "Rohan", "Priya", "Vikram", "Ananya", "Karan", "Ira", "Marco"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Text("● Live")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule(style: .continuous))

                    Text("10 participants")
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "shield.lefthalf.filled")
                    Image(systemName: "ellipsis")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.top, 12)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(Array(participants.enumerated()), id: \.offset) { index, name in
                        VideoTile(name: name, index: index)
                    }
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 8)

                HStack(spacing: 42) {
                    CallControl(icon: "mic.fill", title: "Mute")
                    CallControl(icon: "phone.down.fill", title: "Leave", isDestructive: true)
                    CallControl(icon: "person.3.fill", title: "Participants")
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(.regularMaterial.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.bottom, 22)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct VideoTile: View {
    let name: String
    let index: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    PrototypePalette.roomGradient(index).colorsFallback.first ?? PrototypePalette.accent,
                    Color.black.opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(String(name.prefix(1)))
                .font(.system(size: 46, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if index == 0 {
                Text("Host")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(PrototypePalette.accent)
                    .clipShape(Capsule(style: .continuous))
                    .padding(8)
            }
        }
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CallControl: View {
    let icon: String
    let title: String
    var isDestructive = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(isDestructive ? Color.red : Color.white.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

struct PostMeetSoulmateSelectionView: View {
    @State private var selected = Set(["Marco", "Vikram"])
    private let names = ["Arjun", "Marco", "Rohan", "Vikram", "Karan"]

    var body: some View {
        ScreenContainer(title: "Soulmate", subtitle: "Did you connect with someone?") {
            VStack(spacing: 20) {
                Image(systemName: "heart")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(PrototypePalette.accent)
                    .frame(width: 82, height: 82)
                    .background(PrototypePalette.accentSoft)
                    .clipShape(Circle())
                    .shadow(color: PrototypePalette.accent.opacity(0.12), radius: 18, y: 10)

                Text("Tap the people you felt a real connection with.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)

                VStack(spacing: 0) {
                    ForEach(names, id: \.self) { name in
                        Button {
                            if selected.contains(name) {
                                selected.remove(name)
                            } else {
                                selected.insert(name)
                            }
                        } label: {
                            HStack {
                                Text(name)
                                    .font(PrototypeTypography.sectionTitle)
                                    .foregroundStyle(PrototypePalette.ink)
                                Spacer()
                                Image(systemName: selected.contains(name) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(selected.contains(name) ? PrototypePalette.accent : PrototypePalette.muted)
                            }
                            .padding(.vertical, 17)
                            .padding(.horizontal, 18)
                        }
                        .buttonStyle(.plain)

                        if name != names.last {
                            Divider().padding(.leading, 18)
                        }
                    }
                }
                .background(PrototypePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))

                PrimaryActionButton(title: "Submit", systemImage: "checkmark")

                Button("Skip") {}
                    .font(PrototypeTypography.button)
                    .foregroundStyle(PrototypePalette.accent)
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("After meet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WaveLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        for offset in stride(from: -80.0, through: 80.0, by: 10.0) {
            path.move(to: CGPoint(x: rect.maxX * 0.58, y: mid + offset))
            path.addCurve(
                to: CGPoint(x: rect.maxX + 30, y: mid + offset * 0.55),
                control1: CGPoint(x: rect.maxX * 0.72, y: mid + offset - 34),
                control2: CGPoint(x: rect.maxX * 0.88, y: mid + offset + 34)
            )
        }
        return path
    }
}

private extension LinearGradient {
    var colorsFallback: [Color] { [PrototypePalette.accent, PrototypePalette.accentDeep] }
}

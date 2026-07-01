import SwiftUI

struct SoulmatePrototypeView: View {
    private let matches = [
        ("Arjun", "Met at Jazz & Music meetup", "Jul 5", "A"),
        ("Meera", "Met at Jazz & Music meetup", "Jul 5", "M"),
        ("Rohan", "Met at The Quiet Builders circle", "Jun 21", "R"),
        ("Ananya", "Met at Writers' Corner meetup", "Jun 14", "A")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PrototypePalette.dusk.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        HStack {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Soulmate".uppercased())
                                    .font(PrototypeTypography.eyebrow)
                                    .foregroundStyle(.white.opacity(0.76))
                                Text("Who you connected with.")
                                    .font(PrototypeTypography.display)
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Image(systemName: "ellipsis.message")
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 28)

                        HeartBloom()
                            .frame(maxWidth: .infinity)
                            .frame(height: 145)

                        Text("Matches")
                            .font(PrototypeTypography.heroBody)
                            .foregroundStyle(.white.opacity(0.86))

                        VStack(spacing: 0) {
                            ForEach(Array(matches.enumerated()), id: \.offset) { index, match in
                                MatchRow(
                                    name: match.0,
                                    subtitle: match.1,
                                    date: match.2,
                                    initial: match.3,
                                    tone: index
                                )

                                if index != matches.count - 1 {
                                    Divider().overlay(Color.white.opacity(0.08))
                                }
                            }
                        }
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))

                        HStack(spacing: 14) {
                            Image(systemName: "heart")
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(PrototypePalette.rose.opacity(0.38))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Soulmate")
                                    .font(PrototypeTypography.bodyStrong)
                                    .foregroundStyle(.white)
                                Text("Opt in to find connections after meetups. Only visible when enabled.")
                                    .font(PrototypeTypography.caption)
                                    .foregroundStyle(.white.opacity(0.68))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white)
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Soulmate")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MatchRow: View {
    let name: String
    let subtitle: String
    let date: String
    let initial: String
    let tone: Int

    var body: some View {
        HStack(spacing: 14) {
            Text(initial)
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(PrototypePalette.roomGradient(tone))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(.white.opacity(0.62))
                Text(date)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer()

            Circle()
                .fill(PrototypePalette.rose)
                .frame(width: 9, height: 9)
                .shadow(color: PrototypePalette.rose, radius: 10)
        }
        .padding(16)
    }
}

private struct HeartBloom: View {
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: CGFloat(54 + index * 10), weight: .light))
                    .foregroundStyle(PrototypePalette.rose.opacity(0.10 + Double(index) * 0.05))
                    .blur(radius: CGFloat(index * 2))
                    .offset(x: CGFloat(index * 11 - 16), y: CGFloat(index * -7))
            }

            Image(systemName: "heart.fill")
                .font(.system(size: 82, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [PrototypePalette.rose, PrototypePalette.coral, PrototypePalette.gold],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: PrototypePalette.rose.opacity(0.55), radius: 28, y: 16)
        }
    }
}

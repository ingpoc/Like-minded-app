import SwiftUI

struct CircleCard: View {
    let circle: PlacementCircle
    let tone: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(circle.fitLabel)
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule(style: .continuous))
                Spacer()
            }

            Spacer()

            Text(circle.name)
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(circle.roomEnergy)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)

            HStack(spacing: 6) {
                ForEach(circle.themes.prefix(2), id: \.self) { theme in
                    Text(theme)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule(style: .continuous))
                }
            }

            Text("\(circle.membersOnline) members")
                .font(PrototypeTypography.metadata)
                .foregroundStyle(.white.opacity(0.90))
        }
        .padding(14)
        .containerRelativeFrame(.horizontal, count: 1, spacing: 10)
        .frame(height: 190, alignment: .leading)
        .background(PrototypePalette.roomGradient(tone))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

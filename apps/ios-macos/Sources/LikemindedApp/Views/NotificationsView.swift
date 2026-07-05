import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    @State private var filter: NotificationFilter = .all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if appState.notifications.isEmpty && appState.activityItems.isEmpty {
                        emptyState
                    } else {
                        filterPills

                        if !filteredNotifications.isEmpty {
                            section("Notifications", items: filteredNotifications)
                        }

                        if !appState.activityItems.isEmpty {
                            section("Activity", items: appState.activityItems)
                        }
                    }
                }
                .padding(20)
            }
            .background(PrototypePalette.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button("Mark all read") {
                            appState.markNotificationsRead()
                        }
                        .foregroundStyle(PrototypePalette.accent)
                        .accessibilityLabel("Mark all as read")
                        Button("Done") { dismiss() }
                            .foregroundStyle(PrototypePalette.accent)
                    }
                }
            }
            .task {
                await appState.fetchNotifications()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(PrototypePalette.subink.opacity(0.6))

            Text("All quiet.")
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(PrototypePalette.ink)

            Text("Meetups, joins, matches, and messages will show up here.")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var filterPills: some View {
        HStack(spacing: 10) {
            ForEach(NotificationFilter.allCases) { option in
                Button {
                    withAnimation(.interactive) { filter = option }
                } label: {
                    Text(option.title)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(filter == option ? .white : PrototypePalette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(filter == option ? PrototypePalette.actionGradient : LinearGradient(colors: [Color.black.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var filteredNotifications: [NotificationItem] {
        switch filter {
        case .all: return appState.notifications
        case .meets: return appState.notifications.filter { $0.kind == "meeting" }
        case .matches: return appState.notifications.filter { $0.kind == "soulmate" || $0.kind == "match" }
        case .messages: return appState.notifications.filter { $0.kind == "chat" || $0.kind == "message" }
        }
    }

    @ViewBuilder
    private func section(_ title: String, items: [NotificationItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    NotificationRow(item: item)
                }
            }
        }
    }
}

private enum NotificationFilter: String, CaseIterable, Identifiable {
    case all
    case meets
    case matches
    case messages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .meets: return "Meets"
        case .matches: return "Matches"
        case .messages: return "Messages"
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem

    private var icon: String {
        switch item.kind {
        case "meeting": return "calendar"
        case "community": return "rectangle.3.group"
        case "soulmate", "match": return "heart"
        case "chat", "message": return "bubble.right"
        default: return "sparkle"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(PrototypePalette.accent)
                .frame(width: 40, height: 40)
                .background(PrototypePalette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if let createdAt = item.createdAt {
                Text(LikemindedDate.short(createdAt))
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.subink)
            }
        }
        .padding(14)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }

}

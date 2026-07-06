import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @Environment(\.dismiss) private var dismiss
    @State private var notificationFilter = "All"
    @State private var activityFilter = "All"
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if appState.notifications.isEmpty && appState.activityItems.isEmpty {
                        emptyState
                    } else {
                        notificationsSection
                        activitySection
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
                            statusMessage = "All notifications marked read."
                        }
                        .foregroundStyle(PrototypePalette.accent)
                        .accessibilityLabel("Mark all notifications as read")
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

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTIFICATIONS")
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            filterPills(selection: $notificationFilter, options: ["All", "Unread", "Mentions"])

            if filteredNotifications.isEmpty {
                Text(appState.notificationError ?? "No notifications in this filter.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedNotificationSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(PrototypeTypography.metadata.weight(.semibold))
                                .foregroundStyle(PrototypePalette.subink)

                            VStack(spacing: 10) {
                                ForEach(section.items) { item in
                                    Button {
                                        openNotification(item)
                                    } label: {
                                        NotificationRow(
                                            item: item,
                                            isUnread: !appState.readNotificationIds.contains(item.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(item.title)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVITY")
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            filterPills(selection: $activityFilter, options: ["All", "Circles", "Communities"])

            if filteredActivityItems.isEmpty {
                Text("No activity in this filter.")
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This week")
                        .font(PrototypeTypography.metadata.weight(.semibold))
                        .foregroundStyle(PrototypePalette.subink)

                    VStack(spacing: 10) {
                        ForEach(filteredActivityItems) { item in
                            Button {
                                openActivityItem(item)
                            } label: {
                                ActivityRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.title)
                        }
                    }
                }
            }

            HStack(spacing: 14) {
                Image(systemName: "bell")
                    .font(.title2)
                    .foregroundStyle(PrototypePalette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stay in the loop")
                        .font(PrototypeTypography.bodyStrong)
                    Text("We'll keep you updated on what matters.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }
                Spacer()
                Button {
                    Task {
                        await appState.fetchNotifications()
                        statusMessage = "Notifications refreshed from backend."
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(PrototypeTypography.metadata.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .background(PrototypePalette.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule(style: .continuous))
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh notifications")
            }
            .padding(.top, 8)

            if let statusMessage {
                Text(statusMessage)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }
        }
    }

    private func filterPills(selection: Binding<String>, options: [String]) -> some View {
        HStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.interactive) { selection.wrappedValue = option }
                } label: {
                    Text(option)
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(selection.wrappedValue == option ? .white : PrototypePalette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(selection.wrappedValue == option ? PrototypePalette.actionGradient : LinearGradient(colors: [Color.black.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(option) filter")
            }
            Spacer()
        }
    }

    private struct NotificationSection {
        let title: String
        let items: [NotificationItem]
    }

    private var groupedNotificationSections: [NotificationSection] {
        let items = filteredNotifications
        let today = items.filter { notificationSectionLabel(for: $0.createdAt) == "Today" }
        let yesterday = items.filter { notificationSectionLabel(for: $0.createdAt) == "Yesterday" }
        let earlier = items.filter {
            let label = notificationSectionLabel(for: $0.createdAt)
            return label != "Today" && label != "Yesterday"
        }
        var sections: [NotificationSection] = []
        if !today.isEmpty { sections.append(NotificationSection(title: "Today", items: today)) }
        if !yesterday.isEmpty { sections.append(NotificationSection(title: "Yesterday", items: yesterday)) }
        if !earlier.isEmpty { sections.append(NotificationSection(title: "Earlier", items: earlier)) }
        return sections
    }

    private func notificationSectionLabel(for iso: String?) -> String {
        guard let date = LikemindedDate.parse(iso) else { return "Earlier" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return "Earlier"
    }

    private var filteredNotifications: [NotificationItem] {
        appState.notifications.filter { item in
            switch notificationFilter {
            case "Unread":
                return !appState.readNotificationIds.contains(item.id)
            case "Mentions":
                return item.kind == "mention"
            default:
                return true
            }
        }
    }

    private var filteredActivityItems: [NotificationItem] {
        appState.activityItems.filter { item in
            switch activityFilter {
            case "Circles":
                return item.kind == "meeting" || item.title.localizedCaseInsensitiveContains("circle")
            case "Communities":
                return item.kind == "community"
            default:
                return true
            }
        }
    }

    private func openNotification(_ item: NotificationItem) {
        appState.readNotificationIds.insert(item.id)
        switch item.kind {
        case "meeting":
            appState.requestedTab = .meet
        case "soulmate", "message", "chat":
            appState.requestedTab = .soulmate
        default:
            break
        }
        dismiss()
    }

    private func openActivityItem(_ item: NotificationItem) {
        switch item.kind {
        case "meeting":
            appState.requestedTab = .meet
        case "community":
            appState.requestedTab = .communities
        default:
            break
        }
        dismiss()
    }
}

private struct NotificationRow: View {
    let item: NotificationItem
    let isUnread: Bool

    private var icon: String {
        switch item.kind {
        case "mention": return "at"
        case "meeting": return "calendar.badge.clock"
        case "community": return "person.3"
        case "soulmate", "match": return "heart"
        case "chat", "message": return "bubble.right"
        default: return "bell"
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

            VStack(alignment: .trailing, spacing: 4) {
                if let createdAt = item.createdAt {
                    Text(NotificationTimeLabel.text(for: createdAt))
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.subink)
                }
                if isUnread {
                    Circle()
                        .fill(PrototypePalette.accent)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(14)
        .background(PrototypePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
    }
}

private struct ActivityRow: View {
    let item: NotificationItem

    private var icon: String {
        switch item.kind {
        case "community": return "person.3"
        case "meeting": return "arrow.triangle.2.circlepath"
        default:
            if item.title.localizedCaseInsensitiveContains("circle") {
                return "arrow.triangle.2.circlepath"
            }
            return "person.3"
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
                Text(NotificationTimeLabel.text(for: createdAt))
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

private enum NotificationTimeLabel {
    static func text(for iso: String) -> String {
        guard let date = LikemindedDate.parse(iso) else { return LikemindedDate.short(iso) }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Now" }
        if seconds < 3600 { return "\(max(1, seconds / 60))m ago" }
        if seconds < 86_400 { return "\(max(1, seconds / 3600))h ago" }
        if seconds < 604_800 { return "\(max(1, seconds / 86_400))d ago" }
        return LikemindedDate.short(iso)
    }
}

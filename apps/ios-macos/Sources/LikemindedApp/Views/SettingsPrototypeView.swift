import SwiftUI

struct SettingsPrototypeView: View {
    @State private var soulmateEnabled = true
    @EnvironmentObject private var appState: PrototypeAppState

    var body: some View {
        ScreenContainer(title: "Soulmate", subtitle: "Settings") {
            settingsSection("Soulmate") {
                VStack(spacing: 0) {
                    Toggle(isOn: $soulmateEnabled) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Enable Soulmate")
                                .font(PrototypeTypography.bodyStrong)
                                .foregroundStyle(PrototypePalette.ink)
                            Text("Opt in to find connections after meetups.\nOnly visible when enabled.")
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.subink)
                        }
                    }
                    .tint(PrototypePalette.accent)
                    .padding(.vertical, 8)

                    Divider().overlay(PrototypePalette.rule)

                    SettingsRow(icon: "heart", title: "How it works")
                }
            }

            settingsSection("Account") {
                SettingsRow(title: "Sign out") {
                    appState.signOut()
                }
            }

            settingsSection("About") {
                VStack(spacing: 0) {
                    HStack {
                        Text("App version")
                        Spacer()
                        Text("1.0.0 (100)")
                            .foregroundStyle(PrototypePalette.subink)
                    }
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.ink)
                    .padding(.vertical, 14)

                    Divider().overlay(PrototypePalette.rule)

                    SettingsRow(title: "Privacy policy")
                }
            }

            settingsSection("Support") {
                VStack(spacing: 0) {
                    SettingsRow(title: "Help & FAQ")
                    Divider().overlay(PrototypePalette.rule)
                    SettingsRow(title: "Contact support")
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(PrototypePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PrototypePalette.rule, lineWidth: 1))
        }
    }
}

struct SafetyPrototypeView: View {
    var body: some View {
        SettingsPrototypeView()
    }
}

private struct SettingsRow: View {
    var icon: String?
    let title: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(PrototypePalette.accent)
                }

                Text(title)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.ink)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PrototypePalette.ink)
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

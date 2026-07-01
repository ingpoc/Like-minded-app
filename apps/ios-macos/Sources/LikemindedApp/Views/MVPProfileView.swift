import SwiftUI

struct ProfilePrototypeView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var feedback = ""
    @State private var rating = 4
    @State private var isSendingFeedback = false

    var body: some View {
        NavigationStack {
            ScreenContainer(
                title: "Profile",
                subtitle: "Your private read."
            ) {
                if let slice = appState.slice {
                    Button {
                        Task {
                            await appState.startVoiceSession()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: appState.isStartingVoice ? "hourglass" : "waveform")
                            Text(appState.isStartingVoice ? "Opening voice" : "Update profile")
                            Spacer()
                            Text(appState.realtimeStatus)
                                .font(PrototypeTypography.caption)
                                .foregroundStyle(PrototypePalette.subink)
                        }
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(PrototypePalette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(PrototypePalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(PrototypePalette.rule, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isStartingVoice)

                    FeatureCard(title: "Your read", eyebrow: appState.sourceLabel) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextEditor(text: $appState.editedReflection)
                                .font(PrototypeTypography.body)
                                .foregroundStyle(PrototypePalette.ink)
                                .frame(minHeight: 130)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(PrototypePalette.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            FlexibleTagLayout(items: slice.profile.reflection.strengths)

                            FlexibleTagLayout(items: slice.profile.interests.map(\.label))

                            Button {
                                Task {
                                    try? await LikemindedAPIClient(authToken: appState.authSession?.token)
                                        .updateProfile(reflectionSummary: appState.editedReflection, signals: slice.signals)
                                }
                            } label: {
                                SecondaryActionButton(title: "Save profile edits", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    FeatureCard(title: "Tester feedback", eyebrow: "MVP") {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper("Rating: \(rating)/5", value: $rating, in: 1...5)
                                .font(PrototypeTypography.metadata)

                            TextField("What should improve before wider beta?", text: $feedback, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...5)

                            Button {
                                Task {
                                    isSendingFeedback = true
                                    await appState.submitFeedback(rating: rating, message: feedback)
                                    feedback = ""
                                    isSendingFeedback = false
                                }
                            } label: {
                                PrimaryActionButton(title: isSendingFeedback ? "Sending" : "Send feedback", systemImage: "paperplane")
                            }
                            .buttonStyle(.plain)
                            .disabled(isSendingFeedback || feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                } else {
                    OnboardingView()
                }

                if let loadError = appState.loadError {
                    Text(loadError)
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.coral)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out") {
                        appState.signOut()
                    }
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.accent)
                }
            }
        }
    }
}

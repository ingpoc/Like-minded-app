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
                subtitle: "Review the private read before committing to a room."
            ) {
                if let slice = appState.slice {
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
                    FeatureCard(title: "No profile yet", eyebrow: "Start in Talk") {
                        Text("Complete a voice profile to create your private read and first circle placement.")
                            .font(PrototypeTypography.body)
                            .foregroundStyle(PrototypePalette.subink)
                    }
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

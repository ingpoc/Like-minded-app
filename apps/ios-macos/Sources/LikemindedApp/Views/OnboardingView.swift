import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var step = 0
    @State private var name = ""
    @State private var gender: Gender = .preferNotToSay
    @State private var dateOfBirth = Date()
    @State private var city = ""
    @State private var pincode = ""

    private let steps = 5

    var body: some View {
        FeatureCard(title: "Start profile", eyebrow: "Onboarding") {
            VStack(alignment: .leading, spacing: 18) {
                progressDots

                TabView(selection: $step) {
                    fieldStep("Name") {
                        TextField("Your name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    .tag(0)

                    fieldStep("Gender") {
                        VStack(spacing: 10) {
                            ForEach(Gender.allCases) { option in
                                Button {
                                    gender = option
                                } label: {
                                    HStack {
                                        Text(option.label)
                                        Spacer()
                                        if gender == option {
                                            Image(systemName: "checkmark.circle.fill")
                                        }
                                    }
                                    .font(PrototypeTypography.body)
                                    .foregroundStyle(PrototypePalette.ink)
                                    .padding(12)
                                    .background(gender == option ? PrototypePalette.accent.opacity(0.14) : PrototypePalette.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .tag(1)

                    fieldStep("Date of birth") {
                        DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .padding(8)
                            .background(PrototypePalette.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .tag(2)

                    fieldStep("City") {
                        TextField("City", text: $city)
                            .textFieldStyle(.roundedBorder)
                    }
                    .tag(3)

                    fieldStep("Pincode") {
                        TextField("Pincode", text: $pincode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(minHeight: 250)

                Button {
                    advance()
                } label: {
                    PrimaryActionButton(title: actionTitle, systemImage: "arrow.right")
                }
                .buttonStyle(.plain)
                .disabled(!canContinue || appState.isStartingVoice)
            }
        }
    }

    private var actionTitle: String {
        if step == steps - 1, appState.isStartingVoice {
            return "Opening voice profile"
        }
        return step == steps - 1 ? "Start voice profile" : "Continue"
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? PrototypePalette.accent : PrototypePalette.subink.opacity(0.18))
                    .frame(width: index == step ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: step)
            }
        }
    }

    private func fieldStep<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(PrototypePalette.ink)
            content()
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private var canContinue: Bool {
        switch step {
        case 0:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            return !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 4:
            return !pincode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private func advance() {
        if step < steps - 1 {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                step += 1
            }
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        appState.completeOnboarding(BasicInfo(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            dateOfBirth: formatter.string(from: dateOfBirth),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            pincode: pincode.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        Task { await appState.startVoiceSession() }
    }
}

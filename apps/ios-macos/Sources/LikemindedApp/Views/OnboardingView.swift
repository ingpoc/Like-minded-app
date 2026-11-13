import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: PrototypeAppState
    @State private var step = 1
    @State private var name = ""
    @State private var gender: Gender = .preferNotToSay
    @State private var dateOfBirth = Date()
    @State private var city = ""
    @State private var pincode = ""
    @State private var draftInterests: Set<String> = ["Jazz", "Books"]
    @State private var basicsStatus: String?
    @State private var isSavingBasics = false
    @State private var voicePromptIndex = 0
    @State private var voiceDraft = ""
    @State private var voiceAnswers: [String] = []
    @State private var voiceStatus: String?
    @State private var isSavingVoice = false

    private let onboardingInterestOptions = ["Jazz", "Books", "Design", "Travel", "Coffee", "Writing", "Mindfulness"]

    private let voiceReflectionPrompts = [
        "What has felt most energizing in your social life lately?",
        "How do you prefer to open up with new people?",
        "What topics or hobbies could you talk about for hours?"
    ]

    var body: some View {
        FeatureCard(title: cardTitle, eyebrow: "Onboarding") {
            VStack(alignment: .leading, spacing: 18) {
                stepSidebar
                stepContent
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .task {
            if appState.isSignedIn {
                await appState.loadCurrentPlacement()
                await appState.fetchCircles()
            }
            seedDraftsFromAppState()
        }
        .onChange(of: appState.slice?.profile.basicInfo?.name) { _, _ in
            seedDraftsFromAppState()
        }
        .onChange(of: appState.basicInfo?.name) { _, _ in
            seedDraftsFromAppState()
        }
    }

    private var cardTitle: String {
        switch step {
        case 2: return "Voice profile"
        case 3: return "Join your first circle"
        default: return "About you"
        }
    }

    private var stepSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow(number: "1", title: "About you", subtitle: "Basic info & interests", selected: step == 1)
            stepRow(number: "2", title: "Voice profile", subtitle: "Record & analyze", selected: step == 2)
            stepRow(number: "3", title: "Join your first circle", subtitle: "Start connecting", selected: step == 3)
            Label("Your privacy, always. We never share your data without permission.", systemImage: "shield")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        // Keep step buttons as individual AX targets (Voice profile step, etc.).
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 2:
            voiceStep
        case 3:
            joinCircleStep
        default:
            basicsStep
        }
    }

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About you")
                        .font(PrototypeTypography.sectionTitle)
                        .foregroundStyle(PrototypePalette.ink)
                    Text("Share a bit about yourself.")
                        .font(PrototypeTypography.caption)
                        .foregroundStyle(PrototypePalette.subink)
                }
                Spacer(minLength: 0)
                basicsAvatar
            }

            profileField(label: "What should we call you?", text: $name, prompt: "Your name")
            profileField(label: "Where are you based?", text: $city, prompt: "City", trailingIcon: "mappin.and.ellipse")

            VStack(alignment: .leading, spacing: 8) {
                Text("Gender")
                    .font(PrototypeTypography.metadata)
                    .foregroundStyle(PrototypePalette.ink)
                HStack(spacing: 8) {
                    ForEach(Gender.allCases) { option in
                        Button(option.label) {
                            gender = option
                        }
                        .font(PrototypeTypography.metadata)
                        .foregroundStyle(gender == option ? .white : PrototypePalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(gender == option ? PrototypePalette.accent : PrototypePalette.background)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(Capsule().stroke(PrototypePalette.rule, lineWidth: gender == option ? 0 : 1))
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.label)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Birthday")
                    .font(PrototypeTypography.metadata.weight(.semibold))
                    .foregroundStyle(PrototypePalette.ink)
                DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .accessibilityLabel("Birthday")
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Pincode")
                    .font(PrototypeTypography.metadata.weight(.semibold))
                    .foregroundStyle(PrototypePalette.ink)
                TextField("Pincode", text: $pincode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Pincode numeric")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("What are you into? (Pick a few)")
                    .font(PrototypeTypography.metadata.weight(.semibold))
                    .foregroundStyle(PrototypePalette.ink)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(onboardingInterestOptions, id: \.self) { interest in
                        onboardingInterestChip(interest)
                    }
                }
            }

            if let basicsStatus {
                Text(basicsStatus)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }

            Button {
                Task { await saveBasicsAndContinue() }
            } label: {
                PrimaryActionButton(title: isSavingBasics ? "Saving…" : "Continue", systemImage: "arrow.right")
            }
            .buttonStyle(.plain)
            .disabled(isSavingBasics || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pincode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Continue")
        }
    }

    private var basicsAvatar: some View {
        Circle()
            .fill(PrototypePalette.accentSoft)
            .frame(width: 44, height: 44)
            .overlay {
                Text(basicsAvatarInitials)
                    .font(PrototypeTypography.bodyStrong)
                    .foregroundStyle(PrototypePalette.accent)
            }
            .accessibilityHidden(true)
    }

    private var basicsAvatarInitials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "?" }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(1)).uppercased()
    }

    private func profileField(label: String, text: Binding<String>, prompt: String, trailingIcon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(PrototypeTypography.metadata.weight(.semibold))
                .foregroundStyle(PrototypePalette.ink)
            HStack(spacing: 8) {
                TextField(prompt, text: text)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(label)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(PrototypeTypography.body)
                        .foregroundStyle(PrototypePalette.subink)
                }
            }
        }
    }

    private func onboardingInterestChip(_ interest: String) -> some View {
        let selected = draftInterests.contains(interest)
        return Button {
            if selected {
                draftInterests.remove(interest)
            } else {
                draftInterests.insert(interest)
            }
        } label: {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(interest)
                    .font(PrototypeTypography.metadata.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : PrototypePalette.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(selected ? PrototypePalette.accent : PrototypePalette.background, in: Capsule())
            .overlay(Capsule().stroke(PrototypePalette.rule, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(interest)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private var voiceStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Answer a few reflection prompts to build your private profile signals.")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)

            Text(voiceReflectionPrompts[voicePromptIndex])
                .font(PrototypeTypography.sectionTitle)
                .foregroundStyle(PrototypePalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Your answer", text: $voiceDraft, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Your answer")

            if let voiceStatus {
                Text(voiceStatus)
                    .font(PrototypeTypography.caption)
                    .foregroundStyle(PrototypePalette.subink)
            }

            HStack(spacing: 12) {
                if voicePromptIndex > 0 {
                    Button("Back") {
                        voicePromptIndex -= 1
                        voiceDraft = voiceAnswers.indices.contains(voicePromptIndex)
                            ? voiceAnswers[voicePromptIndex]
                            : ""
                    }
                    .buttonStyle(.bordered)
                }

                Button(isSavingVoice ? "Saving…" : voicePromptIndex == voiceReflectionPrompts.count - 1 ? "Save voice profile" : "Next prompt") {
                    Task { await advanceVoiceReflection() }
                }
                .buttonStyle(.borderedProminent)
                .tint(PrototypePalette.accent)
                .disabled(isSavingVoice || voiceDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var joinCircleStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review your placement and accept a starter circle to finish onboarding.")
                .font(PrototypeTypography.caption)
                .foregroundStyle(PrototypePalette.subink)

            if let placement = appState.slice?.placement {
                let circle = placement.primaryCircle
                formLine("Suggested circle", value: circle.name)
                formLine("Fit", value: circle.fitLabel)
                Text(circle.placementReason)
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Complete the voice profile step to generate a placement suggestion.")
                    .font(PrototypeTypography.body)
                    .foregroundStyle(PrototypePalette.subink)
            }

            Button {
                appState.requestedTab = .circles
            } label: {
                PrimaryActionButton(title: "Open circles", systemImage: "person.2")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Join first circle")
        }
    }

    private func stepRow(number: String, title: String, subtitle: String? = nil, selected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                step = Int(number) ?? 1
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(selected ? PrototypePalette.accent : PrototypePalette.background)
                        .frame(width: 28, height: 28)
                    Text(number)
                        .font(PrototypeTypography.metadata.weight(.bold))
                        .foregroundStyle(selected ? .white : PrototypePalette.subink)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PrototypeTypography.bodyStrong)
                        .foregroundStyle(selected ? PrototypePalette.accent : PrototypePalette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(PrototypeTypography.caption)
                            .foregroundStyle(PrototypePalette.subink)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) step")
        .accessibilityAddTraits(.isButton)
    }

    private func formLine(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(PrototypeTypography.eyebrow)
                .foregroundStyle(PrototypePalette.accent)
            Text(value)
                .font(PrototypeTypography.bodyStrong)
                .foregroundStyle(PrototypePalette.ink)
        }
    }

    private func seedDraftsFromAppState() {
        let info = appState.slice?.profile.basicInfo ?? appState.basicInfo
        name = info?.name ?? ""
        city = info?.city ?? ""
        gender = info?.gender ?? .preferNotToSay
        pincode = info?.pincode ?? ""
        if let dob = info?.dateOfBirth {
            if let parsed = LikemindedDate.parse(dob) {
                dateOfBirth = parsed
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let parsed = formatter.date(from: dob) {
                    dateOfBirth = parsed
                }
            }
        }
        let seededInterests = appState.slice?.profile.interests.map(\.label) ?? []
        if !seededInterests.isEmpty {
            draftInterests = Set(seededInterests.prefix(4))
        }
    }

    private func saveBasicsAndContinue() async {
        isSavingBasics = true
        basicsStatus = nil
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let saved = await appState.updateProfileBasics(
            name: name,
            city: city,
            gender: gender,
            dateOfBirth: formatter.string(from: dateOfBirth),
            pincode: pincode,
            interests: Array(draftInterests).sorted()
        )
        isSavingBasics = false
        if saved {
            basicsStatus = "Saved"
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                step = 2
            }
        } else {
            basicsStatus = appState.loadError ?? "Profile could not be saved."
        }
    }

    private func advanceVoiceReflection() async {
        let trimmed = voiceDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if voiceAnswers.count > voicePromptIndex {
            voiceAnswers[voicePromptIndex] = trimmed
        } else {
            voiceAnswers.append(trimmed)
        }
        if voicePromptIndex < voiceReflectionPrompts.count - 1 {
            voicePromptIndex += 1
            voiceDraft = voiceAnswers.indices.contains(voicePromptIndex)
                ? voiceAnswers[voicePromptIndex]
                : ""
            return
        }
        isSavingVoice = true
        let saved = await appState.refreshProfileFromReflection(voiceAnswers)
        isSavingVoice = false
        if saved {
            voiceStatus = "Voice profile refreshed."
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                step = 3
            }
        } else {
            voiceStatus = appState.loadError ?? "Voice profile could not be saved."
        }
    }
}

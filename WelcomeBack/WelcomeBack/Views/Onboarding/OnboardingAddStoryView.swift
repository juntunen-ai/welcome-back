import SwiftUI

/// Onboarding step: add the first personal memory or story, with AI writing assistance.
struct OnboardingAddStoryView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager

    @State private var storyTitle = ""
    @State private var storyText  = ""
    @State private var isGenerating = false
    @State private var aiError: String? = nil
    @FocusState private var focusedField: StoryField?

    private enum StoryField { case title, text }

    private var canSave: Bool {
        !storyTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !storyText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 10) {
                    Image(systemName: "text.book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentYellow)
                        .padding(.top, 56)
                        .padding(.bottom, 4)

                    Text(lang.t("onboarding.story.title"))
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.onSurface)
                        .multilineTextAlignment(.center)

                    Text(lang.t("onboarding.story.subtitle"))
                        .font(.system(size: 15))
                        .foregroundColor(.onSurface.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                }

                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("onboarding.story.title.label"))
                        .onboardingLbl()
                    TextField(lang.t("onboarding.story.title.placeholder"), text: $storyTitle)
                        .onboardingTF()
                        .focused($focusedField, equals: .title)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .text }
                }
                .padding(.horizontal, 32)

                // Story text + AI
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("onboarding.story.text.label"))
                        .onboardingLbl()

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $storyText)
                            .frame(minHeight: 120)
                            .padding(14)
                            .background(Color.surfaceVariant.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.08)))
                            .focused($focusedField, equals: .text)
                            .font(.system(size: 16))
                            .foregroundColor(.onSurface)
                            .scrollContentBackground(.hidden)

                        if storyText.isEmpty {
                            Text(lang.t("onboarding.story.text.placeholder"))
                                .font(.system(size: 16))
                                .foregroundColor(.onSurface.opacity(0.3))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text(lang.t("onboarding.family.ai.hint"))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.onSurface.opacity(0.4))
                    .padding(.leading, 4)

                    Button(action: generateStory) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView().tint(.black).scaleEffect(0.75)
                                Text(lang.t("onboarding.story.ai.generating"))
                            } else {
                                Text(lang.t("onboarding.story.ai.button"))
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(storyText.isEmpty || isGenerating
                                    ? Color.surfaceVariant : Color.accentYellow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(storyText.isEmpty || isGenerating)

                    if let err = aiError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 32)

                VStack(spacing: 14) {
                    Button(action: saveAndContinue) {
                        Text(lang.t("onboarding.story.continue"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(canSave ? .black : .onSurface.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(canSave ? Color.accentYellow : Color.surfaceVariant.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)

                    Button(action: onContinue) {
                        Text(lang.t("onboarding.story.skip"))
                            .font(.system(size: 15))
                            .foregroundColor(.onSurface.opacity(0.5))
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func generateStory() {
        guard !storyText.isEmpty, !isGenerating else { return }
        isGenerating = true
        aiError = nil
        let hint = storyText
        let langStr = lang.language == .finnish ? "Finnish" : "English"
        let userName = appVM.userName
        Task {
            do {
                let expanded = try await GeminiService.shared.expandMemory(
                    hint: hint, userName: userName, language: langStr
                )
                await MainActor.run {
                    storyText = expanded
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    aiError = lang.t("onboarding.ai.error")
                    isGenerating = false
                }
            }
        }
    }

    private func saveAndContinue() {
        let trimTitle = storyTitle.trimmingCharacters(in: .whitespaces)
        let trimText  = storyText.trimmingCharacters(in: .whitespaces)
        guard !trimTitle.isEmpty, !trimText.isEmpty else { return }

        let memory = Memory(
            id: UUID().uuidString,
            title: trimTitle,
            date: "",
            imageURL: "",
            category: .other,
            description: trimText
        )
        appVM.userProfile.memories.append(memory)
        onContinue()
    }
}

// MARK: - Private style helpers

private extension Text {
    func onboardingLbl() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.onSurface.opacity(0.45))
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.leading, 4)
    }
}

private extension TextField {
    func onboardingTF() -> some View {
        self
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.onSurface)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.08)))
    }
}

#Preview {
    OnboardingAddStoryView(onContinue: {})
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}

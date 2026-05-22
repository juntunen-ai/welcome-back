import SwiftUI

/// Onboarding step: add the first family member with an optional AI-expanded memory.
struct OnboardingAddFamilyView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager

    @State private var name = ""
    @State private var relationship = ""
    @State private var memoryText = ""
    @State private var isGenerating = false
    @State private var aiError: String? = nil
    @FocusState private var focusedField: FamilyField?

    private enum FamilyField { case name, relationship, memory }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !relationship.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentYellow)
                        .padding(.top, 56)
                        .padding(.bottom, 4)

                    Text(lang.t("onboarding.family.title"))
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.onSurface)
                        .multilineTextAlignment(.center)

                    Text(lang.t("onboarding.family.subtitle"))
                        .font(.system(size: 15))
                        .foregroundColor(.onSurface.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                }

                // Name
                inputSection(label: lang.t("onboarding.family.name.label")) {
                    TextField(lang.t("onboarding.family.name.placeholder"), text: $name)
                        .onboardingTextField()
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .relationship }
                }

                // Relationship
                inputSection(label: lang.t("onboarding.family.rel.label")) {
                    TextField(lang.t("onboarding.family.rel.placeholder"), text: $relationship)
                        .onboardingTextField()
                        .focused($focusedField, equals: .relationship)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .memory }
                }

                // Memory + AI generation
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("onboarding.family.memory.label"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.onSurface.opacity(0.45))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.leading, 4)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $memoryText)
                            .frame(minHeight: 110)
                            .padding(14)
                            .background(Color.surfaceVariant.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.08)))
                            .focused($focusedField, equals: .memory)
                            .font(.system(size: 16))
                            .foregroundColor(.onSurface)
                            .scrollContentBackground(.hidden)

                        if memoryText.isEmpty {
                            Text(lang.t("onboarding.family.memory.placeholder"))
                                .font(.system(size: 16))
                                .foregroundColor(.onSurface.opacity(0.3))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 22)
                                .allowsHitTesting(false)
                        }
                    }

                    // AI hint + generate button
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text(lang.t("onboarding.family.ai.hint"))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.onSurface.opacity(0.4))
                    .padding(.leading, 4)

                    Button(action: generateMemory) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView().tint(.black).scaleEffect(0.75)
                                Text(lang.t("onboarding.family.ai.generating"))
                            } else {
                                Text(lang.t("onboarding.family.ai.button"))
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(memoryText.isEmpty || isGenerating
                                    ? Color.surfaceVariant : Color.accentYellow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(memoryText.isEmpty || isGenerating)

                    if let err = aiError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                            .padding(.leading, 4)
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 32)

                // Action buttons
                VStack(spacing: 14) {
                    Button(action: saveAndContinue) {
                        Text(lang.t("onboarding.family.continue"))
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
                        Text(lang.t("onboarding.family.skip"))
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

    // MARK: - Helpers

    private func inputSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.onSurface.opacity(0.45))
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.leading, 4)
            content()
        }
        .padding(.horizontal, 32)
    }

    private func generateMemory() {
        guard !memoryText.isEmpty, !isGenerating else { return }
        isGenerating = true
        aiError = nil
        let hint = memoryText
        let langStr = lang.language == .finnish ? "Finnish" : "English"
        let userName = appVM.userName
        Task {
            do {
                let expanded = try await GeminiService.shared.expandMemory(
                    hint: hint, userName: userName, language: langStr
                )
                await MainActor.run {
                    memoryText = expanded
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
        let trimName = name.trimmingCharacters(in: .whitespaces)
        let trimRel  = relationship.trimmingCharacters(in: .whitespaces)
        guard !trimName.isEmpty, !trimRel.isEmpty else { return }

        let member = FamilyMember(
            id: UUID().uuidString,
            name: trimName,
            relationship: trimRel,
            biography: "",
            memory1: memoryText,
            memory2: "",
            imageURL: "",
            isVoiceCloned: false
        )
        appVM.userProfile.familyMembers.append(member)
        onContinue()
    }
}

// MARK: - TextField style helper

private extension TextField {
    func onboardingTextField() -> some View {
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
    OnboardingAddFamilyView(onContinue: {})
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}

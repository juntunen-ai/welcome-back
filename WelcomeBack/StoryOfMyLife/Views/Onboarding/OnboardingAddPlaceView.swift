import SwiftUI

/// Onboarding step: add the first important place with AI-assisted description.
struct OnboardingAddPlaceView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager

    @State private var placeName = ""
    @State private var description = ""
    @State private var isGenerating = false
    @State private var aiError: String? = nil
    @FocusState private var focusedField: PlaceField?

    private enum PlaceField { case name, description }

    private var canSave: Bool {
        !placeName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(spacing: 10) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.accentYellow)
                        .padding(.top, 56)
                        .padding(.bottom, 4)

                    Text(lang.t("onboarding.place.title"))
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.onSurface)
                        .multilineTextAlignment(.center)

                    Text(lang.t("onboarding.place.subtitle"))
                        .font(.system(size: 15))
                        .foregroundColor(.onSurface.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                }

                // Place name
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("onboarding.place.name.label"))
                        .onboardingLabel()
                    TextField(lang.t("onboarding.place.name.placeholder"), text: $placeName)
                        .onboardingTextField()
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .description }
                }
                .padding(.horizontal, 32)

                // Description + AI
                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.t("onboarding.place.desc.label"))
                        .onboardingLabel()

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $description)
                            .frame(minHeight: 110)
                            .padding(14)
                            .background(Color.surfaceVariant.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.08)))
                            .focused($focusedField, equals: .description)
                            .font(.system(size: 16))
                            .foregroundColor(.onSurface)
                            .scrollContentBackground(.hidden)

                        if description.isEmpty {
                            Text(lang.t("onboarding.place.desc.placeholder"))
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

                    Button(action: generateDescription) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView().tint(.black).scaleEffect(0.75)
                                Text(lang.t("onboarding.place.ai.generating"))
                            } else {
                                Text(lang.t("onboarding.place.ai.button"))
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 11)
                        .background(description.isEmpty || isGenerating
                                    ? Color.surfaceVariant : Color.accentYellow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(description.isEmpty || isGenerating)

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
                        Text(lang.t("onboarding.place.continue"))
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
                        Text(lang.t("onboarding.place.skip"))
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

    private func generateDescription() {
        guard !description.isEmpty, !isGenerating else { return }
        isGenerating = true
        aiError = nil
        let hint = description
        let langStr = lang.language == .finnish ? "Finnish" : "English"
        let userName = appVM.userName
        Task {
            do {
                let expanded = try await GeminiService.shared.expandMemory(
                    hint: hint, userName: userName, language: langStr
                )
                await MainActor.run {
                    description = expanded
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
        let trimName = placeName.trimmingCharacters(in: .whitespaces)
        guard !trimName.isEmpty else { return }

        let place = Place(
            id: UUID().uuidString,
            name: trimName,
            description: description,
            imageURL: "",
            latitude: 0,
            longitude: 0
        )
        appVM.userProfile.places.append(place)
        onContinue()
    }
}

// MARK: - Private style helpers

private extension Text {
    func onboardingLabel() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.onSurface.opacity(0.45))
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.leading, 4)
    }
}

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
    OnboardingAddPlaceView(onContinue: {})
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}

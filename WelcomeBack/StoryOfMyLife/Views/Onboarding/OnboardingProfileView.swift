import SwiftUI

struct OnboardingProfileView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @State private var name: String = ""
    @FocusState private var nameFieldFocused: Bool

    private let maxNameLength = 50
    private var canContinue: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentYellow.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "person.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentYellow)
            }
            .padding(.bottom, 28)

            // Header
            VStack(spacing: 10) {
                Text(lang.t("onboarding.profile.title"))
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(.onSurface)
                    .multilineTextAlignment(.center)

                Text(lang.t("onboarding.profile.subtitle"))
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
            }

            Spacer(minLength: 32)

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(lang.t("onboarding.profile.name.label"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.onSurface.opacity(0.45))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.leading, 4)

                    Spacer()

                    if name.count > maxNameLength - 15 {
                        Text("\(name.count)/\(maxNameLength)")
                            .font(.system(size: 11))
                            .foregroundColor(name.count >= maxNameLength
                                             ? .orange : .onSurface.opacity(0.35))
                            .padding(.trailing, 4)
                    }
                }

                TextField(lang.t("onboarding.profile.name.placeholder"), text: $name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.onSurface)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.surfaceVariant.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.08)))
                    .focused($nameFieldFocused)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.continue)
                    .onSubmit { if canContinue { saveAndContinue() } }
                    .onChange(of: name) { _, newValue in
                        if newValue.count > maxNameLength {
                            name = String(newValue.prefix(maxNameLength))
                        }
                    }
                    .accessibilityLabel(lang.t("onboarding.profile.continue.a11y"))
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button(action: saveAndContinue) {
                Text(lang.t("onboarding.profile.continue"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(canContinue ? .black : .onSurface.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(canContinue ? Color.accentYellow : Color.surfaceVariant.opacity(0.5))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
            .accessibilityLabel(lang.t("onboarding.profile.continue.a11y"))
            .accessibilityHint(canContinue ? "" : lang.t("onboarding.profile.continue.hint"))
        }
        .onAppear { nameFieldFocused = true }
    }

    private func saveAndContinue() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        appVM.userProfile.name = trimmed
        nameFieldFocused = false
        onContinue()
    }
}

#Preview {
    OnboardingProfileView(onContinue: {})
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}

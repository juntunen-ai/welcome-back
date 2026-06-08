import SwiftUI

/// First onboarding step (after the welcome splash) — lets the user pick
/// whether they want to use the app in English or Finnish.
struct OnboardingLanguageView: View {

    let onContinue: () -> Void

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            Image(systemName: "globe")
                .font(.system(size: 64))
                .foregroundColor(.accentYellow)
                .padding(.bottom, 28)

            // Title — always bilingual so the user can read it regardless of choice
            Text("Choose your language")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            Text("Valitse kielesi")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.onSurface.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.bottom, 40)

            // Language cards
            VStack(spacing: 16) {
                ForEach(AppLanguage.allCases) { language in
                    LanguageCard(
                        language: language,
                        isSelected: lang.language == language
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            lang.language = language
                        }
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text(lang.t("onboarding.language.continue"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentYellow)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            Text(lang.t("onboarding.language.subtitle"))
                .font(.system(size: 13))
                .foregroundColor(.onSurface.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.bottom, 48)
        }
    }
}

// MARK: - Language Card

private struct LanguageCard: View {

    let language: AppLanguage
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 20) {
                Text(language.flag)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.onSurface)
                    Text(language == .english ? "English" : "Suomi")
                        .font(.system(size: 13))
                        .foregroundColor(.onSurface.opacity(0.5))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundColor(isSelected ? .accentYellow : .onSurface.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                Color.surfaceVariant.opacity(isSelected ? 0.55 : 0.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? Color.accentYellow.opacity(0.6) : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(language.flag) \(language.displayName)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    OnboardingLanguageView(onContinue: {})
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}

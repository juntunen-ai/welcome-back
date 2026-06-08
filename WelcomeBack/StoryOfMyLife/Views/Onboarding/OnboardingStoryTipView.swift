import SwiftUI

/// Onboarding tip screen shown after adding the first memory/story.
struct OnboardingStoryTipView: View {

    let onContinue: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.purple)
            }
            .padding(.bottom, 32)

            Text(lang.t("onboarding.story.tip.title"))
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 14)

            Text(lang.t("onboarding.story.tip.body"))
                .font(.system(size: 16))
                .foregroundColor(.onSurface.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentYellow)
                Text("Settings → Memories & Stories")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.surfaceVariant.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            Button(action: onContinue) {
                Text(lang.t("onboarding.story.tip.continue"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentYellow)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    OnboardingStoryTipView(onContinue: {})
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}

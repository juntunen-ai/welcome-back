import SwiftUI

struct OnboardingCompleteView: View {

    let onDone: () -> Void

    @EnvironmentObject private var appVM: AppViewModel
    @State private var checkScale: CGFloat = 0.3
    @State private var checkOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color.accentYellow.opacity(0.15))
                    .frame(width: 160, height: 160)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(Color.accentYellow)
                    .scaleEffect(checkScale)
                    .opacity(checkOpacity)
            }
            .padding(.bottom, 36)

            // Heading
            Text("You're all set\(nameGreeting)!")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

            Text("Welcome Back is ready to help you\nrediscover your memories.")
                .font(.system(size: 17))
                .foregroundColor(.onSurface.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

            // Tips card
            tipsCard
                .padding(.horizontal, 24)

            Spacer()

            // Start button
            Button(action: onDone) {
                Text("Start Remembering")
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
            .accessibilityLabel("Start using Welcome Back")
        }
        .onAppear {
            if reduceMotion {
                checkScale = 1.0
                checkOpacity = 1.0
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.15)) {
                    checkScale   = 1.0
                    checkOpacity = 1.0
                }
            }
        }
    }

    private var nameGreeting: String {
        let name = appVM.userProfile.name
        return name.isEmpty ? "" : ", \(name)"
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            tipRow(icon: "mic.fill",           color: .accentYellow,
                   text: "Tap the big mic button on the Home screen to start a conversation.")
            tipRow(icon: "person.3.fill",      color: .green,
                   text: "Add family members in Settings so the app can introduce them.")
            tipRow(icon: "photo.on.rectangle", color: .blue,
                   text: "Your Memories tab shows photos from your photo library grouped by month.")
        }
        .padding(20)
        .background(Color.surfaceVariant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.white.opacity(0.06)))
    }

    private func tipRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.black))

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    OnboardingCompleteView(onDone: {})
        .environmentObject(AppViewModel())
        .preferredColorScheme(.dark)
}

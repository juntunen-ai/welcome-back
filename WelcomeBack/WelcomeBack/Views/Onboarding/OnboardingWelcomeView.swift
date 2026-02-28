import SwiftUI

struct OnboardingWelcomeView: View {

    let onContinue: () -> Void

    @State private var glowOpacity: Double = 0.4
    @State private var iconScale: CGFloat = 0.85
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.accentYellow.opacity(glowOpacity))
                    .frame(width: 200, height: 200)
                    .blur(radius: 48)

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(Color.accentYellow)
                    .scaleEffect(iconScale)
                    .shadow(color: Color.accentYellow.opacity(0.5), radius: 24, y: 8)
            }
            .frame(height: 160)
            .padding(.bottom, 40)

            // Title
            Text("Welcome Back")
                .font(.system(size: 42, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text("A compassionate companion\nfor your most precious memories.")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Spacer()

            // CTA
            Button(action: onContinue) {
                Text("Get Started")
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
            .accessibilityLabel("Get started with Welcome Back")

            Text("Set up takes about 1 minute")
                .font(.system(size: 13))
                .foregroundColor(.onSurface.opacity(0.35))
                .padding(.bottom, 48)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
            ) {
                glowOpacity = 0.75
                iconScale = 1.0
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
        .preferredColorScheme(.dark)
}

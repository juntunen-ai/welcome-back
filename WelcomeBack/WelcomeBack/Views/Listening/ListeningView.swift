import SwiftUI

struct ListeningView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var wavePhase: CGFloat = 0

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            // Background glow
            RadialGradient(
                colors: [Color.accentYellow.opacity(0.08), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 16)

                Spacer()

                listeningAnimation

                Spacer()

                bottomActions
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.onSurface.opacity(0.4))
                    .frame(width: 48, height: 48)
            }

            Spacer()

            Text("Listening...")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.onSurface)

            Spacer()

            // Balance spacer
            Color.clear.frame(width: 48, height: 48)
        }
    }

    private var listeningAnimation: some View {
        VStack(spacing: 48) {
            ZStack {
                // Outer rings
                Circle()
                    .strokeBorder(Color.accentYellow.opacity(0.2), lineWidth: 1)
                    .frame(width: 240, height: 240)

                Circle()
                    .strokeBorder(Color.accentYellow.opacity(0.4), lineWidth: 1)
                    .frame(width: 200, height: 200)

                // Fluid animated blob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentYellow, Color.accentYellow.opacity(0.3)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 8)
                    .scaleEffect(1.0 + 0.05 * sin(wavePhase))

                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.8))
            }
            .onAppear { animateWave() }

            Text("I'm listening to your story. Take your time...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 24) {
            // Sound bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentYellow.opacity(0.4 + Double(i) * 0.15))
                        .frame(width: 4, height: CGFloat([16, 24, 40, 24, 16][i]))
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                            value: wavePhase
                        )
                }
            }

            Button(action: { appVM.doneSpeaking() }) {
                Text("Done Speaking")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.accentYellow)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentYellow.opacity(0.3), radius: 16, y: 6)
            }
            .frame(maxWidth: 320)
        }
    }

    // MARK: - Animation

    private func animateWave() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            wavePhase = .pi * 2
        }
    }
}

#Preview {
    ListeningView()
        .environmentObject(AppViewModel())
}

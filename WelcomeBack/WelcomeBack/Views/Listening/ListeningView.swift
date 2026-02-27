import SwiftUI

struct ListeningView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var liveVM = LiveSessionViewModel()
    @State private var wavePhase: CGFloat = 0

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            // Background glow — intensifies when AI is speaking
            RadialGradient(
                colors: [Color.accentYellow.opacity(blobGlowOpacity), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: liveVM.sessionState)

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
        // Start live session as soon as the sheet appears
        .onAppear {
            animateWave()
            liveVM.beginSession(profile: appVM.userProfile)
        }
        // Tear down when the sheet is dismissed for any reason
        .onDisappear {
            liveVM.endSession()
        }
        // Fallback: if Live WebSocket fails, revert to REST + PlaybackView
        .onChange(of: liveVM.useFallback) { _, isFallback in
            if isFallback {
                dismiss()
                appVM.doneSpeaking()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button {
                liveVM.endSession()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.onSurface.opacity(0.4))
                    .frame(width: 48, height: 48)
            }

            Spacer()

            Text(headerTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.onSurface)
                .animation(.easeInOut(duration: 0.3), value: liveVM.sessionState)

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

                // Fluid animated blob — colour shifts with session state
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [blobColor, blobColor.opacity(0.3)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 8)
                    .scaleEffect(1.0 + 0.05 * sin(wavePhase))
                    .animation(.easeInOut(duration: 0.4), value: liveVM.sessionState)

                Image(systemName: stateIcon)
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.8))
                    .animation(.easeInOut(duration: 0.3), value: liveVM.sessionState)
            }

            Text(statusLabel)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.7))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: liveVM.sessionState)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 24) {
            // Animated sound bars
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

            // "End" replaces "Done Speaking" — VAD handles turn-taking
            Button(action: {
                liveVM.endSession()
                dismiss()
            }) {
                Text("End")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.7))
                    .frame(width: 140, height: 56)
                    .background(Color.surfaceVariant.opacity(0.5))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - State-Driven Computed Properties

    private var headerTitle: String {
        switch liveVM.sessionState {
        case .connecting:    return "Connecting..."
        case .aiSpeaking:   return "Listening..."
        default:             return "Listening..."
        }
    }

    private var statusLabel: String {
        switch liveVM.sessionState {
        case .idle:          return ""
        case .connecting:    return "Connecting…"
        case .listening:     return "I'm listening. Take your time…"
        case .userSpeaking:  return "Go on, I'm listening…"
        case .aiThinking:    return "Just a moment…"
        case .aiSpeaking:    return "Listening to response…"
        case .interrupted:   return "I'm listening…"
        case .error(let m):  return m
        case .disconnected:  return "Session ended."
        }
    }

    private var stateIcon: String {
        switch liveVM.sessionState {
        case .aiSpeaking:   return "speaker.wave.2"
        case .connecting:   return "antenna.radiowaves.left.and.right"
        case .error:        return "exclamationmark.triangle"
        default:            return "waveform"
        }
    }

    private var blobColor: Color {
        switch liveVM.sessionState {
        case .aiSpeaking:              return Color.accentYellow
        case .userSpeaking, .listening: return Color.accentYellow.opacity(0.6)
        default:                       return Color.accentYellow.opacity(0.3)
        }
    }

    private var blobGlowOpacity: Double {
        switch liveVM.sessionState {
        case .aiSpeaking:   return 0.14
        case .listening:    return 0.08
        default:            return 0.04
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

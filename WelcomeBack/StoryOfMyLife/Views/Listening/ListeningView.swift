import SwiftUI

struct ListeningView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var voiceVM: VoiceSessionBridge
    @State private var wavePhase: CGFloat = 0

    init(mode: VoiceSessionBridge.Mode = .cloud) {
        _voiceVM = StateObject(wrappedValue: VoiceSessionBridge(mode: mode))
    }

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
            .animation(.easeInOut(duration: 0.4), value: voiceVM.sessionState)

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
            // Pass pre-loaded LLM to avoid re-loading on mic tap
            if voiceVM.mode == .local {
                voiceVM.preloadedLLM = appVM.takePreloadedLLM()
            }
            voiceVM.beginSession(profile: appVM.userProfile)
        }
        // Tear down when the sheet is dismissed for any reason
        .onDisappear {
            voiceVM.endSession()
            // Reclaim still-loaded LLM for instant next session
            if let llm = voiceVM.reclaimableLLM {
                appVM.reclaimLLM(llm)
            } else {
                appVM.preloadLLMIfNeeded()
            }
        }
        // Announce state changes to VoiceOver users
        .onChange(of: voiceVM.sessionState) { _, newState in
            let announcement: String?
            switch newState {
            case .listening:     announcement = lang.t("listening.a11y.listen")
            case .aiSpeaking:    announcement = lang.t("listening.a11y.speak")
            case .aiThinking:    announcement = lang.t("listening.a11y.think")
            case .error(let m):  announcement = "Error: \(m)"
            case .disconnected:  announcement = lang.t("listening.ended")
            default:             announcement = nil
            }
            if let announcement {
                AccessibilityNotification.Announcement(announcement).post()
            }
            // Graceful close when the session winds itself down (e.g. the idle
            // "shall we rest?" path). No-op if the user already dismissed.
            if case .disconnected = newState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    dismiss()
                    appVM.doneSpeaking()
                }
            }
        }
        // Fallback: only for cloud mode — if WebSocket fails, dismiss gracefully.
        // Local mode errors are shown in-view via .error state; don't auto-dismiss.
        .onChange(of: voiceVM.useFallback) { _, isFallback in
            if isFallback && voiceVM.mode == .cloud {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    appVM.doneSpeaking()
                }
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button {
                voiceVM.endSession()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.onSurface.opacity(0.4))
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Close")
            .accessibilityHint("Ends the conversation and returns home")

            Spacer()

            Text(headerTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.onSurface)
                .animation(.easeInOut(duration: 0.3), value: voiceVM.sessionState)

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
                    .animation(.easeInOut(duration: 0.4), value: voiceVM.sessionState)

                Image(systemName: stateIcon)
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.8))
                    .animation(.easeInOut(duration: 0.3), value: voiceVM.sessionState)
            }

            Text(statusLabel)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.onSurface.opacity(0.7))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: voiceVM.sessionState)
                .accessibilityLabel(statusLabel)
        }
        // Tapping the blob while the AI talks also stops the reply —
        // a large, forgiving target for elderly users.
        .contentShape(Circle())
        .onTapGesture {
            if showStopReply { voiceVM.stopCurrentReply() }
        }
    }

    /// Show tap-to-stop whenever the AI is talking or preparing a reply
    /// (local mode only — the cloud path has its own interruption handling).
    private var showStopReply: Bool {
        voiceVM.mode == .local &&
        (voiceVM.sessionState == .aiSpeaking || voiceVM.sessionState == .aiThinking)
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

            // Tap-to-stop: a big, obvious way to interrupt a long reply without
            // ending the whole session (half-duplex has no voice barge-in).
            if showStopReply {
                Button(action: { voiceVM.stopCurrentReply() }) {
                    Text(lang.t("listening.stop_reply"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 220, height: 56)
                        .background(Color.accentYellow)
                        .clipShape(Capsule())
                }
                .accessibilityLabel(lang.t("listening.stop_reply.a11y"))
                .accessibilityHint(lang.t("listening.stop_reply.hint"))
                .transition(.opacity)
            }

            // "End" replaces "Done Speaking" — VAD handles turn-taking
            Button(action: {
                voiceVM.endSession()
                dismiss()
            }) {
                Text(lang.t("listening.end"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.onSurface.opacity(0.7))
                    .frame(width: 140, height: 56)
                    .background(Color.surfaceVariant.opacity(0.5))
                    .clipShape(Capsule())
            }
            .accessibilityLabel(lang.t("listening.end.a11y"))
            .accessibilityHint(lang.t("listening.end.hint"))
        }
    }

    // MARK: - State-Driven Computed Properties

    private var headerTitle: String {
        switch voiceVM.sessionState {
        case .connecting:
            return voiceVM.mode == .local ? lang.t("listening.header.loading") : lang.t("listening.connecting")
        case .aiSpeaking:
            return lang.t("listening.header")
        default:
            return lang.t("listening.header")
        }
    }

    private var statusLabel: String {
        switch voiceVM.sessionState {
        case .idle:          return ""
        case .connecting:    return voiceVM.mode == .local ? lang.t("listening.loading") : lang.t("listening.connecting")
        case .listening:     return lang.t("listening.ready")
        case .userSpeaking:  return lang.t("listening.go_on")
        case .aiThinking:    return lang.t("listening.moment")
        case .aiSpeaking:    return lang.t("listening.response")
        case .interrupted:   return lang.t("listening.done")
        case .error(let m):  return m
        case .disconnected:  return lang.t("listening.ended")
        }
    }

    private var stateIcon: String {
        switch voiceVM.sessionState {
        case .aiSpeaking:   return "speaker.wave.2"
        case .connecting:   return voiceVM.mode == .local ? "brain" : "antenna.radiowaves.left.and.right"
        case .error:        return "exclamationmark.triangle"
        default:            return "waveform"
        }
    }

    private var blobColor: Color {
        switch voiceVM.sessionState {
        case .aiSpeaking:              return Color.accentYellow
        case .userSpeaking, .listening: return Color.accentYellow.opacity(0.6)
        default:                       return Color.accentYellow.opacity(0.3)
        }
    }

    private var blobGlowOpacity: Double {
        switch voiceVM.sessionState {
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
    ListeningView(mode: .cloud)
        .environmentObject(AppViewModel())
        .environmentObject(LanguageManager())
}

import SwiftUI
import MediaPlayer

/// Onboarding step: invite the user to connect Apple Music for memory lane playback.
struct OnboardingMusicView: View {

    let onContinue: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    @State private var authStatus: MPMediaLibraryAuthorizationStatus = MPMediaLibrary.authorizationStatus()
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Music icon with animated glow
            ZStack {
                Circle()
                    .fill(Color.accentYellow.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: "music.note.list")
                    .font(.system(size: 56))
                    .foregroundColor(.accentYellow)
            }
            .padding(.bottom, 32)

            Text(lang.t("onboarding.music.title"))
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.onSurface)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 14)

            Text(lang.t("onboarding.music.subtitle"))
                .font(.system(size: 16))
                .foregroundColor(.onSurface.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)

            Spacer()

            // Feature pills
            HStack(spacing: 12) {
                featurePill(icon: "waveform.path.ecg", text: "Memory Lane")
                featurePill(icon: "music.quarternote.3", text: "Your Library")
            }
            .padding(.bottom, 32)

            // Action buttons
            VStack(spacing: 14) {
                if authStatus == .authorized {
                    // Already granted — show success
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.black)
                        Text(lang.t("music.connect.btn"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentYellow)
                    .clipShape(Capsule())
                    .onAppear {
                        // Auto-advance after showing "connected" briefly
                        Task {
                            try? await Task.sleep(for: .seconds(1.0))
                            onContinue()
                        }
                    }
                } else {
                    Button(action: requestAccess) {
                        HStack(spacing: 10) {
                            if isRequesting {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "music.note")
                            }
                            Text(lang.t("onboarding.music.connect"))
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accentYellow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequesting)
                }

                Button(action: onContinue) {
                    Text(lang.t("onboarding.music.skip"))
                        .font(.system(size: 15))
                        .foregroundColor(.onSurface.opacity(0.5))
                        .underline()
                }
                .buttonStyle(.plain)

                Text(lang.t("onboarding.music.note"))
                    .font(.system(size: 12))
                    .foregroundColor(.onSurface.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Helpers

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.accentYellow)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.onSurface.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfaceVariant.opacity(0.4))
        .clipShape(Capsule())
    }

    private func requestAccess() {
        isRequesting = true
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                authStatus = status
                isRequesting = false
                if status == .authorized { onContinue() }
            }
        }
    }
}

#Preview {
    OnboardingMusicView(onContinue: {})
        .environmentObject(LanguageManager())
        .preferredColorScheme(.dark)
}

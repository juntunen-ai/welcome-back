import SwiftUI
import AVFoundation

/// Settings view for selecting the AI companion's TTS voice.
/// Supports default Apple voices and Personal Voice (iOS 17+).
struct VoiceSelectionView: View {

    @State private var personalVoices: [AVSpeechSynthesisVoice] = []
    @State private var authStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = .notDetermined
    @State private var selectedID: String? = SpeechService.shared.selectedVoiceIdentifier

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            List {
                defaultVoiceSection
                personalVoiceSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("AI Voice")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            authStatus = SpeechService.shared.personalVoiceAuthStatus
            if authStatus == .authorized {
                personalVoices = SpeechService.shared.availablePersonalVoices()
            }
        }
    }

    // MARK: - Default Voice

    private var defaultVoiceSection: some View {
        Section {
            Button {
                selectedID = nil
                SpeechService.shared.selectedVoiceIdentifier = nil
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: selectedID == nil ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedID == nil ? .accentYellow : .onSurface.opacity(0.3))
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Voice")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.onSurface)
                        Text("Apple TTS (English)")
                            .font(.system(size: 12))
                            .foregroundColor(.onSurface.opacity(0.5))
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.surfaceVariant.opacity(0.4))
        } header: {
            Text("AI Companion Voice")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        }
    }

    // MARK: - Personal Voice

    private var personalVoiceSection: some View {
        Section {
            switch authStatus {
            case .authorized:
                if personalVoices.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.orange)
                        Text("No Personal Voices found. Create one in iOS Settings → Accessibility → Personal Voice.")
                            .font(.system(size: 13))
                            .foregroundColor(.onSurface.opacity(0.6))
                    }
                    .listRowBackground(Color.surfaceVariant.opacity(0.4))
                } else {
                    ForEach(personalVoices, id: \.identifier) { voice in
                        Button {
                            selectedID = voice.identifier
                            SpeechService.shared.selectedVoiceIdentifier = voice.identifier
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: selectedID == voice.identifier
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedID == voice.identifier
                                                     ? .accentYellow : .onSurface.opacity(0.3))
                                    .font(.system(size: 20))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.onSurface)
                                    Text("Personal Voice")
                                        .font(.system(size: 12))
                                        .foregroundColor(.purple)
                                }

                                Spacer()

                                // Preview button
                                Button {
                                    previewVoice(voice)
                                } label: {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.accentYellow)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.surfaceVariant.opacity(0.4))
                    }
                }

            case .notDetermined:
                Button {
                    Task {
                        let granted = await SpeechService.shared.requestPersonalVoiceAccess()
                        authStatus = SpeechService.shared.personalVoiceAuthStatus
                        if granted {
                            personalVoices = SpeechService.shared.availablePersonalVoices()
                        }
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.wave.2.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Personal Voice")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.onSurface)
                            Text("Use a voice you created in iOS Settings")
                                .font(.system(size: 12))
                                .foregroundColor(.onSurface.opacity(0.5))
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.surfaceVariant.opacity(0.4))

            case .denied, .unsupported:
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(authStatus == .denied
                         ? "Personal Voice access denied. Enable in iOS Settings → Privacy → Personal Voice."
                         : "Personal Voice is not supported on this device.")
                        .font(.system(size: 13))
                        .foregroundColor(.onSurface.opacity(0.6))
                }
                .listRowBackground(Color.surfaceVariant.opacity(0.4))

            @unknown default:
                EmptyView()
            }
        } header: {
            Text("Personal Voice")
                .foregroundColor(.accentYellow)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
        } footer: {
            Text("Create a Personal Voice in iOS Settings → Accessibility → Personal Voice. It takes about 15 minutes of reading phrases aloud.")
                .font(.system(size: 11))
                .foregroundColor(.onSurface.opacity(0.4))
        }
    }

    // MARK: - Preview

    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        let utterance = AVSpeechUtterance(string: "Hello! It's so nice to talk with you today.")
        utterance.voice = voice
        utterance.rate = 0.48
        SpeechService.shared.speakSentences(
            ["Hello! It's so nice to talk with you today."],
            voiceIdentifier: voice.identifier,
            onAllFinished: {}
        )
    }
}

#Preview {
    NavigationStack { VoiceSelectionView() }
        .preferredColorScheme(.dark)
}

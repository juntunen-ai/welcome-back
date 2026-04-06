import SwiftUI
import AVFoundation

/// Records a voice sample from a family member and uploads it to the F5-TTS server.
///
/// Navigate here from `FamilyMemberDetailView` or from Settings.
/// When no specific member binding is provided, shows a picker to choose a family member.
struct RecordVoiceView: View {

    @EnvironmentObject private var appVM: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @Binding var member: FamilyMember

    @State private var recordingState: RecordingState = .idle
    @State private var recordedData: Data?
    @State private var recordingDuration: TimeInterval = 0
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var uploadSuccess = false

    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var timer: Timer?

    private let minDuration: TimeInterval = 5
    private let maxDuration: TimeInterval = 30

    enum RecordingState {
        case idle, recording, recorded, playing
    }

    var body: some View {
        ZStack {
            Color.backgroundDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    memberHeader
                    instructionsCard
                    recordingControls
                    if recordedData != nil { uploadSection }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("Record Voice")
        .navigationBarTitleDisplayMode(.large)
        .onDisappear { cleanup() }
    }

    // MARK: - Member Header

    private var memberHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.surfaceVariant.opacity(0.5))
                    .frame(width: 80, height: 80)

                if let ui = PersistenceService.loadImage(imageURL: member.imageURL) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Text(member.name.prefix(1))
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.onSurface.opacity(0.15))
                }
            }

            Text(member.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.onSurface)

            Text(member.relationship)
                .font(.system(size: 14))
                .foregroundColor(.onSurface.opacity(0.5))
        }
    }

    // MARK: - Instructions

    private var instructionsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundColor(.accentYellow)
            Text("Hold the phone 15 cm from \(member.name)'s mouth. Have them speak naturally for 10-30 seconds — reading aloud or talking about their day works well.")
                .font(.system(size: 13))
                .foregroundColor(.onSurface.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.surfaceVariant.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        VStack(spacing: 16) {
            // Timer display
            Text(formattedDuration)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(recordingState == .recording ? .red : .onSurface)

            // Duration bar
            if recordingState == .recording {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.surfaceVariant)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: geo.size.width * min(recordingDuration / maxDuration, 1), height: 6)
                    }
                }
                .frame(height: 6)

                Text(recordingDuration < minDuration ? "Keep recording — need at least \(Int(minDuration)) seconds" : "Good! You can stop now or keep going.")
                    .font(.system(size: 12))
                    .foregroundColor(recordingDuration < minDuration ? .red.opacity(0.8) : .green.opacity(0.8))
            }

            // Buttons
            HStack(spacing: 24) {
                switch recordingState {
                case .idle:
                    recordButton
                case .recording:
                    stopButton
                case .recorded, .playing:
                    playbackButton
                    retryButton
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(Color.surfaceVariant.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var recordButton: some View {
        Button(action: startRecording) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                Text("TAP TO RECORD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.onSurface.opacity(0.5))
            }
        }
    }

    private var stopButton: some View {
        Button(action: stopRecording) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                }
                Text("STOP")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.onSurface.opacity(0.5))
            }
        }
    }

    private var playbackButton: some View {
        Button(action: togglePlayback) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.accentYellow)
                        .frame(width: 56, height: 56)
                    Image(systemName: recordingState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                }
                Text(recordingState == .playing ? "PAUSE" : "PREVIEW")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.onSurface.opacity(0.5))
            }
        }
    }

    private var retryButton: some View {
        Button(action: retry) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.onSurface.opacity(0.3), lineWidth: 2)
                        .frame(width: 56, height: 56)
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                        .foregroundColor(.onSurface.opacity(0.6))
                }
                Text("RETRY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.onSurface.opacity(0.5))
            }
        }
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(spacing: 16) {
            if uploadSuccess {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Cloned!")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.onSurface)
                        Text("\(member.name)'s voice is now ready for story playback.")
                            .font(.system(size: 13))
                            .foregroundColor(.onSurface.opacity(0.6))
                    }
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button("Done") { dismiss() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color.accentYellow)
                    .clipShape(Capsule())
            } else {
                Button(action: uploadVoice) {
                    HStack {
                        if isUploading {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        Text(isUploading ? "Uploading..." : "Upload Voice to Server")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(F5TTSService.shared.isConfigured ? Color.accentYellow : Color.surfaceVariant)
                    .clipShape(Capsule())
                }
                .disabled(isUploading || !F5TTSService.shared.isConfigured || recordingDuration < minDuration)

                if !F5TTSService.shared.isConfigured {
                    Text("Set up the Voice Cloning Server in Settings first.")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                if let error = uploadError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    // MARK: - Formatting

    private var formattedDuration: String {
        let mins = Int(recordingDuration) / 60
        let secs = Int(recordingDuration) % 60
        let tenths = Int((recordingDuration - Double(Int(recordingDuration))) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }

    // MARK: - Recording Actions

    private func startRecording() {
        let avSession = AVAudioSession.sharedInstance()
        do {
            try avSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try avSession.setActive(true)
        } catch {
            uploadError = "Could not access microphone: \(error.localizedDescription)"
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voice_sample.wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder.record()
            audioRecorder = recorder
            recordingState = .recording
            recordingDuration = 0
            recordedData = nil
            uploadError = nil
            uploadSuccess = false

            // Update timer
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration = recorder.currentTime
                if recordingDuration >= maxDuration {
                    stopRecording()
                }
            }
        } catch {
            uploadError = "Recording failed: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()

        if let url = audioRecorder?.url {
            recordedData = try? Data(contentsOf: url)
        }

        audioRecorder = nil
        recordingState = recordedData != nil ? .recorded : .idle
    }

    private func togglePlayback() {
        if recordingState == .playing {
            audioPlayer?.stop()
            audioPlayer = nil
            recordingState = .recorded
        } else if let data = recordedData {
            do {
                let player = try AVAudioPlayer(data: data)
                player.play()
                audioPlayer = player
                recordingState = .playing

                // Return to .recorded when playback finishes
                DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) {
                    if recordingState == .playing {
                        recordingState = .recorded
                    }
                }
            } catch {
                uploadError = "Playback failed: \(error.localizedDescription)"
            }
        }
    }

    private func retry() {
        audioPlayer?.stop()
        audioPlayer = nil
        recordedData = nil
        recordingDuration = 0
        recordingState = .idle
        uploadError = nil
    }

    private func uploadVoice() {
        guard let data = recordedData else { return }

        isUploading = true
        uploadError = nil

        Task {
            do {
                let refId = try await F5TTSService.shared.uploadReference(
                    name: "\(member.name)'s Voice",
                    audioData: data
                )
                member.voiceProfileID = refId
                member.isVoiceCloned = true
                uploadSuccess = true
                #if DEBUG
                print("[RecordVoice] Upload success: \(refId)")
                #endif
            } catch {
                uploadError = error.localizedDescription
            }
            isUploading = false
        }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

#Preview {
    NavigationStack {
        RecordVoiceView(member: .constant(FamilyMember(
            id: "preview-1",
            name: "Anna",
            relationship: "Wife",
            imageURL: "",
            isVoiceCloned: false
        )))
    }
    .environmentObject(AppViewModel())
    .preferredColorScheme(.dark)
}
